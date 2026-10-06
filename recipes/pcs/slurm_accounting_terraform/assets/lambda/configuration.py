from field_validation import (
    named_records as _named_records,
    nested_value as _nested_value,
    validate_record as _validate_record,
    validate_string_list as _validate_string_list,
)
from sacctmgr_load import parse_sacctmgr_load


RESOURCE_TYPES = ("accounts", "qos", "users", "associations")
INPUT_KEYS = frozenset((*RESOURCE_TYPES, "sacctmgr_load"))


def _pop_string_list(record, field, path):
    value = record.pop(field, [])
    if value is None:
        return []
    _validate_string_list(value, path)
    return value


def _normalize_accounts(configuration):
    accounts = _named_records(configuration, "accounts")
    coordinators = {}
    for account in accounts:
        names = _pop_string_list(
            account,
            "coordinators",
            f"accounts.{account['name']}.coordinators",
        )
        if names:
            coordinators[account["name"]] = set(names)
    return accounts, coordinators


def _normalize_users(configuration, cluster_name):
    users = _named_records(configuration, "users")
    default_accounts = {}
    wckeys = {}
    coordinator_accounts = {}

    for user in users:
        user_name = user["name"]
        defaults = user.get("default", {})
        if "account" in defaults:
            default_accounts[user_name] = defaults.pop("account")
        if not defaults:
            user.pop("default", None)

        names = _pop_string_list(
            user,
            "wckeys",
            f"users.{user_name}.wckeys",
        )
        default_wckey = _nested_value(user, "default.wckey")
        if default_wckey is not None:
            names.append(default_wckey)
        for name in names:
            wckeys[(user_name, name)] = {
                "cluster": cluster_name,
                "name": name,
                "user": user_name,
            }

        coordinator_accounts[user_name] = _pop_string_list(
            user,
            "coordinators",
            f"users.{user_name}.coordinators",
        )

    return users, default_accounts, list(wckeys.values()), coordinator_accounts


def _normalize_account_association(
    association,
    index,
    configured_accounts,
):
    if association.get("partition"):
        raise ValueError(f"associations[{index}].partition requires a user")
    if "is_default" in association:
        raise ValueError(
            f"associations[{index}].is_default requires a "
            "non-partition user association"
        )

    if association["account"] == "root":
        parent_account = association.get("parent_account")
        if parent_account not in (None, "", "root"):
            raise ValueError(
                f"associations[{index}].parent_account must be root"
            )
        return {
            key: value
            for key, value in association.items()
            if key != "parent_account"
        } | {"user": None}

    parent_account = association.get("parent_account") or "root"
    if not isinstance(parent_account, str):
        raise ValueError(
            f"associations[{index}].parent_account must be a string"
        )
    if (
        parent_account != "root"
        and parent_account not in configured_accounts
    ):
        raise ValueError(
            f"associations[{index}].parent_account "
            f"{parent_account!r} is not defined in accounts"
        )

    # Slurm represents a cluster-level account association with a null user.
    return {
        **association,
        "parent_account": parent_account,
        "user": None,
    }


def _normalize_user_association(
    association,
    index,
    configured_users,
):
    if "parent_account" in association:
        raise ValueError(
            f"associations[{index}].parent_account is only valid "
            "for account associations"
        )
    user_name = association.get("user")
    if not isinstance(user_name, str):
        raise ValueError(f"associations[{index}].user must be a string")
    if user_name not in configured_users:
        raise ValueError(
            f"associations[{index}].user {user_name!r} is not defined in users"
        )
    if association.get("partition") and "is_default" in association:
        raise ValueError(
            f"associations[{index}].is_default requires a "
            "non-partition user association"
        )

    return (
        {**association, "user": user_name},
        (
            association["account"],
            user_name,
            association.get("partition"),
        ),
    )


