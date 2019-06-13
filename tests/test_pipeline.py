#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import shutil
import inspect
import logging
import unittest

from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../produksjonssystem')))
from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class PipelineTest(unittest.TestCase):
    target = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'target', 'unittest')
    dir_base = {"master": target}
    dir_in = os.path.join(target, 'in')
    dir_out = os.path.join(target, 'out')
    dir_reports = os.path.join(target, 'reports')
    pipeline = None

    def setUp(self):
        print("TEST: setUp")
        #logging.getLogger().setLevel(logging.DEBUG)
        if os.path.exists(self.target):
            shutil.rmtree(self.target)
        os.makedirs(self.dir_in)
        os.makedirs(self.dir_out)
        os.makedirs(self.dir_reports)
        self.pipeline = Pipeline(
            during_working_hours=True,
            during_night_and_weekend=True,
            _title="test",
            _uid="test"
        )
        self.pipeline._inactivity_timeout = 1

    def tearDown(self):
        print("TEST: tearDown")
        time.sleep(2)
        self.pipeline.stop()
        self.pipeline.join()
        time.sleep(2)
        shutil.rmtree(self.target)
        #logging.getLogger().setLevel(logging.INFO)

    def test_file(self):
        print("TEST: " + inspect.stack()[0][3])

        self.pipeline._handle_book_events_thread = lambda: None  # disable handling of book events (prevent emptying _md5 variable)
        self.pipeline.start(inactivity_timeout=2, dir_in=self.dir_in, dir_out=self.dir_out, dir_reports=self.dir_reports, dir_base=self.dir_base)
        time.sleep(2)
        self.assertEqual(len(self.pipeline._md5), 0)

        Path(os.path.join(self.dir_in, '1_foo.epub')).touch()
        time.sleep(2)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '1_foo.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_foo.epub']), 1)

        with open(os.path.join(self.dir_in, '1_foo.epub'), "a") as f:
            f.write("2_bar")
        time.sleep(2)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '1_foo.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_foo.epub']), 1)

        shutil.move(os.path.join(self.dir_in, '1_foo.epub'), os.path.join(self.dir_in, '2_bar.epub'))
        time.sleep(2)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '2_bar.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 2)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_foo.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '2_bar.epub']), 1)

        with open(os.path.join(self.dir_in, '3_baz.epub'), "a") as f:
            f.write("3_baz")
        time.sleep(2)
        self.assertEqual(len(self.pipeline._md5), 2)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '2_bar.epub']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '3_baz.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 3)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_foo.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '2_bar.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '3_baz.epub']), 1)

        os.remove(os.path.join(self.dir_in, '2_bar.epub'))
        time.sleep(2)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '3_baz.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 3)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_foo.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '2_bar.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '3_baz.epub']), 1)

    def test_folder(self):
        print("TEST: " + inspect.stack()[0][3])

        # create three books before starting the pipeline
        os.makedirs(os.path.join(self.dir_in, '1_book'))
        Path(os.path.join(self.dir_in, '1_book/ncc.html')).touch()
        os.makedirs(os.path.join(self.dir_in, '2_book'))
        Path(os.path.join(self.dir_in, '2_book/ncc.html')).touch()
        Path(os.path.join(self.dir_in, '2_book/image.png')).touch()
        os.makedirs(os.path.join(self.dir_in, '3_book'))
        Path(os.path.join(self.dir_in, '3_book/ncc.html')).touch()
        time.sleep(1)

        # start the pipeline
        self.pipeline._handle_book_events_thread = lambda: None  # disable handling of book events (prevent emptying _md5 variable)
        self.pipeline.start(inactivity_timeout=2, dir_in=self.dir_in, dir_out=self.dir_out, dir_reports=self.dir_reports, dir_base=self.dir_base)
        time.sleep(3)

        # there should be no books in the queue, even though there is a folder in the input directory
        self.assertEqual(len(self.pipeline._queue), 0)

        # modify the book
        Path(os.path.join(self.dir_in, '1_book/audio1.mp3')).touch()
        Path(os.path.join(self.dir_in, '1_book/audio2.mp3')).touch()
        Path(os.path.join(self.dir_in, '1_book/content.html')).touch()
        Path(os.path.join(self.dir_in, '1_book/image.png')).touch()
        time.sleep(2)

        # there should be 1 books in the queue
        self.assertEqual(len(self.pipeline._md5), 3)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '1_book']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '2_book']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '3_book']), 1)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_book']), 1)

        # move a file from 2_book to 3_book
        shutil.move(os.path.join(self.dir_in, '2_book/image.png'), os.path.join(self.dir_in, '3_book/image.png'))
        time.sleep(2)

        # now there should be 3 books in the queue
        self.assertEqual(len(self.pipeline._md5), 3)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '1_book']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '2_book']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == '3_book']), 1)
        self.assertEqual(len(self.pipeline._queue), 3)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_book']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '2_book']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '3_book']), 1)

    def test_queue_handler(self):
        print("TEST: " + inspect.stack()[0][3])

        # start the pipeline
        self.pipeline.on_book_created = lambda: time.sleep(6)  # pretend like it takes a few seconds to handle a book
        self.pipeline.on_book_modified = lambda: time.sleep(6)  # pretend like it takes a few seconds to handle a book
        self.pipeline.on_book_deleted = lambda: time.sleep(6)  # pretend like it takes a few seconds to handle a book
        self.pipeline.start(inactivity_timeout=2, dir_in=self.dir_in, dir_out=self.dir_out, dir_reports=self.dir_reports, dir_base=self.dir_base)
        time.sleep(1)

        # There should be no books in the queue to begin with
        self.assertEqual(len(self.pipeline._queue), 0)

        # Create a book
        Path(os.path.join(self.dir_in, '1_book')).touch()
        time.sleep(3)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '1_book']), 1)

        # Create two more books while the first one is being processed
        Path(os.path.join(self.dir_in, '3_book')).touch()
        time.sleep(0.5)
        Path(os.path.join(self.dir_in, '2_book')).touch()
        time.sleep(3)
        self.assertEqual(self.pipeline.get_status(), "1_book")
        self.assertEqual(len(self.pipeline._queue), 2)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '2_book']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '3_book']), 1)

        # wait until 1_book should have been processed and 2_book have started
        time.sleep(6)
        self.assertEqual(self.pipeline.get_status(), "2_book")
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == '3_book']), 1)

        # wait until 2_book should have been processed and 3_book have started
        time.sleep(9)
        self.assertEqual(self.pipeline.get_status(), "3_book")
        self.assertEqual(len(self.pipeline._queue), 0)

        # wait until 3_book should have finished
        time.sleep(9)
        self.assertEqual(self.pipeline.get_status(), "Venter")
        self.assertEqual(len(self.pipeline._queue), 0)


if __name__ == '__main__':
    unittest.main()
