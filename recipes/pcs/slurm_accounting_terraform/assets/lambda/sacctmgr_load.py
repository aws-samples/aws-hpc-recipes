import logging
import math
import re


LOGGER = logging.getLogger(__name__)

QOS_FLAG_NAMES = {
    "denyonlimit": "DENY_LIMIT",
    "enforceusagethreshold": "ENFORCE_USAGE_THRESHOLD",
    "nodecay": "NO_DECAY",
    "noreserve": "NO_RESERVE",
    "overpartqos": "OVERRIDE_PARTITION_QOS",
    "partitionmaxnodes": "PARTITION_MAXIMUM_NODE",
    "partitionminnodes": "PARTITION_MINIMUM_NODE",
    "partitiontimelimit": "PARTITION_TIME_LIMIT",
    "partqos": "PARTITION_QOS",
    "relative": "RELATIVE",
    "requiresreservation": "REQUIRED_RESERVATION",
    "usagefactorsafe": "USAGE_FACTOR_SAFE",
}

QOS_FIELDS = {
    "description": ("description", "string"),
    "flags": ("flags", "qos_flags"),
    "gracetime": ("limits.grace_time", "uint"),
    "grpjobsaccrue": ("limits.max.active_jobs.accruing", "limit"),
    "grpjobs": ("limits.max.active_jobs.count", "limit"),
    "grpsubmitjobs": ("limits.max.jobs.count", "limit"),
    "grptres": ("limits.max.tres.total", "tres"),
    "grptresmins": ("limits.max.tres.minutes.total", "tres"),
    "grptresrunmins": ("limits.max.tres.minutes.per.qos", "tres"),
    "grpwall": ("limits.max.wall_clock.per.qos", "minutes"),
    "limitfactor": ("limits.factor", "float_limit"),
    "maxjobspa": ("limits.max.jobs.active_jobs.per.account", "limit"),
    "maxjobsperaccount": (
        "limits.max.jobs.active_jobs.per.account",
        "limit",
    ),
    "maxjobspu": ("limits.max.jobs.active_jobs.per.user", "limit"),
    "maxjobsperuser": ("limits.max.jobs.active_jobs.per.user", "limit"),
    "maxjobsaccruepa": ("limits.max.accruing.per.account", "limit"),
    "maxjobsaccrueperaccount": (
        "limits.max.accruing.per.account",
        "limit",
    ),
    "maxjobsaccruepu": ("limits.max.accruing.per.user", "limit"),
    "maxjobsaccrueperuser": (
        "limits.max.accruing.per.user",
        "limit",
    ),
    "maxsubmitjobspa": ("limits.max.jobs.per.account", "limit"),
    "maxsubmitjobsperaccount": ("limits.max.jobs.per.account", "limit"),
    "maxsubmitjobspu": ("limits.max.jobs.per.user", "limit"),
    "maxsubmitjobsperuser": ("limits.max.jobs.per.user", "limit"),
    "maxtresminsperjob": ("limits.max.tres.minutes.per.job", "tres"),
    "maxtresperaccount": ("limits.max.tres.per.account", "tres"),
    "maxtres": ("limits.max.tres.per.job", "tres"),
    "maxtresperjob": ("limits.max.tres.per.job", "tres"),
    "maxtrespernode": ("limits.max.tres.per.node", "tres"),
    "maxtresperuser": ("limits.max.tres.per.user", "tres"),
    "maxtresrunminsperaccount": (
        "limits.max.tres.minutes.per.account",
        "tres",
    ),
    "maxtresrunminsperuser": (
        "limits.max.tres.minutes.per.user",
        "tres",
    ),
    "maxwalldurationperjob": ("limits.max.wall_clock.per.job", "minutes"),
    "minpriothresh": ("limits.min.priority_threshold", "limit"),
    "mintresperjob": ("limits.min.tres.per.job", "tres"),
    "preempt": ("preempt.list", "csv"),
    "preemptmode": ("preempt.mode", "preempt_modes"),
    "preemptexempttime": ("preempt.exempt_time", "seconds"),
    "priority": ("priority", "limit"),
    "usagefactor": ("usage_factor", "float_limit"),
    "usagethreshold": ("usage_threshold", "float_limit"),
}