def _association_records(
    configuration,
    cluster_name,
    account_names,
    user_names,
):
    associations = configuration.get("associations", [])
    if not isinstance(associations, list):
        raise ValueError("associations must be a list of objects")

    configured_accounts = {*account_names, "root"}
    configured_users = set(user_names)
    account_associations = []
    user_associations = []
    explicitly_associated_accounts = set()
    configured_user_associations = set()

    for index, association in enumerate(associations):
        if not isinstance(association, dict):
            raise ValueError(f"associations[{index}] must be an object")
        _validate_record(
            association,
            "associations",
            f"associations[{index}]",
        )
        if association.get("cluster", cluster_name) != cluster_name:
            raise ValueError(
                f"associations[{index}].cluster must be {cluster_name!r}"
            )

        normalized = {**association, "cluster": cluster_name}
        account_name = normalized.get("account")
        if not isinstance(account_name, str) or not account_name:
            raise ValueError(
                f"associations[{index}].account must be a non-empty string"
            )
        if account_name not in configured_accounts:
            raise ValueError(
                f"associations[{index}].account {account_name!r} is not "
                "defined in accounts"
            )

        if association.get("user") in (None, ""):
            if account_name in explicitly_associated_accounts:
                raise ValueError(
                    "Multiple cluster-level associations configured for "
                    f"account {account_name!r}"
                )
            explicitly_associated_accounts.add(account_name)
            account_associations.append(
                _normalize_account_association(
                    normalized,
                    index,
                    configured_accounts,
                )
            )
            continue

        normalized, association_key = _normalize_user_association(
            normalized,
            index,
            configured_users,
        )
        if association_key in configured_user_associations:
            raise ValueError(
                "Multiple user associations configured for "
                f"account {account_name!r}, user {normalized['user']!r}, "
                f"partition {normalized.get('partition')!r}"
            )
        configured_user_associations.add(association_key)
        user_associations.append(normalized)

    generated_account_associations = [
        {
            "account": account_name,
            "cluster": cluster_name,
            "parent_account": "root",
            "user": None,
        }
        for account_name in sorted(account_names)
        if account_name not in explicitly_associated_accounts
    ]
    return [
        *generated_account_associations,
        *account_associations,
        *user_associations,
    ]


def _apply_account_defaults(accounts, associations):
    parents = {
        association["account"]: association.get("parent_account", "root")
        for association in associations
        if association["user"] is None
        and association["account"] != "root"
    }
    for account in accounts:
        name = account["name"]
        account.setdefault("description", name)
        parent = parents.get(name, "root")
        account.setdefault(
            "organization",
            name if parent == "root" else parent,
        )


def _apply_user_default_accounts(default_accounts, associations):
    for user_name, account_name in default_accounts.items():
        if not isinstance(account_name, str) or not account_name:
            raise ValueError(
                f"users.{user_name}.default.account must be a "
                "non-empty string"
            )
        matches = [
            association
            for association in associations
            if association["user"] == user_name
            and association["account"] == account_name
            and not association.get("partition")
        ]
        if len(matches) != 1:
            raise ValueError(
                f"users.{user_name}.default.account {account_name!r} "
                "must match one non-partition user association"
            )
        matches[0]["is_default"] = True

    defaults_by_user = {}
    for association in associations:
        if association["user"] is None or not association.get("is_default"):
            continue
        user_name = association["user"]
        if user_name in defaults_by_user:
            raise ValueError(
                f"Multiple default account associations configured "
                f"for user {user_name!r}"
            )
        defaults_by_user[user_name] = association["account"]


def _validate_qos_references(qos, associations):
    qos_names = {record["name"] for record in qos}

    for index, association in enumerate(associations):
        referenced_qos = list(association.get("qos", []))
        default_qos = _nested_value(association, "default.qos")
        if default_qos:
            referenced_qos.append(default_qos)
        missing = sorted(set(referenced_qos) - qos_names)
        if missing:
            raise ValueError(
                f"associations[{index}] references QOS not defined in qos: "
                + ", ".join(missing)
            )

    preemptions = {}
    for record in qos:
        name = record["name"]
        preemptions[name] = set(
            _nested_value(record, "preempt.list") or []
        )
        missing = sorted(preemptions[name] - qos_names)
        if missing:
            raise ValueError(
                f"qos.{name}.preempt.list references QOS not defined in qos: "
                + ", ".join(missing)
            )

    visiting = set()
    visited = set()

    def visit(name):
        if name in visiting:
            raise ValueError(
                f"QOS preemption cycle detected involving {name!r}"
            )
        if name in visited:
            return
        visiting.add(name)
        for preempted_name in preemptions[name]:
            visit(preempted_name)
        visiting.remove(name)
        visited.add(name)

    for name in sorted(preemptions):
        visit(name)


