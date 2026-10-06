import pathlib
import sys
import unittest


sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "assets" / "lambda"))

import configuration
from accounting_fields import (
    ASSOCIATION_FIELDS,
    ASSOCIATION_LIMIT_FIELDS,
    ASSOCIATION_TRES_FIELDS,
    QOS_FIELDS,
    QOS_FLOAT_LIMIT_FIELDS,
    QOS_LIMIT_FIELDS,
    QOS_TRES_FIELDS,
)


class ConfigurationTests(unittest.TestCase):
    @staticmethod
    def _set_path(record, path, value):
        target = record
        keys = path.split(".")
        for key in keys[:-1]:
            target = target.setdefault(key, {})
        target[keys[-1]] = value

    def test_expands_map_keys_and_injects_cluster(self):
        self.assertEqual(
            configuration.normalize_configuration(
                {
                    "accounts": {"research": {"description": "Research"}},
                    "qos": {"normal": None},
                    "users": {"alice": {}},
                    "associations": [
                        {"account": "research", "user": "alice"}
                    ],
                },
                "my-cluster",
            ),
            {
                "accounts": [
                    {
                        "description": "Research",
                        "name": "research",
                        "organization": "research",
                    }
                ],
                "qos": [{"name": "normal"}],
                "users": [{"name": "alice"}],
                "wckeys": [],
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
                ],
                "coordinators": [],
            },
        )

    def test_rejects_cross_cluster_association(self):
        with self.assertRaisesRegex(ValueError, "must be 'my-cluster'"):
            configuration.normalize_configuration(
                {
                    "associations": [
                        {
                            "cluster": "another-cluster",
                            "account": "research",
                        }
                    ]
                },
                "my-cluster",
            )

    def test_explicit_account_association_is_not_duplicated(self):
        normalized = configuration.normalize_configuration(
            {
                "accounts": {"research": {}},
                "associations": [
                    {
                        "account": "research",
                        "parent_account": "root",
                    }
                ],
            },
            "my-cluster",
        )
        self.assertEqual(
            normalized["associations"],
            [
                {
                    "account": "research",
                    "parent_account": "root",
                    "cluster": "my-cluster",
                    "user": None,
                }
            ],
        )

    def test_rejects_partition_without_user(self):
        with self.assertRaisesRegex(ValueError, "partition requires a user"):
            configuration.normalize_configuration(
                {
                    "accounts": {"research": {}},
                    "associations": [
                        {
                            "account": "research",
                            "partition": "batch",
                        }
                    ]
                },
                "my-cluster",
            )

    def test_rejects_default_account_flag_without_nonpartition_user(self):
        cases = [
            {
                "accounts": {"research": {}},
                "associations": [
                    {"account": "research", "is_default": False}
                ],
            },
            {
                "accounts": {"research": {}},
                "users": {"alice": {}},
                "associations": [
                    {
                        "account": "research",
                        "user": "alice",
                        "partition": "batch",
                        "is_default": True,
                    }
                ],
            },
        ]
        for event in cases:
            with self.subTest(event=event):
                with self.assertRaisesRegex(
                    ValueError,
                    "requires a non-partition user association",
                ):
                    configuration.normalize_configuration(
                        event,
                        "my-cluster",
                    )

    def test_rejects_association_account_not_in_accounts(self):
        with self.assertRaisesRegex(
            ValueError,
            "'research' is not defined in accounts",
        ):
            configuration.normalize_configuration(
                {
                    "users": {"alice": {}},
                    "associations": [
                        {
                            "account": "research",
                            "user": "alice",
                        }
                    ],
                },
                "my-cluster",
            )

    def test_rejects_association_user_not_in_users(self):
        with self.assertRaisesRegex(
            ValueError,
            "'alice' is not defined in users",
        ):
            configuration.normalize_configuration(
                {
                    "accounts": {"research": {}},
                    "associations": [
                        {
                            "account": "research",
                            "user": "alice",
                        }
                    ],
                },
                "my-cluster",
            )

    def test_rejects_parent_not_in_accounts(self):
        with self.assertRaisesRegex(
            ValueError,
            "'engineering' is not defined in accounts",
        ):
            configuration.normalize_configuration(
                {
                    "accounts": {"simulation": {}},
                    "associations": [
                        {
                            "account": "simulation",
                            "parent_account": "engineering",
                        }
                    ],
                },
                "my-cluster",
            )

    def test_rejects_duplicate_user_association(self):
        association = {
            "account": "research",
            "user": "alice",
        }
        with self.assertRaisesRegex(
            ValueError,
            "Multiple user associations configured",
        ):
            configuration.normalize_configuration(
                {
                    "accounts": {"research": {}},
                    "users": {"alice": {}},
                    "associations": [association, association],
                },
                "my-cluster",
            )

    def test_rejects_conflicting_name(self):
        with self.assertRaisesRegex(ValueError, "conflicts"):
            configuration.normalize_configuration(
                {"accounts": {"research": {"name": "other"}}},
                "my-cluster",
            )

    def test_normalizes_supported_attributes(self):
        normalized = configuration.normalize_configuration(
            {
                "accounts": {
                    "research": {
                        "coordinators": ["alice"],
                        "description": "Research",
                        "organization": "Example",
                    }
                },
                "qos": {
                    "normal": {
                        "description": "Normal work",
                        "limits": {
                            "max": {
                                "active_jobs": {"count": 10},
                                "tres": {
                                    "per": {
                                        "job": [
                                            {"type": "cpu", "count": 8}
                                        ]
                                    }
                                },
                            }
                        },
                        "priority": 100,
                    }
                },
                "users": {
                    "alice": {
                        "administrator_level": ["Operator"],
                        "default": {
                            "account": "research",
                            "wckey": "primary",
                        },
                        "wckeys": ["secondary"],
                    }
                },
                "associations": [
                    {
                        "account": "research",
                        "default": {"qos": "normal"},
                        "qos": ["normal"],
                        "shares_raw": 10,
                        "user": "alice",
                    }
                ],
            },
            "my-cluster",
        )

        self.assertEqual(
            normalized["users"],
            [
                {
                    "administrator_level": ["Operator"],
                    "default": {"wckey": "primary"},
                    "name": "alice",
                }
            ],
        )
        self.assertEqual(
            normalized["wckeys"],
            [
                {
                    "cluster": "my-cluster",
                    "name": "secondary",
                    "user": "alice",
                },
                {
                    "cluster": "my-cluster",
                    "name": "primary",
                    "user": "alice",
                },
            ],
        )
        self.assertTrue(normalized["associations"][-1]["is_default"])
        self.assertEqual(
            normalized["coordinators"],
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

    def test_rejects_unknown_fields_for_every_input_type(self):
        cases = [
            {"accounts": {"research": {"unknown": True}}},
            {"qos": {"normal": {"unknown": True}}},
            {"users": {"alice": {"unknown": True}}},
            {
                "accounts": {"research": {}},
                "associations": [
                    {"account": "research", "unknown": True}
                ],
            },
        ]
        for event in cases:
            with self.subTest(event=event):
                with self.assertRaisesRegex(
                    ValueError,
                    "is not a supported field",
                ):
                    configuration.normalize_configuration(
                        event,
                        "my-cluster",
                    )

    def test_rejects_structured_inputs_with_sacctmgr_load(self):
        with self.assertRaisesRegex(ValueError, "cannot be combined"):
            configuration.normalize_configuration(
                {
                    "accounts": {"research": {}},
                    "sacctmgr_load": "Cluster - 'source'",
                },
                "my-cluster",
            )

    def test_rejects_qos_reference_not_in_configuration(self):
        with self.assertRaisesRegex(
            ValueError,
            "QOS not defined in qos: high",
        ):
            configuration.normalize_configuration(
                {
                    "accounts": {"research": {}},
                    "users": {"alice": {}},
                    "associations": [
                        {
                            "account": "research",
                            "qos": ["high"],
                            "user": "alice",
                        }
                    ],
                },
                "my-cluster",
            )

    def test_rejects_qos_preemption_cycle(self):
        with self.assertRaisesRegex(ValueError, "preemption cycle"):
            configuration.normalize_configuration(
                {
                    "qos": {
                        "high": {"preempt": {"list": ["normal"]}},
                        "normal": {"preempt": {"list": ["high"]}},
                    }
                },
                "my-cluster",
            )

    def test_validates_every_association_field_kind(self):
        non_limit_fields = {
            "account",
            "cluster",
            "default.qos",
            "is_default",
            "parent_account",
            "partition",
            "qos",
            "shares_raw",
            "user",
        }
        self.assertEqual(
            ASSOCIATION_FIELDS,
            non_limit_fields
            | ASSOCIATION_LIMIT_FIELDS
            | ASSOCIATION_TRES_FIELDS,
        )

    def test_validates_every_qos_field_kind(self):
        non_limit_fields = {
            "description",
            "flags",
            "limits.grace_time",
            "preempt.list",
            "preempt.mode",
        }
        self.assertEqual(
            QOS_FIELDS,
            non_limit_fields
            | QOS_LIMIT_FIELDS
            | QOS_FLOAT_LIMIT_FIELDS
            | QOS_TRES_FIELDS,
        )

    def test_accepts_every_structured_action_field(self):
        qos = {
            "description": "Normal work",
            "flags": ["NO_DECAY"],
            "preempt": {
                "exempt_time": 60,
                "list": ["secondary"],
                "mode": ["CANCEL"],
            },
        }
        for field in QOS_LIMIT_FIELDS:
            self._set_path(qos, field, 1)
        for field in QOS_FLOAT_LIMIT_FIELDS:
            self._set_path(qos, field, 1.5)
        for field in QOS_TRES_FIELDS:
            self._set_path(
                qos,
                field,
                [{"type": "cpu", "count": 1}],
            )
        self._set_path(qos, "limits.grace_time", 30)

        user_association = {
            "account": "research",
            "default": {"qos": "normal"},
            "is_default": True,
            "qos": ["normal"],
            "shares_raw": 10,
            "user": "alice",
        }
        for field in ASSOCIATION_LIMIT_FIELDS:
            self._set_path(user_association, field, 1)
        for field in ASSOCIATION_TRES_FIELDS:
            self._set_path(
                user_association,
                field,
                [{"type": "cpu", "count": 1}],
            )

        normalized = configuration.normalize_configuration(
            {
                "accounts": {
                    "research": {
                        "coordinators": ["alice"],
                        "description": "Research",
                        "organization": "Example",
                    }
                },
                "qos": {
                    "normal": qos,
                    "secondary": {},
                },
                "users": {
                    "alice": {
                        "administrator_level": ["Operator"],
                        "default": {"wckey": "primary"},
                        "wckeys": ["secondary"],
                    }
                },
                "associations": [
                    {
                        "account": "research",
                        "parent_account": "root",
                    },
                    user_association,
                    {
                        "account": "research",
                        "partition": "batch",
                        "user": "alice",
                    },
                ],
            },
            "my-cluster",
        )

        self.assertEqual(len(normalized["qos"]), 2)
        self.assertEqual(len(normalized["associations"]), 3)
        self.assertEqual(len(normalized["wckeys"]), 2)
        self.assertEqual(normalized["coordinators"][0]["users"], ["alice"])

    def test_rejects_invalid_scalar_values_before_rest(self):
        cases = [
            (
                {
                    "accounts": {"research": {}},
                    "associations": [
                        {"account": "research", "priority": "high"}
                    ],
                },
                "associations\\[0\\]\\.priority",
            ),
            (
                {"qos": {"normal": {"priority": -1}}},
                "qos\\.normal\\.priority",
            ),
            (
                {"qos": {"normal": {"usage_factor": float("inf")}}},
                "qos\\.normal\\.usage_factor",
            ),
            (
                {
                    "qos": {
                        "normal": {
                            "limits": {
                                "grace_time": None,
                            }
                        }
                    }
                },
                "qos\\.normal\\.limits\\.grace_time",
            ),
            (
                {
                    "qos": {
                        "normal": {
                            "priority": {
                                "infinite": False,
                            }
                        }
                    }
                },
                "must use exactly",
            ),
            (
                {
                    "qos": {
                        "normal": {
                            "limits": {
                                "max": {
                                    "tres": {
                                        "total": [
                                            {"type": "cpu", "count": -1}
                                        ]
                                    }
                                }
                            }
                        }
                    }
                },
                "count must be a non-negative integer",
            ),
            (
                {
                    "qos": {
                        "normal": {
                            "limits": {
                                "max": {
                                    "tres": {
                                        "total": [],
                                    }
                                }
                            }
                        }
                    }
                },
                "must contain at least one TRES object",
            ),
            (
                {
                    "accounts": {"research": {}},
                    "users": {"alice": {}},
                    "associations": [
                        {
                            "account": "research",
                            "qos": [],
                            "user": "alice",
                        }
                    ],
                },
                "must contain at least one QOS",
            ),
        ]
        for event, message in cases:
            with self.subTest(event=event):
                with self.assertRaisesRegex(ValueError, message):
                    configuration.normalize_configuration(
                        event,
                        "my-cluster",
                    )

    def test_accepts_no_value_scalar_forms(self):
        normalized = configuration.normalize_configuration(
            {
                "accounts": {"research": {}},
                "qos": {
                    "normal": {
                        "limits": {
                            "factor": None,
                            "max": {
                                "active_jobs": {
                                    "count": {"infinite": True},
                                }
                            },
                        },
                        "usage_factor": 1.5,
                    }
                },
                "associations": [
                    {
                        "account": "research",
                        "priority": None,
                        "max": {
                            "jobs": {
                                "active": {"infinite": True},
                            }
                        },
                    }
                ],
            },
            "my-cluster",
        )

        self.assertIsNone(normalized["qos"][0]["limits"]["factor"])
        self.assertEqual(
            normalized["associations"][0]["max"]["jobs"]["active"],
            {"infinite": True},
        )


class AssociationOrderingTests(unittest.TestCase):
    def test_orders_parent_before_child(self):
        child = {
            "account": "simulation",
            "cluster": "my-cluster",
            "parent_account": "engineering",
            "user": None,
        }
        parent = {
            "account": "engineering",
            "cluster": "my-cluster",
            "parent_account": "root",
            "user": None,
        }

        self.assertEqual(
            configuration.order_account_associations([child, parent]),
            [parent, child],
        )

    def test_rejects_missing_parent(self):
        with self.assertRaisesRegex(
            ValueError,
            "simulation -> engineering",
        ):
            configuration.order_account_associations(
                [
                    {
                        "account": "simulation",
                        "cluster": "my-cluster",
                        "parent_account": "engineering",
                        "user": None,
                    }
                ],
            )

    def test_rejects_parent_cycle(self):
        with self.assertRaisesRegex(
            ValueError,
            "parent cycle detected: engineering, simulation",
        ):
            configuration.order_account_associations(
                [
                    {
                        "account": "engineering",
                        "cluster": "my-cluster",
                        "parent_account": "simulation",
                        "user": None,
                    },
                    {
                        "account": "simulation",
                        "cluster": "my-cluster",
                        "parent_account": "engineering",
                        "user": None,
                    },
                ],
            )

    def test_rejects_duplicate_account_association(self):
        association = {
            "account": "engineering",
            "cluster": "my-cluster",
            "parent_account": "root",
            "user": None,
        }
        with self.assertRaisesRegex(
            ValueError,
            "Multiple cluster-level associations",
        ):
            configuration.order_account_associations(
                [association, association],
            )

    def test_rejects_self_parent(self):
        with self.assertRaisesRegex(ValueError, "cannot be its own parent"):
            configuration.order_account_associations(
                [
                    {
                        "account": "engineering",
                        "cluster": "my-cluster",
                        "parent_account": "engineering",
                        "user": None,
                    }
                ]
            )
