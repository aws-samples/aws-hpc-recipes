# Get Started Building for HPCDK

 HPCDK isn't opinionated about what goes into a recipe. Whether you're building with CloudFormation, CDK, Ansible, or even shell scripts, the only hard requirement is that your recipe needs to follow the project's layout and metadata scheme. Luckily, we've made this straightforward with an Python script that bootstraps a new recipe for you. 

## Install dependencies

Download a copy of the HPCDK source code and prepare a Python environment:
 1. Fork HPCDK and check out a local copy of that fork and change into the `hpcdk` directory
 2. Create a new Git branch that will contain your recipe. 
 3. Create a Python virtual environment `python -m venv .env` then activate it `source .env/bin/activate`
 4. Install the project's Python dependencies (there aren't many) `pip install -r requirements.txt`

## Create a new recipe

Activate your Python environment and intiialize a recipe:
 1. Change into the `hpcdk` directory
 2. Activate your Python virtual enviroment `source .env/bin/activate`
 5. Run the interactive new recipe script `python -m scripts.new_recipe`

Here's an example of this script in action:

```shell
python -m scripts.new_recipe
Namespaces: aws,db,dir,env,iam,ide,net,pcluster,scheduler,storage
Namespace [aws]: env
Recipe name [a-z_]+: install_figlet
Short description: Install the figlet ASCII art generator so you can create awesome login banners.
Author (comma-separated values for multiple) [Terry Whitlock <thwhit@example.org>]:
Tags (comma-separated values for multiple): community, experimental, environment, freesoftware
```

A few things to be aware of:
* At each prompt, you will see text in `[brackets]`. This is the default value if you do not provide one.
* Namespace controls under which `recipes/` sub-directory your contribution will be created. You must choose one of the designated options.
* The combination of namespace and your recipe name must be unqiue within the HPCDK repository.
* Short description is a sentence (or two) describing what your recipe does. It will be displayed on the recipes `README` page, so keep it succinct and descriptive. 
* You must define at least one author. The script attempts to figure out who you are by inspecting your git global `user.name` and `user.email`. You can add multiple authors here via a comma-separated list. 
* You can find the suggested "core" tags in `../config/metadata/values.yml#tags`. Feel free to define your own tags. They will simply render in grey on the recipes `README` page if they are not in the core list. 

## Develop your recipe

Put all downloadable scripts, templates, tarballs, etc. into your recipe's `assets` directory. This will be mirrored out to an Amazon S3 bucket when your contribution is merged with the main HPCDK repository. 

Write a nice `README.md` describing what your recipe does, what dependencies it has, and how to use it. If you need more than one page, add additional Markdown files under the `docs` subdirectory. If you need to incorporate diagrams or figures, put that collateral under `docs` as well. 

If there are any tests you wish to include, even if they are manual scripts to run, put them in `tests`. 

You can update your recipe's metadata by editing its `metadata.yml` file.

If you would like to test your new recipe from an S3 deployment, you can do so using the project Makefile (see [develop.md](./develop.md))

When you are ready to contribute your recipe to the main project, run some linting/validation processes on it. A few examples are provided in [linting](linting.md).

## Contributing

Follow the process in [CONTRIBUTING.md](../CONTRIBUTING.md) to contribute your new recipe via pull request. Thank you for your efforts!

