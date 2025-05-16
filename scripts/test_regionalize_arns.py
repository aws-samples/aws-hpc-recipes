#!/usr/bin/env python3
"""
Unit tests for the regionalize_arns.py script.
"""

import unittest
import tempfile
import os
import sys
from pathlib import Path

# Add the parent directory to the path so we can import from regionalize_arns
sys.path.append(str(Path(__file__).resolve().parent))

from regionalize_arns import process_file

class TestRegionalizeArns(unittest.TestCase):
    def setUp(self):
        # Create a temporary directory for test files
        self.test_dir = tempfile.TemporaryDirectory()
    
    def tearDown(self):
        # Clean up the temporary directory
        self.test_dir.cleanup()
    
    def test_double_quoted_arns(self):
        # Test with double-quoted ARNs
        test_content = '''
Resources:
  TestRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
'''
        expected_content = '''
Resources:
  TestRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - !Sub "arn:${AWS::Partition}:iam::aws:policy/AmazonS3ReadOnlyAccess"
'''
        self._run_test(test_content, expected_content)
    
    def test_single_quoted_arns(self):
        # Test with single-quoted ARNs
        test_content = '''
Resources:
  TestPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyDocument:
        Statement:
          - Resource: 'arn:aws:s3:::my-bucket/*'
'''
        expected_content = '''
Resources:
  TestPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyDocument:
        Statement:
          - Resource: !Sub 'arn:${AWS::Partition}:s3:::my-bucket/*'
'''
        self._run_test(test_content, expected_content)
    
    def test_unquoted_arns(self):
        # Test with unquoted ARNs
        test_content = '''
Resources:
  TestRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
'''
        expected_content = '''
Resources:
  TestRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - !Sub arn:${AWS::Partition}:iam::aws:policy/AmazonS3ReadOnlyAccess
'''
        self._run_test(test_content, expected_content)
    
    def test_already_regionalized(self):
        # Test with already regionalized ARNs
        test_content = '''
Resources:
  TestRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - !Sub "arn:${AWS::Partition}:iam::aws:policy/AmazonS3ReadOnlyAccess"
'''
        # Content should remain unchanged
        self._run_test(test_content, test_content)
    
    def test_mixed_arns(self):
        # Test with a mix of ARN formats
        test_content = '''
Resources:
  TestRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
        - !Sub "arn:${AWS::Partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
        - 'arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy'
'''
        expected_content = '''
Resources:
  TestRole:
    Type: AWS::IAM::Role
    Properties:
      ManagedPolicyArns:
        - !Sub "arn:${AWS::Partition}:iam::aws:policy/AmazonS3ReadOnlyAccess"
        - !Sub "arn:${AWS::Partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
        - !Sub 'arn:${AWS::Partition}:iam::aws:policy/CloudWatchAgentServerPolicy'
'''
        self._run_test(test_content, expected_content)
    
    def _run_test(self, test_content, expected_content):
        # Create a test file with the given content
        test_file = os.path.join(self.test_dir.name, "test.yaml")
        with open(test_file, 'w') as f:
            f.write(test_content)
        
        # Process the file
        process_file(test_file)
        
        # Read the processed file
        with open(test_file, 'r') as f:
            processed_content = f.read()
        
        # Compare with expected content
        self.assertEqual(processed_content, expected_content)

if __name__ == "__main__":
    unittest.main()