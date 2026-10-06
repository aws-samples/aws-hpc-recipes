import json
import logging
import re
import time
import urllib.error
import urllib.parse
import urllib.request


LOGGER = logging.getLogger(__name__)
RETRYABLE_HTTP_CODES = {429, 500, 502, 503, 504}
TESTED_API_VERSIONS = frozenset({"v0.0.44", "v0.0.45"})
API_ROUTE_PATTERN = re.compile(
    r"/(?:slurm|slurmdb)/(?P<version>v0\.0\.[0-9]+)/[^/]+/?"
)


def find_endpoint(cluster, endpoint_type):
    matches = [
        endpoint
        for endpoint in cluster.get("endpoints", [])
        if endpoint.get("type") == endpoint_type
    ]
    if len(matches) != 1:
        raise ValueError(
            f"Expected one {endpoint_type} endpoint, found {len(matches)}"
        )
    return matches[0]


def _retry_delay(attempt):
    return min(2**attempt, 8)


def _request_json(
    url,
    token,
    timeout_seconds,
    method="GET",
    payload=None,
    retries=3,
    sleep=time.sleep,
):
    body = None
    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {token}",
    }
    if payload is not None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers=headers,
    )

    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
                response_body = response.read().decode("utf-8")
                if not response_body:
                    return response.status, {}
                try:
                    return response.status, json.loads(response_body)
                except json.JSONDecodeError as error:
                    raise RuntimeError(
                        "slurmrestd returned a non-JSON response"
                    ) from error
        except urllib.error.HTTPError as error:
            response_body = error.read().decode("utf-8", errors="replace")
            if error.code in RETRYABLE_HTTP_CODES and attempt < retries:
                sleep(_retry_delay(attempt))
                continue
            raise RuntimeError(
                f"slurmrestd returned HTTP {error.code}: {response_body[:2000]}"
            ) from error
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt < retries:
                sleep(_retry_delay(attempt))
                continue
            raise RuntimeError(f"Unable to reach slurmrestd: {error}") from error

    raise AssertionError("HTTP retry loop exited unexpectedly")


def _route_exists(paths, route, method):
    for candidate in (route, f"{route}/"):
        operations = paths.get(candidate)
        if isinstance(operations, dict) and method.lower() in operations:
            return True
    return False


def _advertised_api_versions(paths):
    versions = set()
    for path in paths:
        match = API_ROUTE_PATTERN.fullmatch(path)
        if match:
            versions.add(match.group("version"))
    return versions


def _discover_api_version(
    openapi_document,
    preferred_version,
    required_upserts=(),
):
    if preferred_version != "auto" and not re.fullmatch(
        r"v0\.0\.[0-9]+",
        preferred_version,
    ):
        raise ValueError(
            f"Invalid Slurm REST API version {preferred_version!r}; "
            "expected auto or v0.0.N"
        )

    paths = openapi_document.get("paths", {})
    advertised_versions = _advertised_api_versions(paths)

    compatible_versions = []
    for version in advertised_versions:
        required_routes = [
            (f"/slurm/{version}/ping", "get"),
            (f"/slurmdb/{version}/ping", "get"),
        ]
        required_routes.extend(
            [
                (f"/slurmdb/{version}/{resource_name}", "post")
                for resource_name in required_upserts
            ]
        )
        if all(
            _route_exists(paths, route, method)
            for route, method in required_routes
        ):
            compatible_versions.append(version)

    if not compatible_versions:
        required = ", ".join(required_upserts) or "read-only validation"
        raise RuntimeError(
            "slurmrestd advertised no API version with the required "
            f"controller, database, and upsert routes ({required})"
        )

    if (
        preferred_version != "auto"
        and preferred_version in compatible_versions
    ):
        return preferred_version

    if preferred_version != "auto":
        LOGGER.warning(
            "Configured API version is unavailable; selecting the newest compatible version",
            extra={
                "configured_api_version": preferred_version,
                "available_api_versions": sorted(compatible_versions),
            },
        )

    tested_versions = set(compatible_versions) & TESTED_API_VERSIONS
    candidates = tested_versions or set(compatible_versions)
    selected_version = max(
        candidates,
        key=lambda version: tuple(int(part) for part in version[1:].split(".")),
    )
    if selected_version not in TESTED_API_VERSIONS:
        LOGGER.warning(
            "Using an untested Slurm REST API version",
            extra={
                "selected_api_version": selected_version,
                "tested_api_versions": sorted(TESTED_API_VERSIONS),
            },
        )
    return selected_version


