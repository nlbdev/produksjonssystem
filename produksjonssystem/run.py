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
from prepare_for_braille import PrepareForBraille
from nlbpub_to_narration_epub import NlbpubToNarrationEpub
from nlbpub_to_docx import NLBpubToDocx

class Produksjonssystem():
    
    book_archive_dir = None
    email = None
    dirs = None
    pipelines = None
    environment = None
    
    def __init__(self, environment=None):
        
        # Set environment variables (mainly useful when testing)
        if environment:
            assert isinstance(environment, dict)
            for name in environment:
                os.environ[name] = environment[name]
            self.environment = environment
        else:
            self.environment = {}
        Pipeline.environment = self.environment # Make environment available from pipelines
        
        # Check that archive dir is defined
        assert os.environ.get("BOOK_ARCHIVE_DIR")
        book_archive_dir = str(os.path.normpath(os.environ.get("BOOK_ARCHIVE_DIR")))
        self.book_archive_dir = book_archive_dir # for convenience; both method variable and instance variable
        
        # Configure email
        self.email = {
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
                "espen":   Address("Espen Solhjem",            "Espen.Solhjem",     "nlb.no"),
                "jostein": Address("Jostein Austvik Jacobsen", "jostein",           "nlb.no"),
                "kari":    Address("Kari Rudjord",             "Kari.Rudjord",      "nlb.no"),
                "karik":   Address("Kari Kummeneje",           "Kari.Kummeneje",    "nlb.no"),
                "mari":    Address("Mari Myksvoll",            "Mari.Myksvoll",     "nlb.no"),
                "olav":    Address("Olav Indergaard",          "Olav.Indergaard",   "nlb.no"),
                "per":     Address("Per Sennels",              "Per.Sennels",       "nlb.no"),
                "roald":   Address("Roald Madland",            "Roald.Madland",     "nlb.no"),
                "sobia":   Address("Sobia Awan",               "Sobia.Awan",        "nlb.no"),
                "thomas":  Address("Thomas Tsigaridas",        "Thomas.Tsigaridas", "nlb.no"),
                "wenche":  Address("Wenche Andresen",          "wenche.andresen",   "nlb.no"),
            }
        }
        
        # Define directories
        self.dirs = {
            "reports": os.getenv("REPORTS_DIR", os.path.join(book_archive_dir, "rapporter")),
            "incoming": os.path.join(book_archive_dir, "innkommende"),
            "master": os.path.join(book_archive_dir, "master/EPUB"),
            "nlbpub": os.path.join(book_archive_dir, "master/NLBPUB"),
            "metadata": os.path.join(book_archive_dir, "metadata"),
            "dtbook": os.path.join(book_archive_dir, "distribusjonsformater/DTBook"),
            "dtbook_tts": os.path.join(book_archive_dir, "distribusjonsformater/DTBook-til-talesyntese"),
            "daisy202_tts": os.path.join(book_archive_dir, "utgave-ut/DAISY202-fra-talesyntese"),
            "html": os.path.join(book_archive_dir, "distribusjonsformater/HTML"),
            "docx": os.path.join(book_archive_dir, "distribusjonsformater/DOCX"),
            "epub_narration": os.path.join(book_archive_dir, "distribusjonsformater/EPUB-til-innlesing"),
            "epub_narrated": os.path.join(book_archive_dir, "utgave-ut/EPUB-innlest"),
            "ncc": os.path.join(book_archive_dir, "distribusjonsformater/NCC"),
            "pef": os.path.join(book_archive_dir, "distribusjonsformater/PEF"),
            "pub-ready-braille": os.path.join(book_archive_dir, "utgave-klargjort/punktskrift"),
            "pub-in-epub": os.path.join(book_archive_dir, "utgave-inn/EPUB"),
            "pub-in-audio": os.path.join(book_archive_dir, "utgave-inn/lydbok"),
            "pub-in-ebook": os.path.join(book_archive_dir, "utgave-inn/e-tekst"),
            "pub-in-braille": os.path.join(book_archive_dir, "utgave-inn/punktskrift"),
        }
        
        # Define pipelines, input/output/report dirs, and email recipients
        self.pipelines = [
            # Mottak
            [ IncomingNordic(),                             "incoming",            "master",              "reports", ["ammar","jostein","mari","olav","sobia","thomas"]],
            [ NordicToNlbpub(),                             "master",              "nlbpub",              "reports", ["jostein","olav","per"]],
            [ UpdateMetadata(),                             "metadata",            "nlbpub",              "reports", ["jostein"],
                                                                                                                     { "librarians": [
                                                                                                                        self.email["recipients"]["elih"],
                                                                                                                        self.email["recipients"]["jostein"],
                                                                                                                        self.email["recipients"]["karik"],
                                                                                                                        self.email["recipients"]["per"],
                                                                                                                        self.email["recipients"]["wenche"]
                                                                                                                     ]}],
            
            # EPUB
            [ InsertMetadataEpub(),                         "nlbpub",              "pub-in-epub",         "reports", ["jostein"]],
            
            # innlest lydbok
            [ InsertMetadataDaisy202(),                     "nlbpub",              "pub-in-audio",        "reports", ["jostein"]],
            [ NlbpubToNarrationEpub(),                      "pub-in-audio",        "epub_narration",      "reports", ["eivind","jostein","per"]],
            [ DummyPipeline("Innlesing"),                   "epub_narration",      "epub_narrated",       "reports", ["jostein"]],
            
            # e-bok
            [ InsertMetadataXhtml(),                        "nlbpub",              "pub-in-ebook",        "reports", ["jostein"]],
            [ NlbpubToHtml(),                               "pub-in-ebook",        "html",                "reports", ["ammar","espen","jostein","olav"]],
            [ NLBpubToDocx(),                               "pub-in-ebook",        "docx",                "reports", ["espen","jostein"]],
            
            # punktskrift
            [ InsertMetadataBraille(),                      "nlbpub",              "pub-in-braille",      "reports", ["jostein"]],
            [ PrepareForBraille(),                          "pub-in-braille",      "pub-ready-braille",   "reports", ["ammar","jostein","kari"]],
            [ NlbpubToPef(),                                "pub-ready-braille",   "pef",                 "reports", ["ammar","jostein","kari"]],
            
            # TTS-lydbok
            [ EpubToDtbook(),                               "master",              "dtbook",              "reports", ["ammar","jostein","mari","olav"]],
            [ DtbookToTts(),                                "dtbook",              "dtbook_tts",          "reports", ["ammar","jostein","mari","olav"]],
            [ DummyPipeline("TTS-produksjon"),              "dtbook_tts",          "daisy202_tts",        "reports", ["jostein"]],
        ]
    
    
    # ---------------------------------------------------------------------------
    # Don't edit below this line if you only want to add/remove/modify a pipeline
    # ---------------------------------------------------------------------------
    
    def run(self):
        if "debug" in sys.argv:
            logging.getLogger().setLevel(logging.DEBUG)
        else:
            logging.getLogger().setLevel(logging.INFO)
        
        # Make sure that directories are defined properly
        for d in self.dirs:
            self.dirs[d] = os.path.normpath(self.dirs[d])
        for d in self.dirs:
            if not d == "reports":
                assert self.dirs[d].startswith(self.book_archive_dir + "/"), "Directory \"" + d + "\" must be part of the book archive: " + self.dirs[d]
            assert os.path.normpath(self.dirs[d]) != os.path.normpath(self.book_archive_dir), "The directory \"" + d + "\" must not be equal to the book archive dir: " + self.dirs[d]
            assert len([x for x in self.dirs if self.dirs[x] == self.dirs[d]]), "The directory \"" + d + "\" is defined multiple times: " + self.dirs[d]
        
        # Make sure that the pipelines are defined properly
        for pipeline in self.pipelines:
            assert len(pipeline) == 5 or len(pipeline) == 6, "Pipeline declarations have five or six arguments (not " + len(pipeline) + ")"
            assert isinstance(pipeline[0], Pipeline), "The first argument of a pipeline declaration must be a pipeline instance"
            assert isinstance(pipeline[1], str), "The second argument of a pipeline declaration must be a string"
            assert isinstance(pipeline[2], str), "The third argument of a pipeline declaration must be a string"
            assert isinstance(pipeline[3], str), "The fourth argument of a pipeline declaration must be a string"
            assert isinstance(pipeline[4], list), "The fifth argument of a pipeline declaration must be a list"
            assert len(pipeline) <= 5 or isinstance(pipeline[5], dict), "The sixth argument of a pipelie, if present, must be a dict"
            assert pipeline[1] in self.dirs, "The second argument of a pipeline declaration (\"" + str(pipeline[1]) + "\") must refer to a key in \"dirs\""
            assert pipeline[2] in self.dirs, "The third argument of a pipeline declaration (\"" + str(pipeline[2]) + "\") must refer to a key in \"dirs\""
            assert pipeline[3] in self.dirs, "The fourth argument of a pipeline declaration (\"" + str(pipeline[3]) + "\") must refer to a key in \"dirs\""
            for recipient in pipeline[4]:
                assert recipient in self.email["recipients"], "All list items in the fifth argument of a pipeline declaration (\"" + str(pipeline[4]) + "\") must refer to a key in \"email['recipients']\""
        
        # Make directories
        for d in self.dirs:
            os.makedirs(self.dirs[d], exist_ok=True)
        
        if os.environ.get("DEBUG", "1") == "1":
            time.sleep(1)
            logging.basicConfig(stream=sys.stdout, level=logging.DEBUG, format="%(asctime)s %(levelname)-8s %(message)s")
        
        threads = []
        for pipeline in self.pipelines:
            email_settings = {
                "smtp": self.email["smtp"],
                "sender": self.email["sender"],
                "recipients": []
            }
            for s in pipeline[4]:
                email_settings["recipients"].append(self.email["recipients"][s])
            thread = Thread(target=pipeline[0].run, args=(10,
                                                          self.dirs[pipeline[1]],
                                                          self.dirs[pipeline[2]],
                                                          self.dirs[pipeline[3]],
                                                          email_settings,
                                                          self.book_archive_dir,
                                                          pipeline[5] if len(pipeline) >= 6 else {}
                                                         ))
            thread.setDaemon(True)
            thread.start()
            threads.append(thread)
        
        plotter = Plotter(self.pipelines, report_dir=self.dirs["reports"])
        graph_thread = Thread(target=plotter.run)
        graph_thread.setDaemon(True)
        graph_thread.start()
        
        try:
            stopfile = os.getenv("TRIGGER_DIR")
            if stopfile:
                stopfile = os.path.join(stopfile, "stop")
            
            running = True
            while running:
                time.sleep(1)
                
                if os.path.exists(stopfile):
                    os.remove(stopfile)
                    for pipeline in self.pipelines:
                        pipeline[0].stop(exit=True)
                
                if os.getenv("STOP_AFTER_FIRST_JOB", False):
                    running = 0
                    for pipeline in self.pipelines:
                        if pipeline[0].running:
                            running += 1
                    running = True if running > 0 else False
                else:
                    for thread in threads:
                        if not thread.isAlive():
                            running = False
                            break
        
        except KeyboardInterrupt:
            pass
        
        for pipeline in self.pipelines:
            pipeline[0].stop(exit=True)
            plotter.should_run = False
        
        graph_thread.join()
        for thread in threads:
            thread.join()
    
    def wait_until_running(self, timeout=60):
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            waiting = 0
            for pipeline in self.pipelines:
                if pipeline[0]._shouldRun and not pipeline[0].running:
                    waiting += 1
            if waiting == 0:
                return True
        
        return False
    
    def stop(self):
        stopfile = os.getenv("TRIGGER_DIR")
        assert stopfile, "TRIGGER_DIR must be defined"
        stopfile = os.path.join(stopfile, "stop")
        with open(stopfile, "w") as f:
            print("stop", file=f)

if __name__ == "__main__":
    produksjonssystem = Produksjonssystem()
    produksjonssystem.run()
