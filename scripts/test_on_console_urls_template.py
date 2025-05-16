#!/usr/bin/env python3
"""
Test script to run the regionalize_console_urls.py script on the test template.
"""

import sys
import os
from pathlib import Path
import filecmp

# Add the parent directory to the path so we can import from regionalize_console_urls
sys.path.append(str(Path(__file__).resolve().parent))

from regionalize_console_urls import process_file

def main():
    # Define paths
    test_template = os.path.join(Path(__file__).resolve().parent.parent, "test_console_urls_template.yaml")
    expected_template = os.path.join(Path(__file__).resolve().parent.parent, "test_console_urls_template_expected.yaml")
    
    # Make a copy of the test template to work with
    import shutil
    temp_template = os.path.join(Path(__file__).resolve().parent.parent, "test_console_urls_template_temp.yaml")
    shutil.copy2(test_template, temp_template)
    
    try:
        # Process the template
        replacements = process_file(temp_template)
        print(f"Processed {temp_template}: {replacements} console URLs updated")
        
        # Compare with expected output
        if filecmp.cmp(temp_template, expected_template):
            print("\nTest PASSED: Output matches expected template")
        else:
            print("\nTest FAILED: Output does not match expected template")
            
            # Show differences
            print("\nDifferences:")
            with open(temp_template, 'r') as f1, open(expected_template, 'r') as f2:
                import difflib
                diff = difflib.unified_diff(
                    f1.readlines(),
                    f2.readlines(),
                    fromfile='Output',
                    tofile='Expected'
                )
                for line in diff:
                    sys.stdout.write(line)
    finally:
        # Clean up
        if os.path.exists(temp_template):
            os.remove(temp_template)

if __name__ == "__main__":
    main()