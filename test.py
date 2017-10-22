#!/usr/bin/env python3

import unittest
import os
import shutil
import time

from pathlib import Path

from produksjonsystem import Pipeline

def fun(x):
    return x + 1

class PipelineTest(unittest.TestCase):
    def test(self):
        target = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'target')
        dir_in = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'target/in')
        dir_out = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'target/out')
        if os.path.exists(target):
            shutil.rmtree(target)
        os.makedirs(dir_in)
        os.makedirs(dir_out)
        
        pipeline = Pipeline(dir_in)
        self.assertEqual(len(pipeline.queue), 0)
        pipeline.start()
        time.sleep(1)
        
        Path(os.path.join(dir_in, 'foo.epub')).touch()
        time.sleep(1)
        self.assertEqual(len(pipeline.queue), 1)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'foo.epub']), 1)
        
        with open(os.path.join(dir_in, 'foo.epub'), "a") as f:
            f.write("bar")
        time.sleep(1)
        self.assertEqual(len(pipeline.queue), 1)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'foo.epub']), 1)
        
        shutil.move(os.path.join(dir_in, 'foo.epub'), os.path.join(dir_in, 'bar.epub'))
        time.sleep(1)
        self.assertEqual(len(pipeline.queue), 2)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'foo.epub']), 1)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'bar.epub']), 1)
        
        with open(os.path.join(dir_in, 'baz.epub'), "a") as f:
            f.write("baz")
        time.sleep(1)
        self.assertEqual(len(pipeline.queue), 3)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'foo.epub']), 1)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'bar.epub']), 1)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'baz.epub']), 1)
        
        os.remove(os.path.join(dir_in, 'bar.epub'))
        time.sleep(1)
        self.assertEqual(len(pipeline.queue), 3)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'foo.epub']), 1)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'bar.epub']), 1)
        self.assertEqual(len([b['book'] for b in pipeline.queue if b['book'] == 'baz.epub']), 1)
        
        time.sleep(2)
        pipeline.stop()

if __name__ == '__main__':
    unittest.main()
