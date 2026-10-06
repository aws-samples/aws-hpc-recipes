import math

from accounting_fields import (
    ADMINISTRATOR_LEVELS,
    ASSOCIATION_LIMIT_FIELDS,
    ASSOCIATION_TRES_FIELDS,
    PREEMPT_MODES,
    QOS_FLAGS,
    QOS_FLOAT_LIMIT_FIELDS,
    QOS_LIMIT_FIELDS,
    QOS_TRES_FIELDS,
    SUPPORTED_FIELDS,
)


MISSING = object()


def validate_supported_fields(fields, record_path, allowed_fields):
    def visit(value, path):
        for key, child in value.items():
            if not isinstance(key, str) or not key:
                raise ValueError(f"{record_path} field names must be strings")

            child_path = f"{path}.{key}" if path else key
            if child_path in allowed_fields:
                continue
            if any(
                field.startswith(f"{child_path}.")
                for field in allowed_fields
            ):
                if not isinstance(child, dict):
                    raise ValueError(
                        f"{record_path}.{child_path} must be an object"
                    )
                visit(child, child_path)
                continue
            raise ValueError(
                f"{record_path}.{child_path} is not a supported field"
            )

    visit(fields, "")


def nested_value(record, path, default=None):
    value = record
    for key in path.split("."):
        if not isinstance(value, dict) or key not in value:
            return default
        value = value[key]
    return value


def validate_string_list(value, path, allowed_values=None):
    if not isinstance(value, list) or not all(
        isinstance(item, str) and item
        for item in value
    ):
        raise ValueError(f"{path} must be a list of non-empty strings")
    if allowed_values is not None:
        invalid = sorted(set(value) - allowed_values)
        if invalid:
            raise ValueError(
                f"{path} contains unsupported values: {', '.join(invalid)}"
            )


def _validate_tres_list(value, path):
    if not isinstance(value, list):
        raise ValueError(f"{path} must be a list of TRES objects")
    if not value:
        raise ValueError(f"{path} must contain at least one TRES object")

    seen = set()
    for index, tres in enumerate(value):
        item_path = f"{path}[{index}]"
        if not isinstance(tres, dict):
            raise ValueError(f"{item_path} must be an object")
        unknown = sorted(set(tres) - {"count", "name", "type"})
        if unknown:
            raise ValueError(
                f"{item_path} contains unsupported fields: "
                + ", ".join(unknown)
            )
        if not isinstance(tres.get("type"), str) or not tres["type"]:
            raise ValueError(f"{item_path}.type must be a non-empty string")
        if "name" in tres and (
            not isinstance(tres["name"], str) or not tres["name"]
        ):
            raise ValueError(f"{item_path}.name must be a non-empty string")
        if "count" in tres and (
            not isinstance(tres["count"], int)
            or isinstance(tres["count"], bool)
            or tres["count"] < 0
        ):
            raise ValueError(
                f"{item_path}.count must be a non-negative integer"
            )

        identity = (tres["type"], tres.get("name"))
        if identity in seen:
            raise ValueError(f"{path} contains duplicate TRES {identity!r}")
        seen.add(identity)


def _validate_unsigned(value, path, *, allow_null):
    if value is None and allow_null:
        return
    if isinstance(value, dict) and allow_null:
        if value == {"infinite": True}:
            return
        raise ValueError(
            f"{path} must use exactly {{\"infinite\": true}} "
            "for an unlimited value"
        )
    if (
        not isinstance(value, int)
        or isinstance(value, bool)
        or value < 0
    ):
        expected = "a non-negative integer"
        if allow_null:
            expected += ", null, or {\"infinite\": true}"
        raise ValueError(f"{path} must be {expected}")


def _validate_float_limit(value, path):
    if value is None or value == {"infinite": True}:
        return
    if (
        not isinstance(value, (int, float))
        or isinstance(value, bool)
        or not math.isfinite(value)
    ):
        raise ValueError(
            f"{path} must be a finite number, null, "
            "or {\"infinite\": true}"
        )


def _validate_paths(record, fields, validator, record_path):
    for field in fields:
        value = nested_value(record, field, MISSING)
        if value is not MISSING:
            validator(value, f"{record_path}.{field}")


