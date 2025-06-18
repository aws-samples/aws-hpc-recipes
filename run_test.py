#!/usr/bin/env python3

import sys
import os
import unittest
from pathlib import Path

# Add the scripts directory to the path
sys.path.append(str(Path(__file__).resolve().parent / "scripts"))

def run_arn_test():
    from regionalize_arns import process_file
    
    # Process the test template
    template_path = "test_template.yaml"
    replacements = process_file(template_path)
    print(f"Processed {template_path}: {replacements} ARNs regionalized")
    
    # Show the modified file
    with open(template_path, 'r') as file:
        print("\nModified template:")
        print(file.read())

def run_console_urls_test():
    from regionalize_console_urls import process_file
    
    # Process the test template
    template_path = "test_console_urls_template.yaml"
    replacements = process_file(template_path)
    print(f"Processed {template_path}: {replacements} console URLs updated")
    
    # Show the modified file
    with open(template_path, 'r') as file:
        print("\nModified template:")
        print(file.read())

def run_unit_tests():
    # Discover and run all unit tests
    loader = unittest.TestLoader()
    start_dir = os.path.join(Path(__file__).resolve().parent, "scripts")
    suite = loader.discover(start_dir, pattern="test_*.py")
    
    runner = unittest.TextTestRunner()
    result = runner.run(suite)
    
    return result.wasSuccessful()

if __name__ == "__main__":
    print("=== Running ARN regionalization test ===")
    run_arn_test()
    
    print("\n=== Running console URL regionalization test ===")
    run_console_urls_test()
    
    print("\n=== Running unit tests ===")
    success = run_unit_tests()
    
    if not success:
        sys.exit(1)