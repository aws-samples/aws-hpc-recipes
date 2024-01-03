import boto3
import botocore
from botocore.config import Config
from ruamel.yaml import YAML
from ruamel.yaml.compat import StringIO

from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
RECIPE = Path(SCRIPTS).resolve().parent
ASSETS = Path.joinpath(RECIPE, "assets")
TEMPLATE_FILE_NAME = Path.joinpath(ASSETS, "main.yaml")


class MyYAML(YAML):
    # Class that allows dump to string with ruamel.yaml
    def dump(self, data, stream=None, **kw):
        inefficient = False
        if stream is None:
            inefficient = True
            stream = StringIO()
        YAML.dump(self, data, stream, **kw)
        if inefficient:
            return stream.getvalue()


def zone_ids():
    # Hard-coded Zone ID strings in the CF template
    return ["ZoneId3", "ZoneId2", "ZoneId1"]


def region_map(template_file):
    # Extract the region and zone map from the CF template
    yaml = YAML(typ="rt")
    file_contents = yaml.load(template_file)
    return file_contents.get("Mappings", {}).get("RegionMap", {})


def regions():
    # Retrieve a sorted list of all available AWS regions
    account = boto3.client("account")
    regions = account.list_regions()
    status_sets = [["ENABLED"], ["ENABLED_BY_DEFAULT"], ["DISABLED"]]
    region_names = []
    for ss in status_sets:
        regions = account.list_regions(RegionOptStatusContains=ss)
        region_names.extend(
            sorted([r.get("RegionName") for r in regions.get("Regions", {})])
        )
    unique = []
    [unique.append(rn) for rn in region_names if rn not in unique]
    return sorted(unique)


def availability_zone_ids(region):
    # Retrieve active zone IDs for a region
    ec2 = boto3.client("ec2", config=Config(region_name=region))
    # TODO - consider whether to favor AZ where OptInStatus is opt-in-not-required
    zones = ec2.describe_availability_zones(
        Filters=[
            {"Name": "zone-type", "Values": ["availability-zone"]},
            {"Name": "state", "Values": ["available"]},
        ]
    ).get("AvailabilityZones")
    zone_ids = sorted(list(z.get("ZoneId") for z in zones))
    return zone_ids


def generate_mapping(region_name):
    # Generate the region + zone mapping for a region to include in the CF template
    mapping = {region_name: {}}
    region_zone_ids = availability_zone_ids(region_name)[0:3]
    zids = zone_ids()
    while zids:
        zid = zids.pop()
        rzid = region_zone_ids.pop()
        mapping[region_name][zid] = rzid
    return mapping


def render_cf_yaml(mappings):
    # Transform mappings into the requisite section of the CF template
    yaml = MyYAML()
    yaml_section = {"Mappings": {"RegionMap": {}}}
    for m in mappings:
        region_name = list(m.keys())[0]
        yaml_section["Mappings"]["RegionMap"][region_name] = {}
        for k, v in list(m.values())[0].items():
            yaml_section["Mappings"]["RegionMap"][region_name][k] = v
    return yaml.dump(yaml_section)


def main():
    print("Analyzing template file", TEMPLATE_FILE_NAME)

    # Load region mappings from CF YAML
    print("Loading template file...")
    template_regions = sorted(list(region_map(TEMPLATE_FILE_NAME).keys()))
    # Fetch available regions
    print("Fetching available regions...")
    available_regions = regions()
    # Iterate over available regions, generating a mapping for missing ones
    print("Generating RegionMap(s)...")
    mappings = []
    unauth_regions = []
    for ar in available_regions:
        if ar not in template_regions:
            try:
                mappings.append(generate_mapping(ar))
            except botocore.exceptions.ClientError:
                unauth_regions.append(ar)

    print("RESULTS")
    print(
        "The following regions are not represented in the template file, but are inaccessible to the calling AWS account:"
    )
    print(unauth_regions)
    print(
        "Additional default regions were detected. Include the following in the Mappings/RegionMap section of the template file."
    )
    print("---")
    print(render_cf_yaml(mappings))


if __name__ == "__main__":
    main()
