#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import traceback
import time
from threading import Thread
from core.pipeline import Pipeline

# Import pipelines
from incoming_nordic import IncomingNordic
from epub_to_html import EpubToHtml
from epub_to_dtbook import EpubToDtbook

# Check that archive dir is defined
assert os.environ.get("BOOK_ARCHIVE_DIR")
book_archive_dir = str(os.path.normpath(os.environ.get("BOOK_ARCHIVE_DIR")))

# Define directories
dirs = {
    "reports": os.path.join(book_archive_dir, "test-new-system/reports"),
    "nordic": os.path.join(book_archive_dir, "test-new-system/nordic-epub-in"),
    "master": os.path.join(book_archive_dir, "test-new-system/master"),
    "dtbook": os.path.join(book_archive_dir, "test-new-system/dtbook"),
    "html": os.path.join(book_archive_dir, "test-new-system/html"),
    "html_narration": os.path.join(book_archive_dir, "test-new-system/html-narration"),
    "ncc": os.path.join(book_archive_dir, "test-new-system/ncc")
}

# Define pipelines and input/output dirs
pipelines = [
    [ IncomingNordic(),  "nordic", "master", "reports" ],
    [ EpubToHtml(),      "master", "html",   "reports" ],
    [ EpubToDtbook(),    "master", "dtbook", "reports" ]
]


# ---------------------------------------------------------------------------
# Don't edit below this line if you only want to add/remove/modify a pipeline
# ---------------------------------------------------------------------------


# Make sure that directories are defined properly
for d in dirs:
    dirs[d] = os.path.normpath(dirs[d])
for d in dirs:
    assert dirs[d].startswith(book_archive_dir + "/"), "Directory \"" + d + "\" must be part of the book archive: " + dirs[d]
    assert len(dirs[d]) > len(book_archive_dir) + 1, "The directory \"" + d + "\" must not be equal to the book archive dir: " + dirs[d]
    assert len([x for x in dirs if dirs[x] == dirs[d]]), "The directory \"" + d + "\" is defined multiple times: " + dirs[d]

# Make sure that the pipelines are defined properly
for pipeline in pipelines:
    assert len(pipeline) == 4, "Pipeline declarations have four arguments (not " + len(pipeline) + ")"
    assert isinstance(pipeline[0], Pipeline), "The first argument of a pipeline declaration must be a pipeline instance"
    assert isinstance(pipeline[1], str), "The second argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[2], str), "The third argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[3], str), "The fourth argument of a pipeline declaration must be a string"
    assert pipeline[1] in dirs, "The second argument of a pipeline declaration (\"" + str(pipeline[1]) + "\") must refer to a key in \"dirs\""
    assert pipeline[2] in dirs, "The third argument of a pipeline declaration (\"" + str(pipeline[2]) + "\") must refer to a key in \"dirs\""
    assert pipeline[3] in dirs, "The fourth argument of a pipeline declaration (\"" + str(pipeline[2]) + "\") must refer to a key in \"dirs\""

# Make directories
for d in dirs:
    os.makedirs(dirs[d], exist_ok=True)

threads = []
for pipeline in pipelines:
    thread = Thread(target=pipeline[0].run, args=(1, dirs[pipeline[1]], dirs[pipeline[2]], dirs[pipeline[3]]))
    thread.setDaemon(True)
    thread.start()
    threads.append(thread)

try:
    running = True
    while running:
        time.sleep(1)
        for thread in threads:
            if not thread.isAlive():
                running = False
                break
        
except Exception as e:
    print(e)
    traceback.print_tb(e.__traceback__)
    
except KeyboardInterrupt:
    pass

for pipeline in pipelines:
    pipeline[0].stop(exit=True)

for thread in threads:
    thread.join()