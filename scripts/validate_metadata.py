"""Validate that every recipe metadata.yml conforms to the required schema."""
import sys
import yaml
import semver
from pathlib import Path
from . import utils

REQUIRED_FIELDS = ["name", "version", "description", "tags", "type"]


def load_valid_namespaces():
    config = utils.load_config()
    return set(config.get("namespace", {}).keys())


def validate_one(meta_path, valid_namespaces):
    errors = []
    rel = meta_path.relative_to(utils.REPO)
    try:
        with open(meta_path, "r") as f:
            data = yaml.safe_load(f)
    except Exception as e:
        return [f"{rel}: failed to parse YAML: {e}"]
    if not isinstance(data, dict):
        return [f"{rel}: not a YAML mapping"]
    for field in REQUIRED_FIELDS:
        if field not in data or data[field] is None:
            errors.append(f"{rel}: missing required field '{field}'")
    if "version" in data and data["version"] is not None:
        try:
            semver.Version.parse(str(data["version"]))
        except (ValueError, TypeError):
            errors.append(f"{rel}: version '{data['version']}' not valid semver")
    ns_dir = meta_path.parent.parent.name
    if ns_dir not in valid_namespaces:
        errors.append(f"{rel}: namespace '{ns_dir}' not in config")
    if "description" in data and data["description"] is not None:
        if not str(data["description"]).strip():
            errors.append(f"{rel}: description must not be empty")
    if "tags" in data and data["tags"] is not None:
        if not isinstance(data["tags"], list) or len(data["tags"]) == 0:
            errors.append(f"{rel}: tags must be a non-empty list")
    return errors


def main():
    valid_namespaces = load_valid_namespaces()
    meta_files = sorted(utils.RECIPES.rglob("metadata.yml"))
    if not meta_files:
        print("WARNING: No metadata.yml files found.")
        sys.exit(0)
    all_errors = []
    for mf in meta_files:
        all_errors.extend(validate_one(mf, valid_namespaces))
    if all_errors:
        print(f"Metadata validation FAILED ({len(all_errors)} errors):")
        for e in all_errors:
            print(f"  ERROR: {e}")
        sys.exit(1)
    else:
        print(f"Metadata validation passed: {len(meta_files)} files OK.")


main()
