#!/usr/bin/env python3
"""
Script to make console URLs in CloudFormation templates partition-aware.
This script finds all YAML files in the recipes directory and replaces hardcoded
'console.aws.amazon.com' with a construct that uses AWS::URLSuffix to make templates
work in all AWS partitions, including GovCloud.
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
        
        # Skip files that already use AWS::URLSuffix for all console URLs
        if 'AWS::URLSuffix' in content and 'console.aws.amazon.com' not in content:
            print(f"Skipping {file_path} - already using AWS::URLSuffix")
            return 0
        
        # We'll use line-by-line processing to handle console URLs correctly
        lines = content.split('\n')
        modified_lines = []
        replacements = 0
        
        for line in lines:
            # Skip lines that already use AWS::URLSuffix
            if 'AWS::URLSuffix' in line:
                modified_lines.append(line)
                continue
            
            # Check if the line contains a console URL
            if 'console.aws.amazon.com' in line:
                # Handle the case where the console domain is defined in a !Sub mapping
                if 'ConsoleDomain: !Sub' in line and 'console.aws.amazon.com' in line:
                    # Replace the console domain with a construct that uses AWS::URLSuffix
                    modified_line = line.replace(
                        "!Sub '${AWS::Region}.console.aws.amazon.com'",
                        "!Sub '${AWS::Region}.console.${AWS::URLSuffix}'"
                    )
                    replacements += 1
                # Handle direct URLs in !Sub expressions
                elif '!Sub' in line and 'https://' in line and 'console.aws.amazon.com' in line:
                    # Replace the console domain with AWS::URLSuffix
                    modified_line = line.replace(
                        'console.aws.amazon.com',
                        'console.${AWS::URLSuffix}'
                    )
                    replacements += 1
                # Handle direct URLs without !Sub
                elif 'https://' in line and 'console.aws.amazon.com' in line:
                    # Add !Sub and replace the console domain
                    modified_line = line.replace(
                        'https://console.aws.amazon.com',
                        '!Sub "https://console.${AWS::URLSuffix}"'
                    )
                    replacements += 1
                else:
                    # For other cases, just replace the domain
                    modified_line = line.replace(
                        'console.aws.amazon.com',
                        'console.${AWS::URLSuffix}'
                    )
                    replacements += 1
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
            print(f"Modified {file_path} - {replacements} console URLs updated")
            total_replacements += replacements
            modified_files += 1
    
    print(f"\nSummary:")
    print(f"- {modified_files} files modified")
    print(f"- {total_replacements} console URLs updated")

if __name__ == "__main__":
    main()