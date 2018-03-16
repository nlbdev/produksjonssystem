#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import logging
from threading import Thread
from core.plotter import Plotter
from core.pipeline import Pipeline, DummyPipeline
from email.headerregistry import Address

# Import pipelines
from dtbook_to_tts import DtbookToTts
from nlbpub_to_pef import NlbpubToPef
from epub_to_dtbook import EpubToDtbook
from nlbpub_to_html import NlbpubToHtml
from incoming_nordic import IncomingNordic
from insert_metadata import *
from update_metadata import UpdateMetadata
from nordic_to_nlbpub import NordicToNlbpub
from nlbpub_to_narration_epub import NlbpubToNarrationEpub

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
    "sender": Address("NLBs Produksjonssystem", "produksjonssystem", "nlb.no"),
    "recipients": {
        "ammar":   Address("Ammar Usama",              "Ammar.Usama",       "nlb.no"),
        "eivind":  Address("Eivind Haugen",            "Eivind.Haugen",     "nlb.no"),
        "elih":    Address("Eli Hafskjold",            "Eli.Hafskjold",     "nlb.no"),
        "jostein": Address("Jostein Austvik Jacobsen", "jostein",           "nlb.no"),
        "kari":    Address("Kari Rudjord",             "Kari.Rudjord",      "nlb.no"),
        "karik":   Address("Kari Kummeneje",           "Kari.Kummeneje",    "nlb.no"),
        "mari":    Address("Mari Myksvoll",            "Mari.Myksvoll",     "nlb.no"),
        "olav":    Address("Olav Indergaard",          "Olav.Indergaard",   "nlb.no"),
        "per":     Address("Per Sennels",              "Per.Sennels",       "nlb.no"),
        "roald":   Address("Roald Madland",            "Roald.Madland",     "nlb.no"),
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
    "dtbook_tts": os.path.join(book_archive_dir, "distribusjonsformater/DTBook-til-talesyntese"),
    "html": os.path.join(book_archive_dir, "distribusjonsformater/HTML"),
    "epub_narration": os.path.join(book_archive_dir, "distribusjonsformater/EPUB-til-innlesing"),
    "epub_narrated": os.path.join(book_archive_dir, "utgave-ut/EPUB-innlest"),
    "ncc": os.path.join(book_archive_dir, "distribusjonsformater/NCC"),
    "pef": os.path.join(book_archive_dir, "distribusjonsformater/PEF"),
    "pub-in-epub": os.path.join(book_archive_dir, "utgave-inn/EPUB"),
    "pub-in-audio": os.path.join(book_archive_dir, "utgave-inn/lydbok"),
    "pub-in-ebook": os.path.join(book_archive_dir, "utgave-inn/e-tekst"),
    "pub-in-braille": os.path.join(book_archive_dir, "utgave-inn/punktskrift"),
}

# Define pipelines, input/output/report dirs, and email recipients
pipelines = [
    [ IncomingNordic(),                             "incoming",            "master",              "reports", ["ammar","jostein","mari","olav","sobia","thomas"]],
    [ NordicToNlbpub(),                             "master",              "nlbpub",              "reports", ["jostein","olav","per"]],
    [ UpdateMetadata(),                             "metadata",            "nlbpub",              "reports", ["jostein"], { "librarians": [email["recipients"]["elih"], email["recipients"]["jostein"], email["recipients"]["karik"], email["recipients"]["per"]] }],
    [ InsertMetadataEpub(),                         "nlbpub",              "pub-in-epub",         "reports", ["jostein"]],
    [ InsertMetadataDaisy202(),                     "nlbpub",              "pub-in-audio",        "reports", ["jostein"]],
    [ NlbpubToNarrationEpub(),                      "pub-in-audio",        "epub_narration",      "reports", ["eivind","jostein","per"]],
    [ DummyPipeline("Innlesing"),                   "epub_narration",      "epub_narrated",       "reports", ["jostein"]],
    [ InsertMetadataXhtml(),                        "nlbpub",              "pub-in-ebook",        "reports", ["jostein"]],
    [ NlbpubToHtml(),                               "pub-in-ebook",        "html",                "reports", ["ammar","jostein","olav"]],
    [ InsertMetadataBraille(),                      "nlbpub",              "pub-in-braille",      "reports", ["jostein"]],
    [ NlbpubToPef(),                                "pub-in-braille",      "pef",                 "reports", ["ammar","jostein","kari"]],
    [ EpubToDtbook(),                               "master",              "dtbook",              "reports", ["ammar","jostein","mari","olav"]],
    [ DtbookToTts(),                                "dtbook",              "dtbook_tts",          "reports", ["ammar","jostein","mari","olav"]],
]


# ---------------------------------------------------------------------------
# Don't edit below this line if you only want to add/remove/modify a pipeline
# ---------------------------------------------------------------------------

if "debug" in sys.argv:
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
    assert len(pipeline) == 5 or len(pipeline) == 6, "Pipeline declarations have five or six arguments (not " + len(pipeline) + ")"
    assert isinstance(pipeline[0], Pipeline), "The first argument of a pipeline declaration must be a pipeline instance"
    assert isinstance(pipeline[1], str), "The second argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[2], str), "The third argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[3], str), "The fourth argument of a pipeline declaration must be a string"
    assert isinstance(pipeline[4], list), "The fifth argument of a pipeline declaration must be a list"
    assert len(pipeline) <= 5 or isinstance(pipeline[5], dict), "The sixth argument of a pipelie, if present, must be a dict"
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
    thread = Thread(target=pipeline[0].run, args=(10,
                                                  dirs[pipeline[1]],
                                                  dirs[pipeline[2]],
                                                  dirs[pipeline[3]],
                                                  email_settings,
                                                  book_archive_dir,
                                                  pipeline[5] if len(pipeline) >= 6 else None
                                                 ))
    thread.setDaemon(True)
    thread.start()
    threads.append(thread)

plotter = Plotter(pipelines, report_dir=dirs["reports"])
graph_thread = Thread(target=plotter.run)
graph_thread.setDaemon(True)
graph_thread.start()

try:
    triggerdir = os.getenv("TRIGGER_DIR")
    stopfile = os.path.join(triggerdir, "stop") if triggerdir else None
    
    running = True
    while running:
        time.sleep(1)
        
        if os.path.exists(stopfile):
            os.remove(stopfile)
            for pipeline in pipelines:
                pipeline[0].stop(exit=True)
        
        for thread in threads:
            if not thread.isAlive():
                running = False
                break
        
        # trigger all pipelines that uses the "master" directory as input
        triggerfiles = os.listdir(triggerdir)
        for triggerfile in triggerfiles:
            triggerfilepath = os.path.join(triggerdir, triggerfile)
            if os.path.isfile(triggerfilepath):
                os.remove(triggerfilepath)
                for pipeline in pipelines:
                    if pipeline[1] == "master":
                        pipelinetriggerfile = os.path.join(triggerdir, pipeline[0].uid, triggerfile)
                        with open(pipelinetriggerfile, 'a'):
                            os.utime(pipelinetriggerfile, None)
    
except KeyboardInterrupt:
    pass

for pipeline in pipelines:
    pipeline[0].stop(exit=True)

for thread in threads:
    thread.join()

plotter.should_run = False
time.sleep(1.5) # give plotter time for one last plot
graph_thread.join()
