"""Test runner for queue module."""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest


def main():
    """Run all queue tests."""
    # Run pytest on the tests directory
    exit_code = pytest.main([
        __file__,
        "-v",
        "--tb=short"
    ])
    
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