def _coordinator_records(
    accounts,
    users,
    account_coordinators,
    user_coordinator_accounts,
):
    account_names = {account["name"] for account in accounts}
    user_names = {user["name"] for user in users}
    coordinators = {
        account_name: set(names)
        for account_name, names in account_coordinators.items()
    }

    for user_name, coordinated_accounts in user_coordinator_accounts.items():
        for account_name in coordinated_accounts:
            if account_name not in account_names:
                raise ValueError(
                    f"users.{user_name}.coordinators references account "
                    f"{account_name!r}, which is not defined in accounts"
                )
            coordinators.setdefault(account_name, set()).add(user_name)

    for account_name, coordinator_names in coordinators.items():
        missing_users = sorted(coordinator_names - user_names)
        if missing_users:
            raise ValueError(
                f"accounts.{account_name}.coordinators references users "
                f"not defined in users: {', '.join(missing_users)}"
            )

    accounts_by_name = {
        account["name"]: account
        for account in accounts
    }
    return [
        {
            "account": accounts_by_name[account_name],
            "users": sorted(coordinator_names),
        }
        for account_name, coordinator_names in sorted(coordinators.items())
        if coordinator_names
    ]


def normalize_configuration(event, cluster_name):
    if event is None:
        event = {}
    if not isinstance(event, dict):
        raise ValueError("Lambda payload must be a JSON object")

    unknown_keys = sorted(set(event) - INPUT_KEYS)
    if unknown_keys:
        raise ValueError(
            f"Unsupported bootstrap configuration keys: {', '.join(unknown_keys)}"
        )

    load_contents = event.get("sacctmgr_load")
    if load_contents is not None:
        structured_keys = [
            key
            for key in RESOURCE_TYPES
            if event.get(key)
        ]
        if structured_keys:
            raise ValueError(
                "sacctmgr_load cannot be combined with structured inputs: "
                + ", ".join(structured_keys)
            )
        event = parse_sacctmgr_load(load_contents)

    accounts, account_coordinators = _normalize_accounts(event)
    (
        users,
        default_accounts,
        wckeys,
        user_coordinator_accounts,
    ) = _normalize_users(event, cluster_name)
    associations = _association_records(
        event,
        cluster_name,
        [account["name"] for account in accounts],
        [user["name"] for user in users],
    )
    _apply_account_defaults(accounts, associations)
    _apply_user_default_accounts(default_accounts, associations)
    qos = _named_records(event, "qos")
    _validate_qos_references(qos, associations)

    return {
        "accounts": accounts,
        "qos": qos,
        "users": users,
        "wckeys": wckeys,
        "associations": associations,
        "coordinators": _coordinator_records(
            accounts,
            users,
            account_coordinators,
            user_coordinator_accounts,
        ),
    }


def order_account_associations(account_associations):
    desired_by_account = {}
    for association in account_associations:
        account_name = association["account"]
        if account_name in desired_by_account:
            raise ValueError(
                "Multiple cluster-level associations configured for "
                f"account {account_name!r}"
            )

        if account_name == "root":
            parent_account = None
        else:
            parent_account = association.get("parent_account") or "root"
        if not isinstance(parent_account, str):
            if account_name != "root":
                raise ValueError(
                    f"Account association {account_name!r} has a "
                    "non-string parent"
                )
        if parent_account == account_name:
            raise ValueError(
                f"Account association {account_name!r} cannot be its own parent"
            )

        desired_by_account[account_name] = {**association}
        if parent_account is None:
            desired_by_account[account_name].pop("parent_account", None)
        else:
            desired_by_account[account_name]["parent_account"] = parent_account

    missing_parents = sorted(
        (account_name, association.get("parent_account"))
        for account_name, association in desired_by_account.items()
        if association.get("parent_account") not in desired_by_account
        and association.get("parent_account") not in (None, "root")
    )
    if missing_parents:
        relationships = ", ".join(
            f"{account} -> {parent}"
            for account, parent in missing_parents
        )
        raise ValueError(
            "Account association parents are not configured: "
            + relationships
        )

    # Parents must exist in Slurm before their child associations are written.
    child_accounts = {
        account_name: []
        for account_name in desired_by_account
    }
    dependency_count = {
        account_name: 0
        for account_name in desired_by_account
    }
    for account_name, association in desired_by_account.items():
        parent_account = association.get("parent_account")
        if parent_account in desired_by_account:
            child_accounts[parent_account].append(account_name)
            dependency_count[account_name] += 1

    ready = sorted(
        account_name
        for account_name, count in dependency_count.items()
        if count == 0
    )
    ordered = []
    while ready:
        account_name = ready.pop(0)
        ordered.append(desired_by_account[account_name])
        for child_account in sorted(child_accounts[account_name]):
            dependency_count[child_account] -= 1
            if dependency_count[child_account] == 0:
                ready.append(child_account)
                ready.sort()

    if len(ordered) != len(desired_by_account):
        cycle_accounts = sorted(
            account_name
            for account_name, count in dependency_count.items()
            if count > 0
        )
        raise ValueError(
            "Account association parent cycle detected: "
            + ", ".join(cycle_accounts)
        )

    return ordered
