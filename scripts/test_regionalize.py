#!/usr/bin/env python3
"""
Unit tests for FSx Lustre deployment type handling in GovCloud regions
"""

import unittest
import os
import yaml
from pathlib import Path

class TestFSxGovCloud(unittest.TestCase):
    def setUp(self):
        self.test_file = Path(__file__).resolve().parent.parent / "test_fsx_govcloud.yaml"
        self.expected_file = Path(__file__).resolve().parent.parent / "test_fsx_govcloud_expected.yaml"
        
        # Load test files
        with open(self.test_file, 'r') as f:
            self.test_template = yaml.safe_load(f)
        with open(self.expected_file, 'r') as f:
            self.expected_template = yaml.safe_load(f)

    def test_govcloud_condition_exists(self):
        """Test that the IsGovCloud condition is properly defined"""
        self.assertIn('Conditions', self.test_template)
        self.assertIn('IsGovCloud', self.test_template['Conditions'])
        
        condition = self.test_template['Conditions']['IsGovCloud']
        self.assertEqual(condition[0], 'Fn::Equals')
        self.assertEqual(condition[1][0]['Fn::Sub'], '${AWS::Partition}')
        self.assertEqual(condition[1][1], 'aws-us-gov')

    def test_deployment_type_condition(self):
        """Test that the deployment type uses the IsGovCloud condition"""
        fsx = self.test_template['Resources']['FSxLFilesystem']
        deployment_type = fsx['Properties']['LustreConfiguration']['DeploymentType']
        
        self.assertEqual(deployment_type[0], 'Fn::If')
        self.assertEqual(deployment_type[1], 'IsGovCloud')
        self.assertEqual(deployment_type[2], 'PERSISTENT_1')
        self.assertEqual(deployment_type[3], 'PERSISTENT_2')

if __name__ == '__main__':
    unittest.main()