ASSOCIATION_FIELDS = {
    "defaultqos": ("default.qos", "string"),
    "fairshare": ("shares_raw", "shares"),
    "shares": ("shares_raw", "shares"),
    "grpjobs": ("max.jobs.per.count", "limit"),
    "grpjobsaccrue": ("max.jobs.per.accruing", "limit"),
    "grpsubmitjobs": ("max.jobs.per.submitted", "limit"),
    "grptres": ("max.tres.total", "tres"),
    "grptresmins": ("max.tres.group.minutes", "tres"),
    "grptresrunmins": ("max.tres.group.active", "tres"),
    "grpwall": ("max.per.account.wall_clock", "minutes"),
    "maxjobs": ("max.jobs.active", "limit"),
    "maxjobsaccrue": ("max.jobs.accruing", "limit"),
    "maxsubmitjobs": ("max.jobs.total", "limit"),
    "maxtresminsperjob": ("max.tres.minutes.per.job", "tres"),
    "maxtresrunmins": ("max.tres.minutes.total", "tres"),
    "maxtres": ("max.tres.per.job", "tres"),
    "maxtresperjob": ("max.tres.per.job", "tres"),
    "maxtrespernode": ("max.tres.per.node", "tres"),
    "maxwalldurationperjob": ("max.jobs.per.wall_clock", "minutes"),
    "minpriothresh": ("min.priority_threshold", "limit"),
    "priority": ("priority", "limit"),
    "qos": ("qos", "csv"),
    "qoslevel": ("qos", "csv"),
}

TRES_ALIASES = {
    "grpcpumins": ("max.tres.group.minutes", "cpu"),
    "grpcpurunmins": ("max.tres.group.active", "cpu"),
    "grpcpus": ("max.tres.total", "cpu"),
    "grpmemory": ("max.tres.total", "mem"),
    "grpnodes": ("max.tres.total", "node"),
    "maxcpuminsperjob": ("max.tres.minutes.per.job", "cpu"),
    "maxcpurunmins": ("max.tres.minutes.total", "cpu"),
    "maxcpusperjob": ("max.tres.per.job", "cpu"),
    "maxnodesperjob": ("max.tres.per.job", "node"),
}

QOS_TRES_ALIASES = {
    "grpcpumins": ("limits.max.tres.minutes.total", "cpu"),
    "grpcpurunmins": ("limits.max.tres.minutes.per.qos", "cpu"),
    "grpcpus": ("limits.max.tres.total", "cpu"),
    "grpmemory": ("limits.max.tres.total", "mem"),
    "grpnodes": ("limits.max.tres.total", "node"),
    "maxcpuminsperjob": ("limits.max.tres.minutes.per.job", "cpu"),
    "maxcpusperjob": ("limits.max.tres.per.job", "cpu"),
    "maxcpusperuser": ("limits.max.tres.per.user", "cpu"),
    "maxnodesperjob": ("limits.max.tres.per.job", "node"),
    "maxnodesperuser": ("limits.max.tres.per.user", "node"),
    "mincpusperjob": ("limits.min.tres.per.job", "cpu"),
}


def _canonical_name(value):
    return re.sub(r"[^a-z0-9]", "", value.lower())


def _split_unquoted(value, delimiter):
    parts = []
    start = 0
    quote = None
    escaped = False
    for index, character in enumerate(value):
        if escaped:
            escaped = False
        elif character == "\\":
            escaped = True
        elif quote:
            if character == quote:
                quote = None
        elif character in ("'", '"'):
            quote = character
        elif character == delimiter:
            parts.append(value[start:index])
            start = index + 1
    if quote:
        raise ValueError("unterminated quoted value")
    parts.append(value[start:])
    return parts


def _is_typed_tres_colon(value, segment_start, colon_index):
    """Return whether a colon separates a TRES type from its name."""
    for character in reversed(value[segment_start:colon_index]):
        if character in "=,:\"'":
            return False
        if character == "/":
            return True
    return False


