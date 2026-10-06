import base64
import hashlib
import hmac
import json
import pathlib
import sys
import unittest


sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "assets" / "lambda"))

import jwt_auth


def _decode_segment(segment):
    padding = "=" * (-len(segment) % 4)
    return json.loads(base64.urlsafe_b64decode(segment + padding))


class JwtTests(unittest.TestCase):
    def test_root_claims_and_signature(self):
        key = b"a deterministic signing key"
        token = jwt_auth.create_root_jwt(
            key,
            now=1_700_000_000,
            ttl_seconds=300,
        )
        encoded_header, encoded_payload, encoded_signature = token.split(".")

        self.assertEqual(
            _decode_segment(encoded_header),
            {"alg": "HS256", "typ": "JWT"},
        )
        self.assertEqual(
            _decode_segment(encoded_payload),
            {
                "exp": 1_700_000_300,
                "iat": 1_700_000_000,
                "sun": "root",
                "uid": 0,
                "gid": 0,
                "id": {
                    "gecos": "root",
                    "dir": "/root",
                    "gids": [0],
                    "shell": "/bin/bash",
                },
            },
        )

        expected = hmac.new(
            key,
            f"{encoded_header}.{encoded_payload}".encode("ascii"),
            hashlib.sha256,
        ).digest()
        padding = "=" * (-len(encoded_signature) % 4)
        self.assertEqual(
            base64.urlsafe_b64decode(encoded_signature + padding),
            expected,
        )

    def test_decodes_base64_secret_string(self):
        self.assertEqual(
            jwt_auth.decode_signing_key(
                {"SecretString": base64.b64encode(b"secret").decode("ascii")}
            ),
            b"secret",
        )

    def test_rejects_invalid_secret_string(self):
        with self.assertRaisesRegex(ValueError, "not valid base64"):
            jwt_auth.decode_signing_key(
                {"SecretString": "not base64!"}
            )
