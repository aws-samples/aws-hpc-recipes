# Contributing Guidelines

Thank you for your interest in contributing to our project. Whether it's a bug report, new feature, correction, or additional
documentation, we greatly value feedback and contributions from our community.

Please read through this document before submitting any issues or pull requests to ensure we have all the necessary
information to effectively respond to your bug report or contribution.

## Security issue notifications

If you discover a potential security issue in this project we ask that you notify AWS/Amazon Security via our [vulnerability reporting page](http://aws.amazon.com/security/vulnerability-reporting/). Please do **not** create a public github issue.

## Contributing new recipes

We request that you follow these guidelines:

1. Populate your recipe `metadata.yml` file as fully and accurately as you can. This information is used to render the recipes index page. 
2. Make sure your README is populated with enough detail for people to understand what your recipe does and how to use it. Ensure that every asset is documented, where feasible, with a comment describing what it does. If an asset has an explicit description field, like CloudFormation templates do, populate it. 
3. Test your recipe. Can you successfully create or manage resources with it. If your recipe uses CloudFormation, confirm that the stack (and all of its resources) successfully deleted.
4. Format your assets to make them as readable as possible. Use PEP conventions for Python, prettify YAML and JSON files, and so on. Also, comment liberally. 
5. Use linters to check your assets for syntax errors. There isn't one specific tool we recommend, only that you do try to validate your assets where possible. 
6. Review IAM resources. If you include IAM resources, follow the standard security advice of granting least privilege (granting only the permissions required to do a task).
7. Remove secrets/credentials from your recipe. You might hardcode credentials or secrets when you're testing but don't forget to remove them before submitting! You can use this tool to help you scrub secrets: https://github.com/awslabs/git-secrets

When your recipe is ready, submit a pull request. One of the maintainers will review your request and might suggest changes. We review recipes to check for general security issues, but we won't test or maintain them. If we don't get back to you within a week of your submission, use your pull request to send us a message.

## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest features.

When filing an issue, please check existing open, or recently closed, issues to make sure somebody else hasn't already
reported the issue. Please try to include as much information as you can. Details like these are incredibly useful:

* A reproducible test case or series of steps
* The version of our code being used
* Any modifications you've made relevant to the bug
* Anything unusual about your environment or deployment


## Contributing via Pull Requests
Contributions via pull requests are much appreciated. Before sending us a pull request, please ensure that:

1. You are working against the latest source on the *main* branch.
2. You check existing open, and recently merged, pull requests to make sure someone else hasn't addressed the problem already.
3. You open an issue to discuss any significant work - we would hate for your time to be wasted.

To send us a pull request, please:

1. Fork the repository.
2. Modify the source; please focus on the specific change you are contributing. If you also reformat all the code, it will be hard for us to focus on your change.
3. Ensure local tests pass.
4. Commit to your fork using clear commit messages.
5. Send us a pull request, answering any default questions in the pull request interface.
6. Pay attention to any automated CI failures reported in the pull request, and stay involved in the conversation.

GitHub provides additional document on [forking a repository](https://help.github.com/articles/fork-a-repo/) and
[creating a pull request](https://help.github.com/articles/creating-a-pull-request/).


## Finding contributions to work on
Looking at the existing issues is a great way to find something to contribute on. As our projects, by default, use the default GitHub issue labels (enhancement/bug/duplicate/help wanted/invalid/question/wontfix), looking at any 'help wanted' issues is a great place to start.


## Code of Conduct
This project has adopted the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).
For more information see the [Code of Conduct FAQ](https://aws.github.io/code-of-conduct-faq) or contact
opensource-codeofconduct@amazon.com with any additional questions or comments.


## Licensing

See the [LICENSE](LICENSE) file for our project's licensing. We will ask you to confirm the licensing of your contribution.