def _raise_for_slurm_errors(response, operation):
    if not isinstance(response, dict):
        raise RuntimeError(f"{operation} returned an invalid JSON document")

    warnings = response.get("warnings") or []
    if warnings:
        LOGGER.warning(
            "Slurm operation returned warnings",
            extra={
                "operation": operation,
                "warnings": warnings[:10],
            },
        )

    errors = response.get("errors") or []
    if not errors:
        return

    summaries = []
    for error in errors[:10]:
        if isinstance(error, dict):
            summaries.append(
                str(
                    error.get("description")
                    or error.get("error")
                    or error.get("error_number")
                    or error
                )
            )
        else:
            summaries.append(str(error))
    raise RuntimeError(f"{operation} failed: {'; '.join(summaries)}")


class SlurmRestClient:
    def __init__(self, endpoint, token, timeout_seconds, retries):
        try:
            address = endpoint["privateIpAddress"]
            port = endpoint["port"]
        except KeyError as error:
            raise ValueError(
                "SLURMRESTD endpoint is missing its private address or port"
            ) from error

        self.base_url = f"http://{address}:{port}"
        self.token = token
        self.timeout_seconds = timeout_seconds
        self.retries = retries

    def _request(self, path, method="GET", payload=None):
        return _request_json(
            f"{self.base_url}{path}",
            self.token,
            self.timeout_seconds,
            method=method,
            payload=payload,
            retries=self.retries,
        )

    def verify_connectivity(self, preferred_version, required_upserts):
        _, openapi_document = self._request("/openapi/v3")
        api_version = _discover_api_version(
            openapi_document,
            preferred_version,
            required_upserts,
        )

        _, controller_response = self._request(
            f"/slurm/{api_version}/ping"
        )
        _raise_for_slurm_errors(
            controller_response,
            "Slurm controller ping",
        )

        _, database_response = self._request(
            f"/slurmdb/{api_version}/ping/"
        )
        _raise_for_slurm_errors(
            database_response,
            "Slurm database ping",
        )
        return api_version

    def upsert(self, api_version, resource_name, records, operation):
        _, response = self._request(
            f"/slurmdb/{api_version}/{resource_name}",
            method="POST",
            payload={resource_name: records},
        )
        _raise_for_slurm_errors(response, operation)

    def add_account_coordinators(
        self,
        api_version,
        coordinator_records,
    ):
        for coordinator_record in coordinator_records:
            account = coordinator_record["account"]
            account_name = account["name"]
            encoded_name = urllib.parse.quote(account_name, safe="")
            _, response = self._request(
                f"/slurmdb/{api_version}/account/{encoded_name}"
                "?with_coords=true"
            )
            _raise_for_slurm_errors(
                response,
                f"Read coordinators for account {account_name}",
            )

            current_accounts = response.get("accounts")
            if not isinstance(current_accounts, list) or len(current_accounts) != 1:
                raise RuntimeError(
                    f"Expected one Slurm account named {account_name!r}"
                )

            existing = {
                coordinator.get("name")
                for coordinator in (
                    current_accounts[0].get("coordinators") or []
                )
                if isinstance(coordinator, dict)
                and coordinator.get("name")
            }
            desired = existing | set(coordinator_record["users"])
            self.upsert(
                api_version,
                "accounts",
                [
                    {
                        **account,
                        "coordinators": [
                            {"name": user_name}
                            for user_name in sorted(desired)
                        ],
                    }
                ],
                f"Add coordinators to account {account_name}",
            )
