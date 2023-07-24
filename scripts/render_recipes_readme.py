from jinja2 import Environment
from jinja2 import FileSystemLoader
from pathlib import Path

from . import utils

def shield_image_url(name=None, color=None):
    # Returns a shields.io image URL for a name/hex color combination. Used to render tags.
    #
    # Reference - https://img.shields.io/badge/-core-%23146EB4
    if name is None:
        name = "button"
    if color is None:
        color = "CCCCCC"
    return f"https://img.shields.io/badge/-{name}-%23{color}"


def main():
    # Load metadata config
    config = utils.load_config()
    data = {
        "repo_name": "HPCDK",
        "namespaces": {}
    }
    
    # Iterate through namespaces
    for dir, desc in config.get("namespace", {}).items():
        data["namespaces"][dir] = { "description": desc, "recipes": []}
        # List directories in each namespace
        ns = Path(Path.joinpath(utils.RECIPES, dir))
        for entry in ns.iterdir():
            if entry.is_dir():
                config = utils.load_config(Path.joinpath(ns, entry, "metadata.yml"))
                # TODO - add tags to config - hard to compute in template
                data["namespaces"][dir]["recipes"].append(config)

    # Render file
    environment = Environment(loader=FileSystemLoader(utils.RECIPES_README_TEMPLATES))
    template = environment.get_template("README.md.j2")
    content = template.render(**data)
    print(content)


if __name__ == "__main__":
    main()