def _split_record_segments(value):
    """Split dump fields while preserving names like gres/gpu:a100."""
    segments = []
    start = 0
    quote = None
    escaped = False

    for index, character in enumerate(value):
        if escaped:
            escaped = False
        elif character == "\\":
            escaped = True
        elif quote:
            if character == quote:
                quote = None
        elif character in ("'", '"'):
            quote = character
        elif character == ":":
            if _is_typed_tres_colon(value, start, index):
                continue
            segments.append(value[start:index])
            start = index + 1

    if quote:
        raise ValueError("unterminated quoted value")
    segments.append(value[start:])
    return segments


def _unquote(value):
    value = value.strip()
    if (
        len(value) >= 2
        and value[0] in ("'", '"')
        and value[-1] == value[0]
    ):
        quote = value[0]
        value = value[1:-1]
        value = value.replace(f"\\{quote}", quote).replace("\\\\", "\\")
    return value


def _parse_record(line, line_number):
    match = re.fullmatch(
        r"\s*(QOS|Cluster|Machine|Parent|Account|Project|User)\s*-\s*(.+)",
        line,
        re.IGNORECASE,
    )
    if not match:
        raise ValueError(f"sacctmgr_load line {line_number}: invalid record")

    record_type = match.group(1).lower()
    try:
        segments = _split_record_segments(match.group(2))
    except ValueError as error:
        raise ValueError(
            f"sacctmgr_load line {line_number}: {error}"
        ) from error

    name = _unquote(segments[0])
    if not name:
        raise ValueError(
            f"sacctmgr_load line {line_number}: record name is empty"
        )

    options = []
    for segment in segments[1:]:
        option = re.fullmatch(r"\s*([^=+\-\s]+)\s*(\+=|-=|=)\s*(.*)", segment)
        if not option:
            raise ValueError(
                f"sacctmgr_load line {line_number}: invalid option {segment!r}"
            )
        if option.group(2) != "=":
            raise ValueError(
                f"sacctmgr_load line {line_number}: "
                f"{option.group(2)} is not supported; dump files use '='"
            )
        options.append(
            (
                _canonical_name(option.group(1)),
                _unquote(option.group(3)),
            )
        )
    return record_type, name, options


def _parse_uint(value):
    number = int(value, 10)
    if number < 0:
        raise ValueError("expected a non-negative integer")
    return number


def _parse_limit(value):
    if value.lower() in {"-1", "infinite", "unlimited"}:
        return {"infinite": True}
    if value.lower() in {"none", "unset"}:
        return None
    return _parse_uint(value)


def _parse_float_limit(value):
    if value.lower() in {"-1", "infinite", "unlimited"}:
        return {"infinite": True}
    if value.lower() in {"none", "unset"}:
        return None
    return float(value)


def _parse_duration_seconds(value):
    if re.fullmatch(r"[0-9]+", value):
        return int(value)

    match = re.fullmatch(
        r"(?:(?P<days>[0-9]+)-)?"
        r"(?P<hours>[0-9]+):(?P<minutes>[0-9]{1,2})"
        r"(?::(?P<seconds>[0-9]{1,2}))?",
        value,
    )
    if not match:
        raise ValueError("expected an integer or Slurm duration")

    if match.group("seconds") is None and match.group("days") is None:
        hours = 0
        minutes = int(match.group("hours"))
        seconds = int(match.group("minutes"))
    else:
        hours = int(match.group("hours"))
        minutes = int(match.group("minutes"))
        seconds = int(match.group("seconds") or 0)
    return (
        int(match.group("days") or 0) * 86400
        + hours * 3600
        + minutes * 60
        + seconds
    )


def _parse_minutes(value):
    if value.lower() in {"-1", "infinite", "unlimited"}:
        return {"infinite": True}
    return math.ceil(_parse_duration_seconds(value) / 60)


def _parse_seconds(value):
    if value.lower() in {"-1", "infinite", "unlimited"}:
        return {"infinite": True}
    return _parse_duration_seconds(value)


