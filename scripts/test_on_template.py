#!/usr/bin/env python3
"""
Test script to run the regionalize_arns.py script on a specific template.
"""

import sys
import os
from pathlib import Path

# Add the parent directory to the path so we can import from regionalize_arns
sys.path.append(str(Path(__file__).resolve().parent))

from regionalize_arns import process_file

def main():
    if len(sys.argv) != 2:
        print("Usage: python test_on_template.py <path_to_template>")
        sys.exit(1)
    
    template_path = sys.argv[1]
    if not os.path.exists(template_path):
        print(f"Error: File {template_path} does not exist")
        sys.exit(1)
    
    # Process the file
    replacements = process_file(template_path)
    print(f"Processed {template_path}: {replacements} ARNs regionalized")
    
    # Show the modified file
    with open(template_path, 'r') as file:
        print("\nModified template:")
        print(file.read())

if __name__ == "__main__":
    main()