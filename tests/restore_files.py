#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import yaml
from shutil import copyfile

files = "files.yml"
path = (os.path.realpath(__file__))
path = os.path.dirname(path)

if os.path.isfile(os.path.join(path, files)):
    with open(os.path.join(path, files), 'r') as f:
        files_doc = yaml.load(f) or {}
else:
    print("Fant ikke " + files)

for filename in files_doc:
    path_to_file = files_doc[filename]
    file_loc = path_to_file.split('/')

    for i in range(len(file_loc)):

        if file_loc[i] == "NLBPUB-tidligere":
            i += 3
            rel_path = file_loc[i-2]
            for j in range(i, len(file_loc)):
                rel_path = os.path.join(rel_path, file_loc[j])
            dir = os.path.join("RESTORED", os.path.dirname(rel_path))
            if not os.path.exists(dir):
                os.makedirs(dir)
            copyfile(path_to_file, os.path.join(path, "RESTORED", rel_path))