def _parse_count(value, base_unit=""):
    match = re.fullmatch(
        r"(?P<number>[+-]?[0-9]+(?:\.[0-9]+)?)"
        r"(?P<unit>[KMGTPE]?)"
        r"(?:i?[Bb])?",
        value,
        re.IGNORECASE,
    )
    if not match:
        raise ValueError(f"invalid TRES count {value!r}")
    unit = match.group("unit").upper()
    unit_order = "KMGTPE"
    unit_level = 0 if not unit else unit_order.index(unit) + 1
    base_level = 0 if not base_unit else unit_order.index(base_unit) + 1
    if unit_level < base_level:
        raise ValueError(
            f"TRES count {value!r} uses a unit below its base unit"
        )
    multiplier = 1024 ** (unit_level - base_level)
    count = float(match.group("number")) * multiplier
    if not count.is_integer():
        raise ValueError(f"TRES count {value!r} is not an integer")
    return int(count)


def _parse_tres(value):
    records = []
    for entry in _split_unquoted(value, ","):
        name, separator, count = entry.partition("=")
        if not separator:
            raise ValueError(f"invalid TRES entry {entry!r}")
        tres_type, slash, tres_name = name.strip().partition("/")
        base_unit = (
            "M"
            if tres_type.lower() in {"bb", "mem"}
            or tres_name.lower() == "gpumem"
            else ""
        )
        record = {
            "type": tres_type,
            "count": _parse_count(count.strip(), base_unit),
        }
        if slash:
            record["name"] = tres_name
        records.append(record)
    return records


def _parse_csv(value):
    if not value:
        return []
    return [
        item.strip()
        for item in _split_unquoted(value, ",")
        if item.strip()
    ]


def _parse_qos_flags(value):
    flags = []
    for flag in _parse_csv(value):
        canonical = _canonical_name(flag)
        if canonical not in QOS_FLAG_NAMES:
            raise ValueError(f"unsupported QOS flag {flag!r}")
        flags.append(QOS_FLAG_NAMES[canonical])
    return flags


def _parse_preempt_modes(value):
    modes = [mode.upper() for mode in _parse_csv(value)]
    return ["DISABLED" if mode == "OFF" else mode for mode in modes]


def _parse_shares(value):
    if value.lower() == "parent":
        return 0x7FFFFFFF
    return _parse_uint(value)


VALUE_PARSERS = {
    "csv": _parse_csv,
    "float_limit": _parse_float_limit,
    "limit": _parse_limit,
    "minutes": _parse_minutes,
    "preempt_modes": _parse_preempt_modes,
    "qos_flags": _parse_qos_flags,
    "seconds": _parse_seconds,
    "shares": _parse_shares,
    "string": lambda value: value,
    "tres": _parse_tres,
    "uint": _parse_uint,
}


def _set_path(record, path, value):
    target = record
    keys = path.split(".")
    for key in keys[:-1]:
        existing = target.setdefault(key, {})
        if not isinstance(existing, dict):
            raise ValueError(f"conflicting values for {path}")
        target = existing
    if keys[-1] in target and target[keys[-1]] != value:
        raise ValueError(f"conflicting values for {path}")
    target[keys[-1]] = value


def _merge_tres(record, path, records):
    target = record
    keys = path.split(".")
    for key in keys[:-1]:
        target = target.setdefault(key, {})
    existing = target.setdefault(keys[-1], [])
    by_name = {
        (item["type"], item.get("name")): item
        for item in existing
    }
    for item in records:
        by_name[(item["type"], item.get("name"))] = item
    target[keys[-1]] = list(by_name.values())


def _apply_fields(record, options, field_map, tres_aliases, line_number):
    for field, raw_value in options:
        try:
            if field in tres_aliases:
                path, tres_type = tres_aliases[field]
                _merge_tres(
                    record,
                    path,
                    [{"type": tres_type, "count": _parse_uint(raw_value)}],
                )
                continue
            if field not in field_map:
                raise ValueError(f"unsupported option {field!r}")
            path, value_type = field_map[field]
            value = VALUE_PARSERS[value_type](raw_value)
            if value_type == "tres":
                _merge_tres(record, path, value)
            else:
                _set_path(record, path, value)
        except (TypeError, ValueError) as error:
            raise ValueError(
                f"sacctmgr_load line {line_number}: {field}: {error}"
            ) from error


