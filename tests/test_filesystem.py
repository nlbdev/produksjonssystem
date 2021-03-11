#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import unittest
import sys
import os
import shutil
import time

from dotmap import DotMap
from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../produksjonssystem')))
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class MockPipeline():
    messages = None
    book = None
    dir_in = None
    dir_out = None
    utils = None

    def __init__(self, book_source=None, dir_in=None, dir_out=None):
        self.messages = []
        self.utils = DotMap()
        self.utils.report = DotMap()
        self.utils.report.debug = lambda x: self.messages.append("[DEBUG] " + x)
        self.utils.report.info = lambda x: self.messages.append("[INFO] " + x)
        self.utils.report.warn = lambda x: self.messages.append("[WARN] " + x)
        self.utils.report.error = lambda x: self.messages.append("[ERROR] " + x)
        self.book = { "source": book_source }
        self.dir_in = dir_in
        self.dir_out = dir_out

class FilesystemTest(unittest.TestCase):
    target = None
    dir_in = None
    dir_out = None
    pipeline = None
    filesystem = None

    original_unlink = os.unlink

    @staticmethod
    def unlink(name, *args, **kwargs):
        if name in ["locked", "Thumbs.db"]:
            raise OSError("[Errno 16] Device or resource busy: '" + name + "'")
        else:
            FilesystemTest.original_unlink(name, *args, **kwargs)

    def setUp(self):
        print("TEST: setUp (override os.unlink)")
        self.target = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'target', 'unittest'))
        self.dir_in = os.path.join(self.target, "in")
        self.dir_out = os.path.join(self.target, "out")
        self.pipeline = MockPipeline(self.dir_in, self.dir_in, self.dir_out)
        self.filesystem = Filesystem(self.pipeline)

        if os.path.exists(self.target):
            shutil.rmtree(self.target)

        self.original_unlink = os.unlink
        os.unlink = FilesystemTest.unlink

    def tearDown(self):
        print("TEST: tearDown (reset original os.unlink)")
        os.unlink = self.original_unlink
        for m in self.pipeline.messages:
            print(m)
        shutil.rmtree(self.target)

    def test_copy_locked_files(self):

        print("creating book without any locked files")
        book1 = os.path.join(self.dir_in, "book1")
        os.makedirs(os.path.join(book1, "images"))
        Path(os.path.join(book1, "ncc.html")).touch()
        Path(os.path.join(book1, "images/Image.png")).touch()
        Path(os.path.join(book1, "images/zmage.png")).touch()

        print("creating book with a \"Thumbs.db\" file locked by Windows")
        book2 = os.path.join(self.dir_in, "book2")
        os.makedirs(os.path.join(book2, "images"))
        Path(os.path.join(book2, "ncc.html")).touch()
        Path(os.path.join(book2, "images/Image.png")).touch()
        Path(os.path.join(book2, "images/Thumbs.db")).touch()
        Path(os.path.join(book2, "images/zmage.png")).touch()

        print("creating book with a \"locked\" file locked by Windows")
        book3 = os.path.join(self.dir_in, "book3")
        os.makedirs(os.path.join(book3, "images"))
        Path(os.path.join(book3, "ncc.html")).touch()
        Path(os.path.join(book3, "images/Image.png")).touch()
        Path(os.path.join(book3, "images/locked")).touch()
        Path(os.path.join(book3, "images/zmage.png")).touch()

        target_book1 = os.path.join(self.dir_out, "book1")
        target_book2 = os.path.join(self.dir_out, "book2")
        target_book3 = os.path.join(self.dir_out, "book3")

        print("copy book1 to target_book1")
        Filesystem.copy(self.pipeline.utils.report, book1, target_book1)
        dirlist = os.listdir(target_book1)
        dirlist.sort()
        self.assertEqual(dirlist, ["images", "ncc.html"])
        dirlist = os.listdir(os.path.join(target_book1, "images"))
        dirlist.sort()
        self.assertEqual(dirlist, ["Image.png", "zmage.png"])
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[ERROR]")]) == 0)
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[WARN]")]) == 0)

        print("copy book1 to target_book1 once more")
        Filesystem.copy(self.pipeline.utils.report, book1, target_book1)
        dirlist = os.listdir(target_book1)
        dirlist.sort()
        self.assertEqual(dirlist, ["images", "ncc.html"])
        dirlist = os.listdir(os.path.join(target_book1, "images"))
        dirlist.sort()
        self.assertEqual(dirlist, ["Image.png", "zmage.png"])
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[ERROR]")]) == 0)
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[WARN]")]) == 0)

        print("copy book2 to target_book2")
        Filesystem.copy(self.pipeline.utils.report, book2, target_book2)
        dirlist = os.listdir(target_book2)
        dirlist.sort()
        self.assertEqual(dirlist, ["images", "ncc.html"])
        dirlist = os.listdir(os.path.join(target_book2, "images"))
        dirlist.sort()
        self.assertEqual(dirlist, ["Image.png", "zmage.png"])
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[ERROR]")]) == 0)
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[WARN]")]) == 0)

        print("copy book2 to target_book2 once more")
        Filesystem.copy(self.pipeline.utils.report, book2, target_book2)
        dirlist = os.listdir(target_book2)
        dirlist.sort()
        self.assertEqual(dirlist, ["images", "ncc.html"])
        dirlist = os.listdir(os.path.join(target_book2, "images"))
        dirlist.sort()
        self.assertEqual(dirlist, ["Image.png", "zmage.png"])
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[ERROR]")]) == 0)
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[WARN]")]) == 0)

        print("copy book3 to target_book3")
        Filesystem.copy(self.pipeline.utils.report, book3, target_book3)
        dirlist = os.listdir(target_book3)
        dirlist.sort()
        self.assertEqual(dirlist, ["images", "ncc.html"])
        dirlist = os.listdir(os.path.join(target_book3, "images"))
        dirlist.sort()
        self.assertEqual(dirlist, ["Image.png", "locked", "zmage.png"])
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[ERROR]")]) == 0)
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[WARN]")]) == 0)

        print("copy book3 to target_book3 once more")
        Filesystem.copy(self.pipeline.utils.report, book3, target_book3)
        dirlist = os.listdir(target_book3)
        dirlist.sort()
        self.assertEqual(dirlist, ["images", "ncc.html"])
        dirlist = os.listdir(os.path.join(target_book3, "images"))
        dirlist.sort()
        self.assertEqual(dirlist, ["Image.png", "locked", "zmage.png"])
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[WARN]")]) == 0)
        self.assertTrue(len([m for m in self.pipeline.messages if m.startswith("[ERROR]") and "/locked" in m]) >= 1)


if __name__ == '__main__':
    unittest.main()
