"""Validate that every recipe directory has required files and subdirs."""
import sys
from pathlib import Path
from . import utils

REQUIRED_FILES = ["README.md", "metadata.yml", "Makefile"]
REQUIRED_DIRS = ["assets", "docs", "tests"]


def find_recipe_dirs():
    recipes = []
    for meta in utils.RECIPES.rglob("metadata.yml"):
        recipes.append(meta.parent)
    return sorted(recipes)


def validate_recipe(recipe_dir):
    errors = []
    rel = recipe_dir.relative_to(utils.REPO)
    for f in REQUIRED_FILES:
        if not (recipe_dir / f).is_file():
            errors.append(f"{rel}: missing required file '{f}'")
    for d in REQUIRED_DIRS:
        if not (recipe_dir / d).is_dir():
            errors.append(f"{rel}: missing required directory '{d}/'")
    return errors


def main():
    recipe_dirs = find_recipe_dirs()
    if not recipe_dirs:
        print("WARNING: No recipe directories found.")
        sys.exit(0)
    all_errors = []
    for rd in recipe_dirs:
        all_errors.extend(validate_recipe(rd))
    if all_errors:
        print(f"Structure validation FAILED ({len(all_errors)} errors):")
        for e in all_errors:
            print(f"  ERROR: {e}")
        sys.exit(1)
    else:
        print(f"Structure validation passed: {len(recipe_dirs)} recipes OK.")


main()
