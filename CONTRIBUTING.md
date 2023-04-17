# Contributing to HPCDK

Before you submit a recipe, we suggest that you follow these guidelines to help maintain consistency between recipes.

1. Test your recipe. Can you successfully create or manage resources with it. If your recipe uses CloudFormation, confirm that the stack (and all of its resources) successfully deleted.
2. Make sure your README is populated with enough detail for people to understand what your recipe does and how to use it. Ensure that every asset is documented, where feasible, with a comment describing what it does. If an asset has an explicit description field, like CloudFormation templates do, populate it. 
3. Format your assets to make them as readable as possible. Use PEP conventions for Python, prettify YAML and JSON files, and so on. Also, comment liberally. 
4. Use linters to check your assets for syntax errors. There isn't one specific tool we recommend, only that you do lint your assets where possible. 
5. Review IAM resources. If you include IAM resources, follow the standard security advice of granting least privilege (granting only the permissions required to do a task).
6. Remove secrets/credentials from your recipe. You might hardcode credentials or secrets when you're testing. Don't forget to remove them before submitting! You can use this tool to help you scrub secrets: https://github.com/awslabs/git-secrets
7. Populate your recipe `metadata.yml` file as fully and accurately as you can. This information is used to render the index page of all HPCDK recipes. 

When your recipe is ready, submit a pull request. A maintainer of the repository will review your request and might suggest changes. We review recipes to check for general security issues, but we won't test or maintain them. If we don't get back to you within a week of your submission, use your pull request to send us a message.
