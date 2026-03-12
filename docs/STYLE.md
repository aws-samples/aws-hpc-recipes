# Code Style Conventions

## YAML
- 2-space indentation
- Quote strings when they contain special characters or could be misinterpreted
- Use `---` document start marker

## CloudFormation Templates
- Comment liberally — explain the "why", not just the "what"
- Group resources logically with section comments
- Use `Metadata::AWS::CloudFormation::Interface` to organize parameters in the console
- See `docs/CLOUDFORMATION.md` for partition and pattern rules

## Python
- Follow PEP 8 conventions
- Use type hints where appropriate
- Scripts live in `scripts/` and are invoked as modules: `python -m scripts.<name>`

## Markdown
- Use consistent heading levels (don't skip levels)
- Include language specification in fenced code blocks
- One sentence per line in source (for cleaner diffs)

## Pull Requests
- Title format: `[namespace/recipe] Description`
- Test recipe deployment before submitting
- Update documentation if adding new features
- Ensure all CloudFormation templates pass `make validate`
