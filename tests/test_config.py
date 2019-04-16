#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../produksjonssystem')))
from core.config import Config

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class FilesystemTest(unittest.TestCase):
    def test_merge_dicts(self):
        config = {}

        new = {'logging': {'level': 10}}
        Config._merge_dicts(config, new)
        self.assertEqual(config, {'logging': {'level': 10}})

        new = {'logging': {'format': "%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s"}}
        Config._merge_dicts(config, new)
        self.assertEqual(config, {'logging': {'level': 10, 'format': "%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s"}})

        new = {'logging': {'some': {'subdict': None}}}
        Config._merge_dicts(config, new)
        self.assertEqual(config, {'logging': {'level': 10, 'format': "%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s", 'some': {'subdict': None}}})

        new = {'logging': {'some': {'subdict': 42}}}
        Config._merge_dicts(config, new)
        self.assertEqual(config, {'logging': {'level': 10, 'format': "%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s", 'some': {'subdict': 42}}})

        new = {'logging': {'some': 113}}
        Config._merge_dicts(config, new)
        self.assertEqual(config, {'logging': {'level': 10, 'format': "%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s", 'some': 113}})

        new = {'logging': {'some': [1, 2, 3]}}
        Config._merge_dicts(config, new)
        self.assertEqual(config, {'logging': {'level': 10, 'format': "%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s", 'some': [1, 2, 3]}})


if __name__ == '__main__':
    unittest.main()
