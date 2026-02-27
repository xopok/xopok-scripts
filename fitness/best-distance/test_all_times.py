#!/usr/bin/python

import unittest
import sys
import os
import tempfile
import array

# Add the current directory to path to import all_times
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from all_times import silly, flt, complete, calcMinMaxs, clever, time_call


class TestAllTimes(unittest.TestCase):
    
    def setUp(self):
        """Set up test fixtures - create sample data"""
        # Simple test data: list of (time, distance) tuples
        self.simple_data = [
            (0, 0),
            (1, 1),
            (2, 2),
            (3, 3),
            (4, 4),
            (5, 5),
        ]
        
        self.larger_data = [
            (0, 0),
            (10, 100),
            (20, 250),
            (30, 400),
            (40, 600),
            (50, 800),
            (60, 1000),
        ]
    
    def test_silly_basic(self):
        """Smoke test for silly function - should return list of tuples"""
        result = silly(self.simple_data)
        self.assertIsInstance(result, list)
        # Result should be non-empty for data with multiple points
        self.assertGreater(len(result), 0)
        # Each item should be a tuple
        for item in result:
            self.assertIsInstance(item, tuple)
    
    def test_silly_larger_data(self):
        """Test silly with larger dataset"""
        result = silly(self.larger_data)
        self.assertIsInstance(result, list)
        self.assertGreater(len(result), 0)
    
    def test_flt_basic(self):
        """Smoke test for flt function"""
        # Create sample answer data
        answer = [(1, (10, 0, 1)), (2, (20, 0, 2)), (3, (15, 0, 3))]
        result = flt(answer)
        self.assertIsInstance(result, list)
    
    def test_flt_empty(self):
        """Test flt with empty input"""
        result = flt([])
        self.assertIsInstance(result, list)
        self.assertEqual(len(result), 0)
    
    def test_complete_basic(self):
        """Smoke test for complete function"""
        result = complete(self.simple_data)
        self.assertIsInstance(result, list)
        # Complete should return at least the original data
        self.assertGreaterEqual(len(result), len(self.simple_data))
        # First element should match
        self.assertEqual(result[0], self.simple_data[0])
    
    def test_complete_larger_data(self):
        """Test complete with larger dataset"""
        result = complete(self.larger_data)
        self.assertIsInstance(result, list)
        self.assertGreaterEqual(len(result), len(self.larger_data))
    
    def test_calcMinMaxs_basic(self):
        """Smoke test for calcMinMaxs function"""
        result = calcMinMaxs(array.array('d', [1.0, 2.0, 3.0, 4.0, 5.0]), self.simple_data)
        self.assertIsInstance(result, list)
        self.assertGreater(len(result), 0)
        # Each item should be a tuple of two arrays
        for mins, maxs in result:
            self.assertIsInstance(mins, array.array)
            self.assertIsInstance(maxs, array.array)
    
    def test_clever_basic(self):
        """Smoke test for clever function"""
        result = clever(self.simple_data)
        self.assertIsInstance(result, list)
        # Result should be non-empty for data with multiple points
        self.assertGreater(len(result), 0)
        # Each item should be a tuple
        for item in result:
            self.assertIsInstance(item, tuple)
    
    def test_clever_larger_data(self):
        """Test clever with larger dataset"""
        result = clever(self.larger_data)
        self.assertIsInstance(result, list)
        self.assertGreater(len(result), 0)
    
    def test_time_call(self):
        """Test time_call wrapper function"""
        def dummy_func(x):
            return x * 2
        
        elapsed, result = time_call(dummy_func, 5)
        self.assertIsInstance(elapsed, (int, float))
        self.assertGreaterEqual(elapsed, 0)
        self.assertEqual(result, 10)
    
    def test_full_pipeline(self):
        """Test the full pipeline: complete -> clever -> flt"""
        arr = complete(self.larger_data)
        clever_result = clever(arr)
        sorted_result = sorted(clever_result)
        filtered_result = flt(sorted_result)
        
        self.assertIsInstance(filtered_result, list)
        # Should have at least one result
        self.assertGreater(len(filtered_result), 0)
    
    def test_file_processing_smoke(self):
        """Smoke test for file processing - create temp file and process it"""
        # Create a temporary file with test data
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(str(self.larger_data))
            temp_filename = f.name
        
        try:
            # Simulate what happens in main when processing a file
            arr = eval(open(temp_filename).read())
            arr = complete(arr)
            
            clever_time, clever_answer = time_call(clever, arr)
            clever_answer = flt(sorted(clever_answer))
            
            self.assertIsInstance(clever_answer, list)
            self.assertGreater(clever_time, 0)
        finally:
            os.unlink(temp_filename)


if __name__ == '__main__':
    unittest.main()