def validate_record_values(record, record_type, record_path):
    if record_type == "accounts":
        for field in ("description", "organization"):
            value = record.get(field)
            if value is not None and not isinstance(value, str):
                raise ValueError(f"{record_path}.{field} must be a string")

    if record_type == "users":
        administrator_level = record.get("administrator_level")
        if administrator_level is not None:
            validate_string_list(
                administrator_level,
                f"{record_path}.administrator_level",
                ADMINISTRATOR_LEVELS,
            )
            if len(administrator_level) != 1:
                raise ValueError(
                    f"{record_path}.administrator_level must contain one value"
                )
        for field in ("default.account", "default.wckey"):
            value = nested_value(record, field)
            if value is not None and (
                not isinstance(value, str) or not value
            ):
                raise ValueError(
                    f"{record_path}.{field} must be a non-empty string"
                )

    if record_type == "qos":
        description = record.get("description")
        if description is not None and not isinstance(description, str):
            raise ValueError(f"{record_path}.description must be a string")
        flags = record.get("flags")
        if flags is not None:
            validate_string_list(
                flags,
                f"{record_path}.flags",
                QOS_FLAGS,
            )
        preempt_modes = nested_value(record, "preempt.mode")
        if preempt_modes is not None:
            validate_string_list(
                preempt_modes,
                f"{record_path}.preempt.mode",
                PREEMPT_MODES,
            )
        preempt_list = nested_value(record, "preempt.list")
        if preempt_list is not None:
            validate_string_list(
                preempt_list,
                f"{record_path}.preempt.list",
            )
        grace_time = nested_value(record, "limits.grace_time", MISSING)
        if grace_time is not MISSING:
            _validate_unsigned(
                grace_time,
                f"{record_path}.limits.grace_time",
                allow_null=False,
            )
        _validate_paths(
            record,
            QOS_LIMIT_FIELDS,
            lambda value, path: _validate_unsigned(
                value,
                path,
                allow_null=True,
            ),
            record_path,
        )
        _validate_paths(
            record,
            QOS_FLOAT_LIMIT_FIELDS,
            _validate_float_limit,
            record_path,
        )
        tres_fields = QOS_TRES_FIELDS
    elif record_type == "associations":
        default_qos = nested_value(record, "default.qos")
        if default_qos is not None and (
            not isinstance(default_qos, str) or not default_qos
        ):
            raise ValueError(
                f"{record_path}.default.qos must be a non-empty string"
            )
        if "is_default" in record and not isinstance(
            record["is_default"],
            bool,
        ):
            raise ValueError(f"{record_path}.is_default must be a boolean")
        qos = record.get("qos")
        if qos is not None:
            validate_string_list(qos, f"{record_path}.qos")
            if not qos:
                raise ValueError(
                    f"{record_path}.qos must contain at least one QOS"
                )
        shares_raw = record.get("shares_raw", MISSING)
        if shares_raw is not MISSING:
            _validate_unsigned(
                shares_raw,
                f"{record_path}.shares_raw",
                allow_null=False,
            )
        _validate_paths(
            record,
            ASSOCIATION_LIMIT_FIELDS,
            lambda value, path: _validate_unsigned(
                value,
                path,
                allow_null=True,
            ),
            record_path,
        )
        tres_fields = ASSOCIATION_TRES_FIELDS
    else:
        tres_fields = ()

    for field in tres_fields:
        value = nested_value(record, field)
        if value is not None:
            _validate_tres_list(value, f"{record_path}.{field}")


def validate_record(record, record_type, record_path):
    validate_supported_fields(
        record,
        record_path,
        SUPPORTED_FIELDS[record_type],
    )
    validate_record_values(record, record_type, record_path)


def named_records(configuration, record_type):
    records = configuration.get(record_type, {})
    if not isinstance(records, dict):
        raise ValueError(f"{record_type} must be an object keyed by name")

    result = []
    for name in sorted(records):
        if not isinstance(name, str) or not name:
            raise ValueError(f"{record_type} keys must be non-empty strings")
        fields = records[name]
        if fields is None:
            fields = {}
        if not isinstance(fields, dict):
            raise ValueError(f"{record_type}.{name} must be an object")
        if fields.get("name", name) != name:
            raise ValueError(
                f"{record_type}.{name}.name conflicts with its Terraform map key"
            )
        fields = {
            key: value
            for key, value in fields.items()
            if key != "name"
        }
        validate_record(fields, record_type, f"{record_type}.{name}")
        result.append({**fields, "name": name})
    return result
