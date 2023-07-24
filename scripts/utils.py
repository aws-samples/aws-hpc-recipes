import yaml
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
REPO = SCRIPTS.parent
CONFIG = Path.joinpath(REPO, "config", "metadata", "values.yml")
RECIPES = Path.joinpath(REPO, "recipes")
TEMPLATES = Path.joinpath(REPO, "templates", "recipe")
RECIPES_README_TEMPLATES = Path.joinpath(REPO, "templates", "readme")
RECIPES_README_DESTINTAION = Path.joinpath(RECIPES, "README.md")

def load_config(path=None):
    if path is None:
        path = CONFIG
    with open(path, 'r') as file:
        config = yaml.safe_load(file)
        return config

