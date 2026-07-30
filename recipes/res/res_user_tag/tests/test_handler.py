# recipes/res/res_user_tag/tests/test_handler.py
import importlib.util
import os
from pathlib import Path

HANDLER = Path(__file__).resolve().parents[1] / "assets" / "lambda" / "handler.py"
spec = importlib.util.spec_from_file_location("handler", HANDLER)
handler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handler)


class FakeEC2:
    def __init__(self, tags):
        self._tags = tags
        self.created = []

    def describe_instances(self, InstanceIds):
        return {
            "Reservations": [
                {"Instances": [
                    {"InstanceId": InstanceIds[0],
                     "Tags": [{"Key": k, "Value": v} for k, v in self._tags.items()]}
                ]}
            ]
        }

    def create_tags(self, Resources, Tags):
        self.created.append((Resources, Tags))
        return {}


class FakeDDB:
    """Records the table name queried so cross-environment routing can be asserted."""
    def __init__(self, owner):
        self._owner = owner
        self.queried_tables = []

    def query(self, **kwargs):
        self.queried_tables.append(kwargs.get("TableName"))
        if self._owner is None:
            return {"Items": []}
        return {"Items": [{"owner": {"S": self._owner}}]}


def test_is_res_dcv_host_true():
    assert handler.is_res_dcv_host({"res:NodeType": "virtual-desktop-dcv-host"}) is True


def test_is_res_dcv_host_not_dcv():
    assert handler.is_res_dcv_host({"res:NodeType": "scheduler"}) is False


def test_env_name_from_tags():
    assert handler.env_name_from_tags({"res:EnvironmentName": "res-green"}) == "res-green"


def test_env_name_from_tags_missing():
    assert handler.env_name_from_tags({"res:NodeType": "virtual-desktop-dcv-host"}) is None


def test_resolve_owner_found():
    assert handler.resolve_owner("i-abc", FakeDDB("domorand"), "res-blue") == "domorand"


def test_resolve_owner_queries_env_specific_table():
    ddb = FakeDDB("domorand")
    handler.resolve_owner("i-abc", ddb, "res-green")
    assert ddb.queried_tables == ["res-green.vdc.controller.user-sessions"]


def test_resolve_owner_missing():
    assert handler.resolve_owner("i-abc", FakeDDB(None), "res-blue") is None


def _dcv_event():
    return {"detail": {"instance-id": "i-abc", "state": "running"}}


def test_handler_tags_dcv_host():
    ec2 = FakeEC2({"res:NodeType": "virtual-desktop-dcv-host", "res:EnvironmentName": "res-blue"})
    ddb = FakeDDB("domorand")
    handler.lambda_handler(_dcv_event(), None, ec2_client=ec2, ddb_client=ddb)
    assert ec2.created == [(["i-abc"], [{"Key": "res:User", "Value": "domorand"}])]
    assert ddb.queried_tables == ["res-blue.vdc.controller.user-sessions"]


def test_handler_routes_by_environment_tag():
    # Same code path, different env tag -> different table. Proves blue/green works
    # with one deployment and survives new environments with no change.
    ec2 = FakeEC2({"res:NodeType": "virtual-desktop-dcv-host", "res:EnvironmentName": "res-green"})
    ddb = FakeDDB("bob")
    handler.lambda_handler(_dcv_event(), None, ec2_client=ec2, ddb_client=ddb)
    assert ec2.created == [(["i-abc"], [{"Key": "res:User", "Value": "bob"}])]
    assert ddb.queried_tables == ["res-green.vdc.controller.user-sessions"]


def test_handler_skips_non_dcv():
    ec2 = FakeEC2({"res:NodeType": "scheduler", "res:EnvironmentName": "res-blue"})
    ddb = FakeDDB("domorand")
    handler.lambda_handler(_dcv_event(), None, ec2_client=ec2, ddb_client=ddb)
    assert ec2.created == []


def test_handler_skips_when_env_tag_missing():
    ec2 = FakeEC2({"res:NodeType": "virtual-desktop-dcv-host"})
    ddb = FakeDDB("domorand")
    handler.lambda_handler(_dcv_event(), None, ec2_client=ec2, ddb_client=ddb)
    assert ec2.created == []


def test_handler_skips_when_no_owner():
    ec2 = FakeEC2({"res:NodeType": "virtual-desktop-dcv-host", "res:EnvironmentName": "res-blue"})
    ddb = FakeDDB(None)
    handler.lambda_handler(_dcv_event(), None, ec2_client=ec2, ddb_client=ddb)
    assert ec2.created == []
