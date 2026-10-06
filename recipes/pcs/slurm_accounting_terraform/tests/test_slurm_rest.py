import pathlib
import sys
import unittest
from unittest import mock


sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "assets" / "lambda"))

import slurm_rest
from test_support import openapi


class EndpointTests(unittest.TestCase):
    def test_finds_endpoint_by_type(self):
        cluster = {
            "endpoints": [
                {"type": "SLURMCTLD", "port": "6817"},
                {"type": "SLURMRESTD", "port": "6820"},
            ]
        }
        self.assertEqual(
            slurm_rest.find_endpoint(cluster, "SLURMRESTD"),
            {"type": "SLURMRESTD", "port": "6820"},
        )

    def test_requires_exactly_one_endpoint(self):
        with self.assertRaisesRegex(ValueError, "found 0"):
            slurm_rest.find_endpoint(
                {"endpoints": []},
                "SLURMRESTD",
            )


class ApiVersionTests(unittest.TestCase):
    def test_selects_preferred_compatible_version(self):
        self.assertEqual(
            slurm_rest._discover_api_version(
                openapi("v0.0.44", "v0.0.45"),
                "v0.0.44",
                ("accounts",),
            ),
            "v0.0.44",
        )

    def test_auto_selects_highest_version(self):
        self.assertEqual(
            slurm_rest._discover_api_version(
                openapi("v0.0.43", "v0.0.44", "v0.0.45"),
                "auto",
                ("accounts", "users"),
            ),
            "v0.0.45",
        )

    def test_auto_prefers_tested_version_over_newer_version(self):
        self.assertEqual(
            slurm_rest._discover_api_version(
                openapi("v0.0.45", "v0.0.46"),
                "auto",
                ("qos",),
            ),
            "v0.0.45",
        )

    def test_accepts_explicit_newer_compatible_version(self):
        self.assertEqual(
            slurm_rest._discover_api_version(
                openapi("v0.0.46"),
                "v0.0.46",
                ("accounts",),
            ),
            "v0.0.46",
        )

    def test_auto_uses_newer_version_when_no_tested_version_is_available(self):
        with self.assertLogs(slurm_rest.LOGGER, level="WARNING") as logs:
            selected = slurm_rest._discover_api_version(
                openapi("v0.0.46"), "auto", ("accounts",)
            )

        self.assertEqual(selected, "v0.0.46")
        self.assertTrue(
            any("untested Slurm REST API version" in line for line in logs.output)
        )

    def test_rejects_invalid_preferred_version(self):
        with self.assertRaisesRegex(ValueError, "expected auto or v0.0.N"):
            slurm_rest._discover_api_version(
                openapi("v0.0.45"),
                "latest",
                ("accounts",),
            )

    def test_requires_requested_upsert_route(self):
        document = openapi("v0.0.44")
        del document["paths"]["/slurmdb/v0.0.44/qos"]
        with self.assertRaisesRegex(RuntimeError, "no API version"):
            slurm_rest._discover_api_version(
                document,
                "auto",
                ("qos",),
            )


class SlurmErrorTests(unittest.TestCase):
    def test_empty_errors_are_success(self):
        slurm_rest._raise_for_slurm_errors(
            {"errors": []},
            "operation",
        )

    def test_errors_fail_the_invocation(self):
        with self.assertRaisesRegex(RuntimeError, "permission denied"):
            slurm_rest._raise_for_slurm_errors(
                {"errors": [{"description": "permission denied"}]},
                "operation",
            )


class SlurmRestClientTests(unittest.TestCase):
    def setUp(self):
        self.client = slurm_rest.SlurmRestClient(
            {
                "privateIpAddress": "10.0.0.10",
                "port": "6820",
            },
            "token",
            15,
            3,
        )

    def test_posts_resource_records_to_supported_versions(self):
        for version in ("v0.0.44", "v0.0.45"):
            with self.subTest(version=version), mock.patch.object(
                self.client,
                "_request",
                return_value=(200, {"errors": []}),
            ) as request:
                self.client.upsert(
                    version,
                    "accounts",
                    [{"name": "research"}],
                    "Upsert accounts",
                )

            request.assert_called_once_with(
                f"/slurmdb/{version}/accounts",
                method="POST",
                payload={"accounts": [{"name": "research"}]},
            )

    def test_coordinator_updates_preserve_existing_users(self):
        responses = [
            (
                200,
                {
                    "accounts": [
                        {
                            "name": "research",
                            "coordinators": [{"name": "existing"}],
                        }
                    ],
                    "errors": [],
                },
            ),
            (200, {"errors": []}),
        ]
        with mock.patch.object(
            self.client,
            "_request",
            side_effect=responses,
        ) as request:
            self.client.add_account_coordinators(
                "v0.0.44",
                [
                    {
                        "account": {
                            "description": "Research",
                            "name": "research",
                            "organization": "Example",
                        },
                        "users": ["alice"],
                    }
                ],
            )

        self.assertEqual(
            request.call_args_list,
            [
                mock.call(
                    "/slurmdb/v0.0.44/account/research?with_coords=true"
                ),
                mock.call(
                    "/slurmdb/v0.0.44/accounts",
                    method="POST",
                    payload={
                        "accounts": [
                            {
                                "coordinators": [
                                    {"name": "alice"},
                                    {"name": "existing"},
                                ],
                                "description": "Research",
                                "name": "research",
                                "organization": "Example",
                            }
                        ]
                    },
                ),
            ],
        )
