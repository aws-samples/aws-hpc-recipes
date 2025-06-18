#!/usr/bin/env python3

import sys
import os
from pathlib import Path
import unittest

# Add the scripts directory to the path
sys.path.append(str(Path(__file__).resolve().parent / "scripts"))

# Import the test class
from test_regionalize_console_urls import TestRegionalizeConsoleUrls

if __name__ == "__main__":
    # Run the tests
    unittest.main(argv=['first-arg-is-ignored'], exit=False)
    print("Tests completed.")