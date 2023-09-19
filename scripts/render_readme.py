from jinja2 import Environment, FileSystemLoader, select_autoescape
from pathlib import Path

from . import utils

def main():
    # Load metadata config
    config = utils.load_config()
    data = {
        "namespaces": {},
        "_internal": config['_internal'],
        "colors": config['colors'],
        "tags": config['tags']
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
    environment = Environment(loader=FileSystemLoader(utils.RECIPES_README_TEMPLATES), autoescape=select_autoescape())
    template = environment.get_template("README.md.j2")
    content = template.render(**data)
    dest_filename = utils.RECIPES_README_DESTINTAION
    with open(dest_filename, mode="w", encoding="utf-8") as rendered_file:
        rendered_file.write(content)

if __name__ == "__main__":
    main()
