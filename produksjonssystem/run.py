#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import logging
from threading import Thread
from core.pipeline import Pipeline
from core.plotter import Plotter
from email.headerregistry import Address

# Import pipelines
from incoming_nordic import IncomingNordic
from nordic_to_nlbpub import NordicToNlbpub
from update_metadata import UpdateMetadata
from epub_to_html import EpubToHtml
from epub_to_dtbook import EpubToDtbook
from epub_to_pef import EpubToPef

# Check that archive dir is defined
assert os.environ.get("BOOK_ARCHIVE_DIR")
book_archive_dir = str(os.path.normpath(os.environ.get("BOOK_ARCHIVE_DIR")))

# Configure email
email = {
    "smtp": {
        "host": os.getenv("MAIL_SERVER"),
        "port": os.getenv("MAIL_PORT"),
        "user": os.getenv("MAIL_USERNAME"),
        "pass": os.getenv("MAIL_PASSWORD")
    },
    "sender": Address("NLBs Produksjonssystem", "jostein", "nlb.no"),
    "recipients": {
        "ammar":   Address("Ammar Usama",              "Ammar.Usama",       "nlb.no"),
        "jostein": Address("Jostein Austvik Jacobsen", "jostein",           "nlb.no"),
        "kari":    Address("Kari Rudjord",             "Kari.Rudjord",      "nlb.no"),
        "mari":    Address("Mari Myksvoll",            "Mari.Myksvoll",     "nlb.no"),
        "olav":    Address("Olav Indergaard",          "Olav.Indergaard",   "nlb.no"),
        "sobia":   Address("Sobia Awan",               "Sobia.Awan",        "nlb.no"),
        "thomas":  Address("Thomas Tsigaridas",        "Thomas.Tsigaridas", "nlb.no"),
    }
}

# Define directories
dirs = {
    "reports": os.path.join(book_archive_dir, "rapporter"),
    "incoming": os.path.join(book_archive_dir, "innkommende"),
    "master": os.path.join(book_archive_dir, "master/EPUB"),
    "nlbpub": os.path.join(book_archive_dir, "master/NLBPUB"),
    "metadata": os.path.join(book_archive_dir, "metadata"),
    "dtbook": os.path.join(book_archive_dir, "distribusjonsformater/DTBook"),
    "html": os.path.join(book_archive_dir, "distribusjonsformater/HTML"),
    "html_narration": os.path.join(book_archive_dir, "distribusjonsformater/HTML-til-innlesing"),
    "ncc": os.path.join(book_archive_dir, "distribusjonsformater/NCC"),
    "pef": os.path.join(book_archive_dir, "distribusjonsformater/PEF"),
}

# Define pipelines, input/output/report dirs, and email recipients
pipelines = [
    [ IncomingNordic(),  "incoming", "master", "reports", ["ammar","jostein","mari","olav","sobia","thomas"]],
    [ NordicToNlbpub(),  "master",   "nlbpub", "reports", ["ammar","jostein","olav"]],
    [ EpubToHtml(),      "master",   "html",   "reports", ["ammar","jostein","olav"]],
    [ EpubToDtbook(),    "master",   "dtbook", "reports", ["ammar","jostein","mari","olav"]],
    [ EpubToPef(),       "master",   "pef",    "reports", ["ammar","jostein","kari"]]
]


# ---------------------------------------------------------------------------
# Don't edit below this line if you only want to add/remove/modify a pipeline
# ---------------------------------------------------------------------------

if len(sys.argv) > 1 and sys.argv[1].lower() == "debug":
    logging.getLogger().setLevel(logging.DEBUG)
else:
    logging.getLogger().setLevel(logging.INFO)

# Make sure that directories are defined properly
for d in dirs:
    dirs[d] = os.path.normpath(dirs[d])
for d in dirs:
    assert dirs[d].startswith(book_archive_dir + "/"), "Directory \"" + d + "\" must be part of the book archive: " + dirs[d]
    assert len(dirs[d]) > len(book_archive_dir) + 1, "The directory \"" + d + "\" must not be equal to the book archive dir: " + dirs[d]
    assert len([x for x in dirs if dirs[x] == dirs[d]]), "The directory \"" + d + "\" is defined multiple times: " + dirs[d]

# Make sure that the pipelines are defined properly
for pipeline in pipelines:
    assert len(pipeline) == 5, "Pipeline declarations have four arguments (not " + len(pipeline) + ")"
    assert isinstance(pipeline[0], Pipeline), "The first argument of a pipeline declaration must be a pipeline instance"
    assert isinstance(pipeline[1], str), "The second argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[2], str), "The third argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[3], str), "The fourth argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[4], list), "The fifth argument of a pipeline declaration must be a list"
    assert pipeline[1] in dirs, "The second argument of a pipeline declaration (\"" + str(pipeline[1]) + "\") must refer to a key in \"dirs\""
    assert pipeline[2] in dirs, "The third argument of a pipeline declaration (\"" + str(pipeline[2]) + "\") must refer to a key in \"dirs\""
    assert pipeline[3] in dirs, "The fourth argument of a pipeline declaration (\"" + str(pipeline[3]) + "\") must refer to a key in \"dirs\""
    for recipient in pipeline[4]:
        assert recipient in email["recipients"], "All list items in the fifth argument of a pipeline declaration (\"" + str(pipeline[4]) + "\") must refer to a key in \"email['recipients']\""

# Make directories
for d in dirs:
    os.makedirs(dirs[d], exist_ok=True)

if os.environ.get("DEBUG", "1") == "1":
    time.sleep(1)
    logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

threads = []
for pipeline in pipelines:
    email_settings = {
        "smtp": email["smtp"],
        "sender": email["sender"],
        "recipients": []
    }
    for s in pipeline[4]:
        email_settings["recipients"].append(email["recipients"][s])
    thread = Thread(target=pipeline[0].run, args=(10, dirs[pipeline[1]], dirs[pipeline[2]], dirs[pipeline[3]], email_settings, book_archive_dir))
    thread.setDaemon(True)
    thread.start()
    threads.append(thread)

plotter = Plotter(pipelines, report_dir=dirs["reports"])
graph_thread = Thread(target=plotter.run)
graph_thread.setDaemon(True)
graph_thread.start()

try:
    running = True
    while running:
        time.sleep(1)
        for thread in threads:
            if not thread.isAlive():
                running = False
                break
    
except KeyboardInterrupt:
    pass

for pipeline in pipelines:
    pipeline[0].stop(exit=True)
    plotter.should_run = False

graph_thread.join()
for thread in threads:
    thread.join()
