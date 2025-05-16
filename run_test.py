#!/usr/bin/env python3

import sys
import os
from pathlib import Path

# Add the scripts directory to the path
sys.path.append(str(Path(__file__).resolve().parent / "scripts"))

from regionalize_arns import process_file

# Process the test template
template_path = "test_template.yaml"
replacements = process_file(template_path)
print(f"Processed {template_path}: {replacements} ARNs regionalized")

# Show the modified file
with open(template_path, 'r') as file:
    print("\nModified template:")
    print(file.read())