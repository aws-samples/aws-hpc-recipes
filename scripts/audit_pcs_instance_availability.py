"""Audit EC2 instance type availability across AWS PCS regions.

Reads scripts/pcs_instance_manifest.yml and checks every desired instance
type against every region where AWS PCS is available. Writes two reports:

  - audit-pcs-instances.md  (human-readable matrix + gap summary)
  - audit-pcs-instances.csv (raw data, one row per instance/region pair)

Region-level availability comes from two sources, combined:

  1. AWS docs page (credential-free, covers ALL PCS regions including
     opt-in and GovCloud):
       https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-regions.html
     This page lists instance FAMILIES per region (e.g. "Hpc7a", not
     "hpc7a.48xlarge"). Within a family, all offered sizes are treated
     as region-available per AWS convention.

  2. EC2 DescribeInstanceTypeOfferings (LocationType=availability-zone) in
     regions the current credentials can reach, for AZ-level granularity.
     AZ data is useful for PCS because clusters pin to specific subnets and
     capacity-constrained families (hpc7a, hpc7g, P5) are often single-AZ.

PCS region list is resolved from the AWS SSM public parameter:
  /aws/service/global-infrastructure/services/pcs/regions

Operators can supply additional regions to audit (for example, non-GA
regions relevant to an internal planning exercise) via the
--extra-regions-file flag. The referenced file is never read from or
written to the repo; the caller points at a file on their local system.

All AWS API calls are read-only (Describe/Get). No mutations.

Usage:
  python -m scripts.audit_pcs_instance_availability
  python -m scripts.audit_pcs_instance_availability --regions us-east-1,eu-west-1
  python -m scripts.audit_pcs_instance_availability --output-dir reports/
  python -m scripts.audit_pcs_instance_availability --no-az  # docs only, skip EC2 calls
  python -m scripts.audit_pcs_instance_availability --extra-regions-file ~/mylist.yaml
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
import time
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import boto3
import yaml
from botocore.config import Config
from botocore.exceptions import ClientError

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = REPO_ROOT / "scripts" / "pcs_instance_manifest.yml"
DEFAULT_OUTPUT_DIR = REPO_ROOT

PCS_REGIONS_SSM_PARAM = "/aws/service/global-infrastructure/services/pcs/regions"
AWS_DOCS_URL = (
    "https://docs.aws.amazon.com/ec2/latest/instancetypes/ec2-instance-regions.html"
)

# Concurrency cap for per-region EC2 calls. EC2 Describe throttling is generous
# but conservative is safer when running inside a shared CI account.
MAX_REGION_WORKERS = 8

BOTO_CONFIG = Config(
    retries={"max_attempts": 6, "mode": "adaptive"},
    connect_timeout=5,
    read_timeout=30,
)


class RegionNotAccessible(RuntimeError):
    """Raised when a region is not reachable with current credentials.

    Covers opt-in regions the account has not enabled, and GovCloud regions
    when running with commercial credentials.
    """


@dataclass(frozen=True)
class InstanceSpec:
    """One instance type referenced by a recipe, with context for the report."""

    recipe: str
    type: str
    role: str
    arch: str


def load_manifest(path: Path) -> list[InstanceSpec]:
    with path.open() as f:
        data = yaml.safe_load(f)
    specs: list[InstanceSpec] = []
    for recipe in data.get("recipes", []):
        name = recipe["name"]
        for inst in recipe.get("instances", []):
            specs.append(
                InstanceSpec(
                    recipe=name,
                    type=inst["type"],
                    role=inst["role"],
                    arch=inst["arch"],
                )
            )
    return specs


def resolve_pcs_regions(session: boto3.Session) -> list[str]:
    """Fetch the list of regions where AWS PCS is GA via SSM public parameter."""
    ssm = session.client("ssm", region_name="us-east-1", config=BOTO_CONFIG)
    regions: list[str] = []
    paginator = ssm.get_paginator("get_parameters_by_path")
    for page in paginator.paginate(Path=PCS_REGIONS_SSM_PARAM):
        for p in page.get("Parameters", []):
            regions.append(p["Name"].rsplit("/", 1)[-1])
    return sorted(set(regions))


def load_extra_regions(path: Path) -> list[str]:
    """Load region codes from an operator-supplied YAML file.

    File format is a mapping with a top-level `regions` key whose value is
    a list of entries. Each entry must include a `code` field (the AWS
    region code, e.g. `eu-central-2`). Other fields are ignored.

    Example:
      regions:
        - code: ap-southeast-3
        - code: eu-central-2

    Returns an empty list if the path does not exist.
    """
    if not path.exists():
        return []
    with path.open() as f:
        data = yaml.safe_load(f) or {}
    out: list[str] = []
    for entry in data.get("regions", []):
        code = entry.get("code") if isinstance(entry, dict) else None
        if code:
            out.append(code)
    return out


# -----------------------------------------------------------------------------
# Docs-page scraper: region -> set of instance families
# -----------------------------------------------------------------------------

# The docs page presents each region as a heading line like:
#   "Europe (Spain) — eu-south-2"
# followed by a line starting with "The following instance types" and then
# one or more lines with category names ("General Purpose", "Compute
# Optimized", ...) joined by "|" separated family tokens.
#
# Family tokens are first-letter capitalized (e.g. "Hpc7a", "C7i-flex",
# "Mac-m4pro", "P6-B200"). Sizes are NOT listed on this page.

REGION_HEADING_RE = re.compile(
    # Match region codes in any AWS partition. Accept any number of
    # hyphen-separated lowercase chunks ending in "-<digit>[letter]?".
    # Must anchor the match to a region separator (em-dash or hyphen after
    # the region name) AND the end of the line so we get the full code.
    r"[—\-]\s*((?:[a-z]+-){2,}\d+[a-z]?)\s*$"
)

CATEGORY_RE = re.compile(
    r"(?:General Purpose|Compute Optimized|Memory Optimized|Storage Optimized|"
    r"Accelerated Computing|High Performance Computing|Previous Generation):\s*"
    r"([A-Za-z0-9|\-\s]+?)(?=(?:General Purpose|Compute Optimized|Memory Optimized|"
    r"Storage Optimized|Accelerated Computing|High Performance Computing|"
    r"Previous Generation):|$)"
)


def _fetch_url(url: str, timeout: int = 30) -> str:
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "aws-hpc-recipes-audit/1.0"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
        return resp.read().decode("utf-8", errors="replace")


def _extract_text(html: str) -> str:
    # Very basic HTML -> text: strip scripts/styles and tags, decode a few
    # common entities. The docs page is well-formed and uses minimal markup
    # inside the family lists, so this is sufficient.
    html = re.sub(r"<script[\s\S]*?</script>", " ", html, flags=re.IGNORECASE)
    html = re.sub(r"<style[\s\S]*?</style>", " ", html, flags=re.IGNORECASE)
    # Keep block boundaries by turning tags into newlines.
    text = re.sub(r"<(br|/p|/li|/h\d|/div|/tr|/table)\b[^>]*>", "\n", html, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", " ", text)
    text = (
        text.replace("&mdash;", "—")
        .replace("&amp;", "&")
        .replace("&nbsp;", " ")
        .replace("&#x2014;", "—")
    )
    return text


def scrape_doc_families(
    url: str = AWS_DOCS_URL, html: str | None = None
) -> dict[str, set[str]]:
    """Return mapping: region -> set of instance families (lowercase).

    Families come from the AWS docs page. Size suffixes like ".48xlarge" are
    not present on that page; a manifest entry is considered region-available
    if the family appears in the region's list.
    """
    if html is None:
        html = _fetch_url(url)
    text = _extract_text(html)

    # Iterate line-by-line, associating family lists with the last region
    # heading seen.
    by_region: dict[str, set[str]] = {}
    current_region: str | None = None

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        m = REGION_HEADING_RE.search(line)
        if m:
            current_region = m.group(1)
            by_region.setdefault(current_region, set())
            continue
        if current_region is None:
            continue
        # Collect families from every category match on the line.
        for cat_match in CATEGORY_RE.finditer(line):
            families_str = cat_match.group(1)
            for token in families_str.split("|"):
                token = token.strip()
                if not token:
                    continue
                by_region[current_region].add(token.lower())
    return by_region


def family_of(instance_type: str) -> str:
    """Extract the family token used by the docs page from a full type name.

    Examples:
      c7g.xlarge      -> c7g
      hpc7a.48xlarge  -> hpc7a
      p5en.48xlarge   -> p5en
      t2.medium       -> t2
      c7i-flex.xlarge -> c7i-flex
      mac2-m2.metal   -> mac2-m2
    """
    return instance_type.split(".", 1)[0]


# -----------------------------------------------------------------------------
# EC2 AZ-level lookup (best-effort, for reachable regions)
# -----------------------------------------------------------------------------


def offerings_for_region(
    session: boto3.Session, region: str, instance_types: list[str]
) -> tuple[set[str], dict[str, set[str]], int]:
    """Return (region_available_types, az_map, total_azs_in_region).

    Raises RegionNotAccessible when credentials cannot reach the region
    (opt-in not enabled, or GovCloud from commercial).
    """
    ec2 = session.client("ec2", region_name=region, config=BOTO_CONFIG)

    total_azs = 0
    try:
        az_resp = ec2.describe_availability_zones(
            Filters=[{"Name": "state", "Values": ["available"]}]
        )
        total_azs = len(az_resp.get("AvailabilityZones", []))
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        if code in ("AuthFailure", "UnauthorizedOperation", "OptInRequired"):
            raise RegionNotAccessible(region) from e
        print(f"  [{region}] describe_availability_zones error: {e}", file=sys.stderr)
    except Exception as e:
        # Endpoint connection errors commonly mean GovCloud from commercial.
        msg = str(e)
        if "Could not connect" in msg or "EndpointConnectionError" in type(e).__name__:
            raise RegionNotAccessible(region) from e
        print(f"  [{region}] describe_availability_zones error: {e}", file=sys.stderr)

    region_avail: set[str] = set()
    paginator = ec2.get_paginator("describe_instance_type_offerings")
    try:
        for page in paginator.paginate(
            LocationType="region",
            Filters=[{"Name": "instance-type", "Values": instance_types}],
        ):
            for off in page.get("InstanceTypeOfferings", []):
                region_avail.add(off["InstanceType"])
    except ClientError as e:
        print(f"  [{region}] region offerings error: {e}", file=sys.stderr)
        return set(), {}, total_azs

    az_map: dict[str, set[str]] = defaultdict(set)
    if region_avail:
        try:
            for page in paginator.paginate(
                LocationType="availability-zone",
                Filters=[
                    {"Name": "instance-type", "Values": sorted(region_avail)},
                ],
            ):
                for off in page.get("InstanceTypeOfferings", []):
                    az_map[off["InstanceType"]].add(off["Location"])
        except ClientError as e:
            print(f"  [{region}] az offerings error: {e}", file=sys.stderr)

    return region_avail, dict(az_map), total_azs


def audit_az_detail(
    session: boto3.Session,
    regions: list[str],
    instance_types: list[str],
) -> tuple[dict[str, tuple[set[str], dict[str, set[str]], int]], list[str]]:
    """Run AZ-level offerings lookups in parallel across regions.

    Returns (results, inaccessible_regions). Inaccessible regions are ones
    the current credentials cannot reach (opt-in not enabled, GovCloud
    without GovCloud creds).
    """
    results: dict[str, tuple[set[str], dict[str, set[str]], int]] = {}
    inaccessible: list[str] = []
    t0 = time.monotonic()
    with ThreadPoolExecutor(max_workers=MAX_REGION_WORKERS) as pool:
        futures = {
            pool.submit(offerings_for_region, session, r, instance_types): r
            for r in regions
        }
        for i, fut in enumerate(as_completed(futures), 1):
            region = futures[fut]
            try:
                results[region] = fut.result()
            except RegionNotAccessible:
                inaccessible.append(region)
            except Exception as e:
                print(f"  [{region}] AZ detail failed: {e}", file=sys.stderr)
                results[region] = (set(), {}, 0)
            print(
                f"  [{i}/{len(regions)}] {region} AZ detail done",
                file=sys.stderr,
            )
    print(f"  AZ detail took {time.monotonic() - t0:.1f}s", file=sys.stderr)
    return results, inaccessible


# -----------------------------------------------------------------------------
# Report writers
# -----------------------------------------------------------------------------


def _region_cell(
    itype: str,
    region: str,
    doc_families: dict[str, set[str]],
    az_results: dict[str, tuple[set[str], dict[str, set[str]], int]],
) -> tuple[str, str]:
    """Return (cell_text, status) for the matrix.

    status is one of: "ok", "partial-az", "missing-region", "unknown-region".
    """
    fam = family_of(itype)
    doc_set = doc_families.get(region)
    if doc_set is None:
        return "??", "unknown-region"

    # Docs-family availability is the ground truth for "does the region offer
    # this family at all". We ALWAYS use docs for region-level presence.
    region_has_family = fam in doc_set

    # AZ data, if we got it.
    az_info = az_results.get(region)
    if az_info is None:
        # No AZ data (inaccessible region). Report region-level only.
        return ("OK" if region_has_family else "--"), (
            "ok" if region_has_family else "missing-region"
        )

    _az_api_types, az_map, total_azs = az_info
    az_have = len(az_map.get(itype, set()))

    if not region_has_family and az_have == 0:
        return "--", "missing-region"
    if not region_has_family and az_have > 0:
        # Docs say no, EC2 says yes. Very rare; prefer the EC2 signal because
        # the docs page can lag a few days behind a launch.
        if total_azs and az_have < total_azs:
            return f"{az_have}/{total_azs}*", "partial-az"
        return "OK*", "ok"
    # region_has_family is True.
    if az_have == 0:
        # Docs say yes, EC2 says no. Likely a family-vs-size mismatch (e.g.
        # docs list "Hpc7a" but we asked for hpc7a.48xlarge which is the
        # only current size; both cases should converge). Fall back to
        # docs-level OK and annotate.
        return "OK(?)", "ok"
    if total_azs and az_have < total_azs:
        return f"{az_have}/{total_azs}", "partial-az"
    return "OK", "ok"


def write_csv(
    path: Path,
    specs: list[InstanceSpec],
    regions: list[str],
    doc_families: dict[str, set[str]],
    az_results: dict[str, tuple[set[str], dict[str, set[str]], int]],
    extra_regions: set[str] | None = None,
) -> None:
    extra_regions = extra_regions or set()
    unique_types = sorted({(s.type, s.arch) for s in specs})
    type_to_recipes: dict[str, set[str]] = defaultdict(set)
    type_to_roles: dict[str, set[str]] = defaultdict(set)
    for s in specs:
        type_to_recipes[s.type].add(s.recipe)
        type_to_roles[s.type].add(s.role)

    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            [
                "instance_type",
                "family",
                "arch",
                "region",
                "region_status",
                "docs_family_available",
                "az_data_source",
                "az_count",
                "total_azs",
                "azs",
                "recipes",
                "roles",
            ]
        )
        for itype, arch in unique_types:
            fam = family_of(itype)
            for region in regions:
                doc_set = doc_families.get(region, set())
                doc_has = fam in doc_set
                az_info = az_results.get(region)
                if az_info is None:
                    az_source = "none"
                    az_count = 0
                    total_azs = 0
                    azs: list[str] = []
                else:
                    az_source = "ec2-api"
                    _api_types, az_map, total_azs = az_info
                    azs = sorted(az_map.get(itype, set()))
                    az_count = len(azs)
                w.writerow(
                    [
                        itype,
                        fam,
                        arch,
                        region,
                        "extra" if region in extra_regions else "ga",
                        "yes" if doc_has else "no",
                        az_source,
                        az_count,
                        total_azs,
                        ";".join(azs),
                        ";".join(sorted(type_to_recipes[itype])),
                        ";".join(sorted(type_to_roles[itype])),
                    ]
                )


def write_markdown(
    path: Path,
    specs: list[InstanceSpec],
    regions: list[str],
    doc_families: dict[str, set[str]],
    az_results: dict[str, tuple[set[str], dict[str, set[str]], int]],
    inaccessible_az: list[str],
    unknown_doc_regions: list[str],
    extra_regions: set[str] | None = None,
) -> None:
    extra_regions = extra_regions or set()
    unique_types = sorted({(s.type, s.arch) for s in specs})
    type_to_recipes: dict[str, set[str]] = defaultdict(set)
    type_to_roles: dict[str, set[str]] = defaultdict(set)
    for s in specs:
        type_to_recipes[s.type].add(s.recipe)
        type_to_roles[s.type].add(s.role)

    def region_label(r: str) -> str:
        return f"{r} (extra)" if r in extra_regions else r

    ga_count = len([r for r in regions if r not in extra_regions])
    extra_count = len([r for r in regions if r in extra_regions])

    lines: list[str] = []
    lines.append("# PCS recipe instance availability audit\n")
    summary_parts = [f"- Regions audited: **{len(regions)}**"]
    if extra_count:
        summary_parts[-1] += (
            f" (**{ga_count}** GA from SSM, **{extra_count}** extras "
            f"supplied via `--extra-regions-file`)"
        )
    summary_parts.append(f"- Unique instance types audited: **{len(unique_types)}**")
    summary_parts.append(f"- Source manifest: `scripts/pcs_instance_manifest.yml`")
    summary_parts.append(f"- GA region list: SSM `{PCS_REGIONS_SSM_PARAM}`")
    summary_parts.append(
        f"- Region-level availability: AWS docs page "
        f"([ec2-instance-regions.html]({AWS_DOCS_URL}))"
    )
    summary_parts.append(
        "- AZ-level detail: EC2 `DescribeInstanceTypeOfferings` where "
        "credentials can reach the region"
    )
    lines.append("  \n".join(summary_parts) + "\n")

    regions_with_az = [r for r in regions if r in az_results]
    regions_without_az = [r for r in regions if r not in az_results]
    if regions_without_az:
        lines.append(
            f"\n**Region-level only** (no AZ detail — credentials cannot reach "
            f"these regions): `{', '.join(regions_without_az)}`. Run from an "
            "account with access if AZ granularity is needed.\n"
        )
    if unknown_doc_regions:
        lines.append(
            f"\n**Unknown from docs** (PCS region but not found on the public "
            f"docs page; likely page lag): `{', '.join(unknown_doc_regions)}`.\n"
        )

    lines.append("\n## Legend\n")
    lines.append(
        "- `OK` — family offered in the region (per AWS docs) and in every "
        "available AZ (per EC2 API, where we could read it).\n"
        "- `N/M` — family offered in the region, but only in N of M AZs. "
        "Matters for PCS since clusters pin to subnets; capacity-constrained "
        "families (hpc7a, hpc7g, P5) are often single-AZ.\n"
        "- `OK` without N/M in regions we couldn't reach means region-level "
        "only: the docs page confirms the family is offered, but we could not "
        "query AZ coverage.\n"
        "- `--` — not offered in the region per AWS docs.\n"
        "- `OK(?)` — docs say yes, EC2 API returned zero AZs. Usually "
        "harmless (family includes only one size; docs lag). Worth verifying.\n"
        "- `*` suffix — docs say no, EC2 API says yes. Docs page is likely "
        "lagging a recent launch. Trust the API.\n"
        "- `??` — region appears in the PCS region list but not on the docs "
        "page. Treat as unknown.\n"
        "- Column headers with `(extra)` are regions supplied by the "
        "operator via `--extra-regions-file` beyond the GA PCS region list. "
        "They are audited the same way as GA regions.\n"
        "- us-east-1 may show `5/6` for modern families because `us-east-1e` "
        "does not carry recent generations. Not a real gap if subnets are "
        "placed outside us-east-1e.\n"
    )

    # Summary: gaps by instance type.
    lines.append("\n## Gaps by instance type\n")
    lines.append(
        "Regions where the family is unavailable per docs, or where AZ "
        "coverage is partial.\n"
    )
    lines.append(
        "| Instance type | Family | Arch | Recipes | Roles | Missing regions | Partial-AZ regions |"
    )
    lines.append("| --- | --- | --- | --- | --- | --- | --- |")
    for itype, arch in unique_types:
        fam = family_of(itype)
        missing: list[str] = []
        partial: list[str] = []
        for region in regions:
            _, status = _region_cell(itype, region, doc_families, az_results)
            label = region_label(region)
            if status == "missing-region":
                missing.append(label)
            elif status == "partial-az":
                az_map = az_results[region][1]
                total_azs = az_results[region][2]
                az_have = len(az_map.get(itype, set()))
                partial.append(f"{label} ({az_have}/{total_azs})")
        recipes_col = ", ".join(sorted(type_to_recipes[itype]))
        roles_col = ", ".join(sorted(type_to_roles[itype]))
        lines.append(
            f"| `{itype}` | `{fam}` | {arch} | {recipes_col} | {roles_col} | "
            f"{', '.join(missing) if missing else '_none_'} | "
            f"{', '.join(partial) if partial else '_none_'} |"
        )

    # Full matrix.
    lines.append("\n## Full matrix\n")
    header = ["Instance type", "Arch"] + [region_label(r) for r in regions]
    lines.append("| " + " | ".join(header) + " |")
    lines.append("| " + " | ".join(["---"] * len(header)) + " |")
    for itype, arch in unique_types:
        row = [f"`{itype}`", arch]
        for region in regions:
            cell, _ = _region_cell(itype, region, doc_families, az_results)
            row.append(cell)
        lines.append("| " + " | ".join(row) + " |")

    # Per-recipe impact.
    lines.append("\n## Impact by recipe\n")
    lines.append(
        "For each recipe, the regions where at least one required instance "
        "type is missing (region-level). These are the regions where the "
        "recipe will fail without a fallback.\n"
    )
    by_recipe: dict[str, list[InstanceSpec]] = defaultdict(list)
    for s in specs:
        by_recipe[s.recipe].append(s)
    for recipe in sorted(by_recipe):
        lines.append(f"### {recipe}\n")
        blockers: dict[str, list[str]] = defaultdict(list)
        for s in by_recipe[recipe]:
            for region in regions:
                _, status = _region_cell(s.type, region, doc_families, az_results)
                if status == "missing-region":
                    blockers[region].append(f"{s.type} ({s.role})")
        if not blockers:
            lines.append(
                "_All required instance types available in every PCS region._\n"
            )
            continue
        lines.append("| Region | Missing instance types |")
        lines.append("| --- | --- |")
        for region in sorted(blockers):
            lines.append(
                f"| {region_label(region)} | {', '.join(sorted(set(blockers[region])))} |"
            )
        lines.append("")

    path.write_text("\n".join(lines))


# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--regions",
        help="Comma-separated region list to override PCS region discovery "
        "(useful for dry runs).",
    )
    p.add_argument(
        "--manifest",
        default=str(MANIFEST_PATH),
        help="Path to instance manifest YAML.",
    )
    p.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory to write report files into.",
    )
    p.add_argument("--profile", help="AWS profile to use.")
    p.add_argument(
        "--no-az",
        action="store_true",
        help="Skip EC2 AZ-level lookups. Region-level only (docs page).",
    )
    p.add_argument(
        "--docs-url",
        default=AWS_DOCS_URL,
        help="Override the AWS docs URL for region-to-family mapping.",
    )
    p.add_argument(
        "--docs-cache",
        help="Path to a local HTML cache of the docs page (for offline runs).",
    )
    p.add_argument(
        "--extra-regions-file",
        help="Path to a YAML file listing extra AWS regions to include in the "
        "audit alongside the GA PCS region list. Useful for auditing instance "
        "availability in arbitrary additional regions. File format: "
        "`regions: [{code: <region>}, ...]`. The file is not shipped with "
        "this repo; point at a path on your local system.",
    )
    return p.parse_args(list(argv) if argv is not None else None)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    session = (
        boto3.Session(profile_name=args.profile) if args.profile else boto3.Session()
    )

    specs = load_manifest(Path(args.manifest))
    unique_instance_types = sorted({s.type for s in specs})
    print(
        f"Loaded {len(specs)} instance entries "
        f"({len(unique_instance_types)} unique types)",
        file=sys.stderr,
    )

    if args.regions:
        regions = [r.strip() for r in args.regions.split(",") if r.strip()]
        print(f"Using region override: {regions}", file=sys.stderr)
        extra_regions: set[str] = set()
    else:
        ga_regions = resolve_pcs_regions(session)
        print(
            f"Discovered {len(ga_regions)} GA PCS regions: {ga_regions}",
            file=sys.stderr,
        )
        extra_regions = set()
        if args.extra_regions_file:
            extra_path = Path(args.extra_regions_file).expanduser()
            loaded = load_extra_regions(extra_path)
            for code in loaded:
                if code not in ga_regions:
                    extra_regions.add(code)
            if extra_regions:
                print(
                    f"Adding {len(extra_regions)} extra regions from "
                    f"{extra_path}: {sorted(extra_regions)}",
                    file=sys.stderr,
                )
            else:
                print(
                    f"Loaded {extra_path}; no regions to add (all already in GA list)",
                    file=sys.stderr,
                )
        regions = sorted(set(ga_regions) | extra_regions)
    if not regions:
        print("No regions to audit.", file=sys.stderr)
        return 1

    # Docs-page region-level scrape (all partitions in one shot, no creds).
    print(f"Fetching AWS docs page: {args.docs_url}", file=sys.stderr)
    if args.docs_cache:
        html = Path(args.docs_cache).read_text()
        doc_families = scrape_doc_families(html=html)
    else:
        doc_families = scrape_doc_families(url=args.docs_url)
    print(
        f"Parsed families for {len(doc_families)} regions from docs page.",
        file=sys.stderr,
    )
    unknown_doc_regions = [r for r in regions if r not in doc_families]
    if unknown_doc_regions:
        print(
            f"PCS regions not found on docs page: {unknown_doc_regions}",
            file=sys.stderr,
        )

    # AZ-level detail (optional, best-effort).
    az_results: dict[str, tuple[set[str], dict[str, set[str]], int]] = {}
    inaccessible: list[str] = []
    if args.no_az:
        print("Skipping EC2 AZ lookups (--no-az).", file=sys.stderr)
    else:
        az_results, inaccessible = audit_az_detail(
            session, regions, unique_instance_types
        )
        if inaccessible:
            print(
                f"  {len(inaccessible)} region(s) without AZ data "
                f"(credentials cannot reach): {inaccessible}",
                file=sys.stderr,
            )

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    md_path = out_dir / "audit-pcs-instances.md"
    csv_path = out_dir / "audit-pcs-instances.csv"
    write_markdown(
        md_path,
        specs,
        regions,
        doc_families,
        az_results,
        inaccessible,
        unknown_doc_regions,
        extra_regions=extra_regions,
    )
    write_csv(
        csv_path,
        specs,
        regions,
        doc_families,
        az_results,
        extra_regions=extra_regions,
    )
    print(f"Wrote {md_path}", file=sys.stderr)
    print(f"Wrote {csv_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
