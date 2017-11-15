#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import unittest
import sys
import os
import shutil
import time
import inspect

from pathlib import Path

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../produksjonssystem')))
from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class PipelineTest(unittest.TestCase):
    target = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'target')
    dir_in = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'target/in')
    dir_out = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'target/out')
    dir_reports = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'target/reports')
    pipeline = None
    
    def setUp(self):
        print("TEST: setUp")
        if os.path.exists(self.target):
            shutil.rmtree(self.target)
        os.makedirs(self.dir_in)
        os.makedirs(self.dir_out)
        os.makedirs(self.dir_reports)
        self.pipeline = Pipeline()
    
    def tearDown(self):
        print("TEST: tearDown")
        time.sleep(2)
        self.pipeline.stop()
        time.sleep(2)
    
    def test_file(self):
        self.pipeline.title = inspect.stack()[0][3]
        print("TEST: " + self.pipeline.title)
        
        self.pipeline.start(inactivity_timeout=3600, dir_in=self.dir_in, dir_out=self.dir_out, dir_reports=self.dir_reports)
        time.sleep(2)
        self.assertEqual(len(self.pipeline._md5), 0)
        
        Path(os.path.join(self.dir_in, 'foo.epub')).touch()
        time.sleep(3)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'foo.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'foo.epub']), 1)
        
        with open(os.path.join(self.dir_in, 'foo.epub'), "a") as f:
            f.write("bar")
        time.sleep(3)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'foo.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'foo.epub']), 1)
        
        shutil.move(os.path.join(self.dir_in, 'foo.epub'), os.path.join(self.dir_in, 'bar.epub'))
        time.sleep(3)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'bar.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 2)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'foo.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'bar.epub']), 1)
        
        with open(os.path.join(self.dir_in, 'baz.epub'), "a") as f:
            f.write("baz")
        time.sleep(3)
        self.assertEqual(len(self.pipeline._md5), 2)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'bar.epub']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'baz.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 3)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'foo.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'bar.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'baz.epub']), 1)
        
        os.remove(os.path.join(self.dir_in, 'bar.epub'))
        time.sleep(3)
        self.assertEqual(len(self.pipeline._md5), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'baz.epub']), 1)
        self.assertEqual(len(self.pipeline._queue), 3)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'foo.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'bar.epub']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'baz.epub']), 1)
    
    def test_folder(self):
        self.pipeline.title = inspect.stack()[0][3]
        print("TEST: " + self.pipeline.title)
        
        # create three books before starting the pipeline
        os.makedirs(os.path.join(self.dir_in, 'book1'))
        Path(os.path.join(self.dir_in, 'book1/ncc.html')).touch()
        os.makedirs(os.path.join(self.dir_in, 'book2'))
        Path(os.path.join(self.dir_in, 'book2/ncc.html')).touch()
        Path(os.path.join(self.dir_in, 'book2/image.png')).touch()
        os.makedirs(os.path.join(self.dir_in, 'book3'))
        Path(os.path.join(self.dir_in, 'book3/ncc.html')).touch()
        time.sleep(1)
        
        # start the pipeline
        self.pipeline.start(inactivity_timeout=3600, dir_in=self.dir_in, dir_out=self.dir_out, dir_reports=self.dir_reports)
        time.sleep(3)
        
        # there should be no books in the queue, even though there is a folder in the input directory
        self.assertEqual(len(self.pipeline._queue), 0)
        
        # modify the book
        Path(os.path.join(self.dir_in, 'book1/audio1.mp3')).touch()
        Path(os.path.join(self.dir_in, 'book1/audio2.mp3')).touch()
        Path(os.path.join(self.dir_in, 'book1/content.html')).touch()
        Path(os.path.join(self.dir_in, 'book1/image.png')).touch()
        time.sleep(3)
        
        # there should be 1 books in the queue
        self.assertEqual(len(self.pipeline._md5), 3)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'book1']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'book2']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'book3']), 1)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book1']), 1)
        
        # move a file from book2 to book3
        shutil.move(os.path.join(self.dir_in, 'book2/image.png'), os.path.join(self.dir_in, 'book3/image.png'))
        time.sleep(3)
        
        # now there should be 3 books in the queue
        self.assertEqual(len(self.pipeline._md5), 3)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'book1']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'book2']), 1)
        self.assertEqual(len([b for b in self.pipeline._md5 if b == 'book3']), 1)
        self.assertEqual(len(self.pipeline._queue), 3)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book1']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book2']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book3']), 1)
    
    def test_queue_handler(self):
        self.pipeline.title = inspect.stack()[0][3]
        print("TEST: " + self.pipeline.title)
        
        # start the pipeline
        self.pipeline.start(inactivity_timeout=10, dir_in=self.dir_in, dir_out=self.dir_out, dir_reports=self.dir_reports)
        time.sleep(1)
        
        # There should be no books in the queue to begin with
        self.assertEqual(len(self.pipeline._queue), 0)
        
        # Create a book
        Path(os.path.join(self.dir_in, 'book1')).touch()
        time.sleep(3)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book1']), 1)
        
        # Create another book
        Path(os.path.join(self.dir_in, 'book2')).touch()
        time.sleep(4)
        self.assertEqual(len(self.pipeline._queue), 2)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book1']), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book2']), 1)
        
        # wait until book1 should have been processed
        time.sleep(6)
        self.assertEqual(len(self.pipeline._queue), 1)
        self.assertEqual(len([b['name'] for b in self.pipeline._queue if b['name'] == 'book2']), 1)
        
        # wait until book2 should have been processed
        time.sleep(4)
        self.assertEqual(len(self.pipeline._queue), 0)

if __name__ == '__main__':
    unittest.main()
