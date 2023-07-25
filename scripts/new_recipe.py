import getpass
import os
import re
import semver
import subprocess
import sys
import yaml

from jinja2 import Environment, FileSystemLoader, select_autoescape
from pathlib import Path

from . import utils

# SCRIPTS = Path(__file__).resolve().parent
# REPO = SCRIPTS.parent
# CONFIG = Path.joinpath(REPO, "config", "metadata", "values.yml")
# RECIPES = Path.joinpath(REPO, "recipes")
# TEMPLATES = Path.joinpath(REPO, "templates", "recipe")

def slugify(s):
    # Simple slugify strings to path safe values
    s = s.lower().strip()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s_-]+", "_", s)
    s = re.sub(r"^-+|-+$", "", s)
    return s


def redact(value):
    return value[0] + ("*" * (len(value) - 2)) + value[-1]


def prompt(body, default=None, secret=False, allow_empty=True):
    """Prompt user for text input
    """
    if default is not None:
        if secret is False:
            fdefault = default
        else:
            # Mask out all but first and last two chars of secret value
            fdefault = redact(default)
        qtext = "{0} [{1}]: ".format(body, fdefault)
    else:
        qtext = "{0}: ".format(body)

    try:
        if not secret:
            response = input(qtext)
        else:
            response = getpass.getpass(qtext)
    except KeyboardInterrupt:
        print()
        sys.exit(1)
    except Exception:
        raise

    if (response is None or response == "") and default is not None:
        response = default
    else:
        response = response.strip()

    if (response is None or response == "") and allow_empty is False:
        raise ValueError("This value cannot be empty.")
    else:
        return response


def process_namespace(namespace):
    return slugify(namespace)


def process_recipe_name(recipe_name):
    return slugify(recipe_name)


def process_version(version):
    # Validate version conforms to semver
    try:
        parsed = semver.Version.parse(version)
        return version
    except Exception:
        raise


def process_authors(authors_string):
    # Turn CSV into list of strings
    if len(authors_string) > 0:
        authors = [a.strip() for a in authors_string.split(",")]
    else:
        authors = []
    return authors


def process_tags(tags_string):
    # Turn CSV into list of safened strings
    if len(tags_string) > 0:
        tags = [slugify(t.strip()) for t in tags_string.split(",")]
    else:
        tags = []
    # Automatically tag new recipes as experimental
    if ["experimental"] not in tags:
        tags.append("experimental")
    return tags


def default_author():
    # Generate a default author from git config
    default_author = ""
    user_name = (
        subprocess.run(
            "git config --global user.name", shell=True, stdout=subprocess.PIPE
        )
        .stdout.strip()
        .decode("utf-8")
    )
    if user_name != "":
        default_author = user_name
    else:
        return ""
    user_email = (
        subprocess.run(
            "git config --global user.email", shell=True, stdout=subprocess.PIPE
        )
        .stdout.strip()
        .decode("utf-8")
    )
    if user_email != "" and user_email is not None:
        default_author = default_author + " <" + user_email + ">"
    return default_author


def gitkeep(path):
    with open(os.path.join(path, ".gitkeep"), "w") as fp:
        pass

def main():

    # Load metadata config
    config = utils.load_config()

    # User inputs
    #
    data = {}

    print("Namespaces: " + ",".join(config['namespace'].keys()))
    data["namespace"] = process_namespace(prompt("Namespace", "aws"))
    if data["namespace"] not in config['namespace'].keys():
        raise ValueError(f"Unknown namespace")

    data["name"] = process_recipe_name(
        prompt("Recipe name [a-z_]+", None, allow_empty=False)
    )
    # Validate destination directory before accepting any more user input
    dest_dir = Path.joinpath(utils.RECIPES, data["namespace"], data["name"])
    if Path(dest_dir).exists():
        raise ValueError(f"A recipe named '{data['name']}' exists")

    # TODO - add version support back later if we establish a need for them
    # data["version"] = process_version(
    #     prompt(
    #         "Version (must be compatible with semantic versioning)",
    #         default="1.0.0",
    #         allow_empty=False,
    #     )
    # )
    data["version"] = "1.0.0"

    data["description"] = prompt("Short description", allow_empty=False)

    data["authors"] = process_authors(
        prompt(
            "Author (comma-separated values for multiple)",
            default=default_author(),
            allow_empty=True,
        )
    )
    data["tags"] = process_tags(
        prompt("Tags (comma-separated values for multiple)", allow_empty=True)
    )

    # Create directory structure
    # Root directory
    os.mkdir(dest_dir)
    gitkeep(dest_dir)
    # Empty subdirectories
    for dir in ["assets", "docs", "tests"]:
        sub_dir = Path.joinpath(dest_dir, dir)
        os.mkdir(sub_dir)
        gitkeep(sub_dir)

    # Write files
    environment = Environment(loader=FileSystemLoader(utils.TEMPLATES), autoescape=select_autoescape())
    for fname in ["README.md", "metadata.yml", "Makefile"]:
        template = environment.get_template(fname + ".j2")
        content = template.render(**data)
        dest_filename = Path.joinpath(dest_dir, fname)
        with open(dest_filename, mode="w", encoding="utf-8") as rendered_file:
            rendered_file.write(content)


if __name__ == "__main__":
    main()
