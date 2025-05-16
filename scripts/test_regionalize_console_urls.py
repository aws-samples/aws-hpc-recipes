#!/usr/bin/env python3
"""
Unit tests for the regionalize_console_urls.py script.
"""

import unittest
import tempfile
import os
import sys
from pathlib import Path

# Add the parent directory to the path so we can import from regionalize_console_urls
sys.path.append(str(Path(__file__).resolve().parent))

from regionalize_console_urls import process_file

class TestRegionalizeConsoleUrls(unittest.TestCase):
    def setUp(self):
        # Create a temporary directory for test files
        self.test_dir = tempfile.TemporaryDirectory()
    
    def tearDown(self):
        # Clean up the temporary directory
        self.test_dir.cleanup()
    
    def test_console_domain_in_sub_mapping(self):
        # Test with console domain in a !Sub mapping
        test_content = '''
Outputs:
  PcsConsoleUrl:
    Description: URL to access the cluster in the PCS console
    Value: !Sub
      - https://${ConsoleDomain}/pcs/home?region=${AWS::Region}#/clusters/${ClusterId}
      - { ConsoleDomain: !Sub '${AWS::Region}.console.aws.amazon.com',
          ClusterId: !GetAtt [ PCSCluster, Id ] 
        }
'''
        expected_content = '''
Outputs:
  PcsConsoleUrl:
    Description: URL to access the cluster in the PCS console
    Value: !Sub
      - https://${ConsoleDomain}/pcs/home?region=${AWS::Region}#/clusters/${ClusterId}
      - { ConsoleDomain: !Sub '${AWS::Region}.console.${AWS::URLSuffix}',
          ClusterId: !GetAtt [ PCSCluster, Id ] 
        }
'''
        self._run_test(test_content, expected_content)
    
    def test_direct_url_in_sub(self):
        # Test with direct URL in a !Sub expression
        test_content = '''
Outputs:
  ConsoleUrl:
    Description: URL to access the console
    Value: !Sub "https://${AWS::Region}.console.aws.amazon.com/ec2/home?region=${AWS::Region}"
'''
        expected_content = '''
Outputs:
  ConsoleUrl:
    Description: URL to access the console
    Value: !Sub "https://${AWS::Region}.console.${AWS::URLSuffix}/ec2/home?region=${AWS::Region}"
'''
        self._run_test(test_content, expected_content)
    
    def test_direct_url_without_sub(self):
        # Test with direct URL without !Sub
        test_content = '''
Outputs:
  ConsoleUrl:
    Description: URL to access the console
    Value: "https://console.aws.amazon.com/ec2/home"
'''
        expected_content = '''
Outputs:
  ConsoleUrl:
    Description: URL to access the console
    Value: !Sub "https://console.${AWS::URLSuffix}/ec2/home"
'''
        self._run_test(test_content, expected_content)
    
    def test_already_regionalized(self):
        # Test with already regionalized URLs
        test_content = '''
Outputs:
  ConsoleUrl:
    Description: URL to access the console
    Value: !Sub "https://console.${AWS::URLSuffix}/ec2/home?region=${AWS::Region}"
'''
        # Content should remain unchanged
        self._run_test(test_content, test_content)
    
    def test_mixed_urls(self):
        # Test with a mix of URL formats
        test_content = '''
Outputs:
  ConsoleUrl1:
    Description: URL to access the console
    Value: !Sub "https://${AWS::Region}.console.aws.amazon.com/ec2/home?region=${AWS::Region}"
  ConsoleUrl2:
    Description: URL to access the console
    Value: !Sub
      - https://${ConsoleDomain}/pcs/home?region=${AWS::Region}
      - { ConsoleDomain: !Sub '${AWS::Region}.console.aws.amazon.com' }
  ConsoleUrl3:
    Description: URL to access the console
    Value: !Sub "https://console.${AWS::URLSuffix}/ec2/home?region=${AWS::Region}"
'''
        expected_content = '''
Outputs:
  ConsoleUrl1:
    Description: URL to access the console
    Value: !Sub "https://${AWS::Region}.console.${AWS::URLSuffix}/ec2/home?region=${AWS::Region}"
  ConsoleUrl2:
    Description: URL to access the console
    Value: !Sub
      - https://${ConsoleDomain}/pcs/home?region=${AWS::Region}
      - { ConsoleDomain: !Sub '${AWS::Region}.console.${AWS::URLSuffix}' }
  ConsoleUrl3:
    Description: URL to access the console
    Value: !Sub "https://console.${AWS::URLSuffix}/ec2/home?region=${AWS::Region}"
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