def _merge_user(users, name, fields, line_number):
    user = users.setdefault(name, {})
    for key, value in fields.items():
        if key in {"coordinators", "wckeys"}:
            user[key] = sorted(set(user.get(key, [])) | set(value))
        elif key == "default":
            default = user.setdefault("default", {})
            for default_key, default_value in value.items():
                if (
                    default_key in default
                    and default[default_key] != default_value
                ):
                    raise ValueError(
                        f"sacctmgr_load line {line_number}: conflicting "
                        f"default.{default_key} for user {name!r}"
                    )
                default[default_key] = default_value
        elif key in user and user[key] != value:
            raise ValueError(
                f"sacctmgr_load line {line_number}: conflicting {key} "
                f"for user {name!r}"
            )
        else:
            user[key] = value


def parse_sacctmgr_load(contents):
    if not isinstance(contents, str):
        raise ValueError("sacctmgr_load must be a string")

    result = {
        "accounts": {},
        "associations": [],
        "qos": {},
        "users": {},
    }
    current_parent = "root"
    saw_cluster = False

    for line_number, raw_line in enumerate(contents.splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        record_type, name, options = _parse_record(line, line_number)
        if record_type == "qos":
            if saw_cluster:
                raise ValueError(
                    f"sacctmgr_load line {line_number}: "
                    "QOS records must precede the Cluster record"
                )
            if name in result["qos"]:
                raise ValueError(
                    f"sacctmgr_load line {line_number}: "
                    f"duplicate QOS {name!r}"
                )
            qos = {}
            _apply_fields(
                qos,
                options,
                QOS_FIELDS,
                QOS_TRES_ALIASES,
                line_number,
            )
            result["qos"][name] = qos
            continue

        if record_type in {"cluster", "machine"}:
            if saw_cluster:
                raise ValueError(
                    f"sacctmgr_load line {line_number}: "
                    "only one Cluster record is supported"
                )
            saw_cluster = True
            root_association = {"account": "root"}
            association_options = []
            for field, value in options:
                if field == "classification":
                    LOGGER.warning(
                        "Ignoring sacctmgr dump cluster classification",
                        extra={"classification": value},
                    )
                else:
                    association_options.append((field, value))
            _apply_fields(
                root_association,
                association_options,
                ASSOCIATION_FIELDS,
                TRES_ALIASES,
                line_number,
            )
            if len(root_association) > 1:
                result["associations"].append(root_association)
            continue

        if not saw_cluster:
            raise ValueError(
                f"sacctmgr_load line {line_number}: "
                f"{record_type.title()} record precedes the Cluster record"
            )

        if record_type == "parent":
            if options:
                raise ValueError(
                    f"sacctmgr_load line {line_number}: "
                    "Parent records cannot have options"
                )
            current_parent = name
            continue

        association = {
            "account": current_parent if record_type == "user" else name,
        }
        association_options = []

        if record_type in {"account", "project"}:
            if name in result["accounts"]:
                raise ValueError(
                    f"sacctmgr_load line {line_number}: "
                    f"duplicate account {name!r}"
                )
            account = {}
            for field, value in options:
                if field in {"description", "organization"}:
                    account[field] = value
                else:
                    association_options.append((field, value))
            result["accounts"][name] = account
            association["parent_account"] = current_parent
        else:
            association["user"] = name
            user = {}
            for field, value in options:
                if field == "adminlevel":
                    user["administrator_level"] = [value]
                elif field == "defaultaccount":
                    _set_path(user, "default.account", value)
                elif field == "defaultwckey":
                    _set_path(user, "default.wckey", value)
                elif field == "coordinator":
                    user["coordinators"] = _parse_csv(value)
                elif field == "wckeys":
                    user["wckeys"] = _parse_csv(value)
                elif field == "partition":
                    association["partition"] = value
                else:
                    association_options.append((field, value))
            _merge_user(result["users"], name, user, line_number)

        _apply_fields(
            association,
            association_options,
            ASSOCIATION_FIELDS,
            TRES_ALIASES,
            line_number,
        )
        result["associations"].append(association)

    if not saw_cluster and any(result[key] for key in result):
        raise ValueError("sacctmgr_load does not contain a Cluster record")
    return result
