#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import yaml
from shutil import copyfile

files = "files.yml"
path = (os.path.realpath(__file__))
path = os.path.dirname(path)
path_oneup = os.path.dirname(path)
identifier = os.path.basename(path_oneup)

if os.path.isfile(os.path.join(path, files)):
    with open(os.path.join(path, files), 'r') as f:
        files_doc = yaml.load(f, Loader=yaml.FullLoader) or {}
else:
    print("Fant ikke " + files)

for file_name in files_doc:
    path_to_file = os.path.join(path_oneup, files_doc[file_name])
    dir = os.path.join(path, "RESTORED", identifier, os.path.dirname(file_name))
    if not os.path.exists(dir):
        os.makedirs(dir)
    copyfile(path_to_file, os.path.join(path, "RESTORED", identifier, file_name))
