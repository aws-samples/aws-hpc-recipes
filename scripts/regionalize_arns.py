#!/usr/bin/env python3
"""
Script to regionalize ARNs in CloudFormation templates to support GovCloud.
This script finds all YAML files in the recipes directory and replaces hardcoded
'arn:aws:' with '!Sub "arn:${AWS::Partition}:' to make templates work in all AWS partitions.
"""

import re
import os
from pathlib import Path
import yaml
import sys

# Import utility functions
from utils import REPO, RECIPES

# Function to check if a file is a CloudFormation template
def is_cloudformation_template(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()
            # Check for common CloudFormation indicators
            return ('AWSTemplateFormatVersion' in content or 
                    'Resources:' in content or 
                    'Outputs:' in content)
    except Exception:
        return False

# Function to process a single file
def process_file(file_path):
    try:
        with open(file_path, 'r') as file:
            content = file.read()
        
        # Skip files that already use AWS::Partition for all ARNs
        if 'arn:${AWS::Partition}:' in content and 'arn:aws:' not in content:
            print(f"Skipping {file_path} - already using AWS::Partition")
            return 0
        
        # We'll use line-by-line processing to handle ARNs correctly
        lines = content.split('\n')
        modified_lines = []
        replacements = 0
        
        for line in lines:
            # Skip lines that already use !Sub for ARNs
            if '!Sub' in line and 'arn:${AWS::Partition}:' in line:
                modified_lines.append(line)
                continue
            
            # Check if the line contains an ARN
            if 'arn:aws:' in line:
                # Replace quoted ARNs
                if '"arn:aws:' in line or "'arn:aws:" in line:
                    # Replace double-quoted ARNs
                    if '"arn:aws:' in line:
                        modified_line = line.replace('"arn:aws:', '!Sub "arn:${AWS::Partition}:')
                        replacements += line.count('"arn:aws:')
                    # Replace single-quoted ARNs
                    elif "'arn:aws:" in line:
                        modified_line = line.replace("'arn:aws:", "!Sub 'arn:${AWS::Partition}:")
                        replacements += line.count("'arn:aws:")
                    modified_lines.append(modified_line)
                else:
                    # Handle unquoted ARNs
                    modified_line = line.replace('arn:aws:', '!Sub arn:${AWS::Partition}:')
                    replacements += line.count('arn:aws:')
                    modified_lines.append(modified_line)
            else:
                modified_lines.append(line)
        
        if replacements > 0:
            # Write the modified content back to the file
            with open(file_path, 'w') as file:
                file.write('\n'.join(modified_lines))
        
        return replacements
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return 0

# Main function to find and process all CloudFormation templates
def main():
    yaml_files = []
    
    # Find all YAML files in the recipes directory
    for root, _, files in os.walk(RECIPES):
        for file in files:
            if file.endswith(('.yaml', '.yml')):
                file_path = os.path.join(root, file)
                if is_cloudformation_template(file_path):
                    yaml_files.append(file_path)
    
    print(f"Found {len(yaml_files)} CloudFormation template files")
    
    # Process each file
    total_replacements = 0
    modified_files = 0
    
    for file_path in yaml_files:
        replacements = process_file(file_path)
        if replacements > 0:
            print(f"Modified {file_path} - {replacements} ARNs regionalized")
            total_replacements += replacements
            modified_files += 1
    
    print(f"\nSummary:")
    print(f"- {modified_files} files modified")
    print(f"- {total_replacements} ARNs regionalized")

if __name__ == "__main__":
    main()