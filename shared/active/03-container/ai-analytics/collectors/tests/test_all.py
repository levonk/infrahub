"""
Test runner for collector tests.
"""

import sys
import os

# Add the parent directory to the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

if __name__ == '__main__':
    import pytest
    
    # Run pytest with coverage
    exit_code = pytest.main([
        __file__,
        '-v',
        '--tb=short',
        '--cov=.',
        '--cov-report=term-missing',
        '--cov-report=html'
    ])
    
    sys.exit(exit_code)
