#!/usr/bin/env python3
"""
Test script to verify the ARN regionalization logic on a single template.
"""

import sys
import os
from pathlib import Path
import shutil

# Add the parent directory to the path so we can import from regionalize_arns
sys.path.append(str(Path(__file__).resolve().parent))

from regionalize_arns import process_file

def main():
    if len(sys.argv) != 2:
        print("Usage: python test_regionalize.py <path_to_template>")
        sys.exit(1)
    
    template_path = sys.argv[1]
    if not os.path.exists(template_path):
        print(f"Error: File {template_path} does not exist")
        sys.exit(1)
    
    # Create a backup of the original file
    backup_path = f"{template_path}.bak"
    shutil.copy2(template_path, backup_path)
    print(f"Created backup at {backup_path}")
    
    # Process the file
    replacements = process_file(template_path)
    print(f"Processed {template_path}: {replacements} ARNs regionalized")
    
    # Show a diff of the changes
    print("\nChanges made:")
    os.system(f"diff {backup_path} {template_path}")
    
    # For automated testing, we'll keep the changes
    print("\nKeeping changes for testing")
    
    # Remove the backup
    os.remove(backup_path)
    print("Backup removed")

if __name__ == "__main__":
    main()