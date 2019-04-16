#!/bin/bash

python3 -m unittest tests.test_pipeline
python3 -m unittest tests.test_filesystem
python3 -m unittest tests.test_config
