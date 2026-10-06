import base64
import pathlib
import sys
import unittest
from unittest import mock


sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "assets" / "lambda"))

import handler
import slurm_rest
from test_support import openapi


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.cluster = {
            "id": "pcs_123",
            "name": "my-cluster",
            "status": "ACTIVE",
            "endpoints": [
                {
                    "type": "SLURMRESTD",
                    "privateIpAddress": "10.0.0.10",
                    "port": "6820",
                }
            ],
            "slurmConfiguration": {
                "accounting": {"mode": "STANDARD"},
                "slurmRest": {"mode": "STANDARD"},
                "jwtAuth": {
                    "jwtKey": {
                        "secretArn": "arn:secret",
                        "secretVersion": "version",
                    }
                },
            },
        }
        self.pcs = mock.Mock()
        self.pcs.get_cluster.return_value = {"cluster": self.cluster}
        self.secrets = mock.Mock()
        self.secrets.get_secret_value.return_value = {
            "SecretString": base64.b64encode(b"secret").decode("ascii")
        }

    def _run(self, event):
        return handler._run_bootstrap(
            event=event,
            pcs=self.pcs,
            secrets_manager=self.secrets,
            cluster_identifier="pcs_123",
            preferred_api_version="auto",
            ttl_seconds=300,
            timeout_seconds=15,
            retries=3,
            now=1_700_000_000,
        )

    def test_upserts_resources_in_dependency_order(self):
        event = {
            "accounts": {"research": {}},
            "qos": {"normal": {}},
            "users": {"alice": {}},
            "associations": [
                {"account": "research", "user": "alice"}
            ],
        }
        calls = []

        def request(url, token, timeout, method="GET", payload=None, retries=3):
            del token, timeout, retries
            calls.append((url, method, payload))
            if url.endswith("/openapi/v3"):
                return 200, openapi("v0.0.44", "v0.0.45")
            return 200, {"errors": []}

        with mock.patch.object(
            slurm_rest,
            "_request_json",
            side_effect=request,
        ):
            result = self._run(event)

        post_calls = [call for call in calls if call[1] == "POST"]
        self.assertEqual(
            [call[0].rsplit("/", 1)[-1] for call in post_calls],
            ["qos", "accounts", "users", "associations"],
        )
        self.assertEqual(
            [call[2] for call in post_calls],
            [
                {"qos": [{"name": "normal"}]},
                {
                    "accounts": [
                        {
                            "description": "research",
                            "name": "research",
                            "organization": "research",
                        }
                    ]
                },
                {"users": [{"name": "alice"}]},
                {
                    "associations": [
                        {
                            "account": "research",
                            "cluster": "my-cluster",
                            "parent_account": "root",
                            "user": None,
                        },
                        {
                            "account": "research",
                            "user": "alice",
                            "cluster": "my-cluster",
                        },
                    ]
                },
            ],
        )
        self.assertEqual(
            result["upserted"],
            {
                "accounts": 1,
                "qos": 1,
                "users": 1,
                "associations": 2,
                "wckeys": 0,
                "coordinators": 0,
            },
        )
        self.assertEqual(result["apiVersion"], "v0.0.45")

    def test_empty_configuration_only_validates_connectivity(self):
        calls = []

        def request(url, token, timeout, method="GET", payload=None, retries=3):
            del token, timeout, payload, retries
            calls.append((url, method))
            if url.endswith("/openapi/v3"):
                return 200, openapi("v0.0.44")
            return 200, {"errors": []}

        with mock.patch.object(
            slurm_rest,
            "_request_json",
            side_effect=request,
        ):
            result = self._run({})

        self.assertFalse(any(method == "POST" for _, method in calls))
        self.assertEqual(
            result["upserted"],
            {
                "accounts": 0,
                "qos": 0,
                "users": 0,
                "associations": 0,
                "wckeys": 0,
                "coordinators": 0,
            },
        )

    def test_rejects_inactive_cluster_before_rest_calls(self):
        self.cluster["status"] = "UPDATING"
        with self.assertRaisesRegex(RuntimeError, "not ACTIVE"):
            self._run({})

    def test_requires_accounting(self):
        self.cluster["slurmConfiguration"]["accounting"]["mode"] = "NONE"
        with self.assertRaisesRegex(RuntimeError, "accounting mode"):
            self._run({})

    def test_requires_slurm_rest(self):
        self.cluster["slurmConfiguration"]["slurmRest"]["mode"] = "NONE"
        with self.assertRaisesRegex(RuntimeError, "Slurm REST mode"):
            self._run({})

    def test_requires_jwt_signing_key(self):
        del self.cluster["slurmConfiguration"]["jwtAuth"]["jwtKey"]
        with self.assertRaisesRegex(RuntimeError, "JWT signing key"):
            self._run({})
