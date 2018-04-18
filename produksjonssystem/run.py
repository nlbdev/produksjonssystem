#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import logging
from threading import Thread
from core.plotter import Plotter
from core.pipeline import Pipeline, DummyPipeline
from core.utils.slack import Slack
from email.headerregistry import Address

# Import pipelines
from nlbpub_to_pef import NlbpubToPef
from epub_to_dtbook import EpubToDtbook
from epub_to_dtbook_braille import EpubToDtbookBraille
from epub_to_dtbook_html import EpubToDtbookHTML
from nlbpub_to_html import NlbpubToHtml
from incoming_nordic import IncomingNordic
from insert_metadata import *
from update_metadata import UpdateMetadata
from nordic_to_nlbpub import NordicToNlbpub
from prepare_for_braille import PrepareForBraille
from nlbpub_to_narration_epub import NlbpubToNarrationEpub
from nlbpub_to_docx import NLBpubToDocx
from make_abstracts import Audio_Abstract

class Produksjonssystem():

    book_archive_dirs = None
    email = None
    dirs = None
    pipelines = None
    environment = None

    def __init__(self, environment=None):
        logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(levelname)-8s %(message)s")

        # Set environment variables (mainly useful when testing)
        if environment:
            assert isinstance(environment, dict)
            for name in environment:
                os.environ[name] = environment[name]
            self.environment = environment
        else:
            self.environment = {}
        Pipeline.environment = self.environment # Make environment available from pipelines

        # Check that archive dirs is defined
        assert os.environ.get("BOOK_ARCHIVE_DIRS"), "The book archives must be defined as a space separated list in the environment variable BOOK_ARCHIVE_DIRS (as name=path pairs)"
        self.book_archive_dirs = {}
        for d in os.environ.get("BOOK_ARCHIVE_DIRS").split(" "):
            assert "=" in d, "Book archives must be specified as name=path. For instance: master=/media/archive. Note that paths can not contain spaces."
            archive_name = d.split("=")[0]
            archive_path = os.path.normpath(d.split("=")[1]) + "/"
            self.book_archive_dirs[archive_name] = archive_path
        
        # for convenience; both method variable and instance variable so you don't have to
        # write "self." all the time during initialization.
        book_archive_dirs = self.book_archive_dirs

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
                "ammar":    Address("Ammar Usama",              "Ammar.Usama",       "nlb.no"),
                "anya":     Address("Anya Bauer-Hartmark",      "Anya.Hartmark",     "nlb.no"),
                "eivind":   Address("Eivind Haugen",            "Eivind.Haugen",     "nlb.no"),
                "elif":     Address("Eli Frisvold",             "eli.frisvold",      "nlb.no"),
                "elih":     Address("Eli Hafskjold",            "Eli.Hafskjold",     "nlb.no"),
                "espen":    Address("Espen Solhjem",            "Espen.Solhjem",     "nlb.no"),
                "hanne":    Address("Hanne Lillevold",          "hanne.lillevold",   "nlb.no"),
                "ingvilda": Address("Ingvild Aanensen",         "ingvild.aanensen",  "nlb.no"),
                "jostein":  Address("Jostein Austvik Jacobsen", "jostein",           "nlb.no"),
                "kariga":   Address("Kari Gjølstad Aas",        "kari.gjolstadaas",  "nlb.no"),
                "karik":    Address("Kari Kummeneje",           "Kari.Kummeneje",    "nlb.no"),
                "karir":    Address("Kari Rudjord",             "Kari.Rudjord",      "nlb.no"),
                "marim":    Address("Mari Myksvoll",            "Mari.Myksvoll",     "nlb.no"),
                "olav":     Address("Olav Indergaard",          "Olav.Indergaard",   "nlb.no"),
                "per":      Address("Per Sennels",              "Per.Sennels",       "nlb.no"),
                "roald":    Address("Roald Madland",            "Roald.Madland",     "nlb.no"),
                "sobia":    Address("Sobia Awan",               "Sobia.Awan",        "nlb.no"),
                "therese":  Address("Therese Solbjorg",         "therese.solbjorg",  "nlb.no"),
                "thomas":   Address("Thomas Tsigaridas",        "Thomas.Tsigaridas", "nlb.no"),
                "wenche":   Address("Wenche Andresen",          "wenche.andresen",   "nlb.no"),
            }
        }

        # Define directories
        self.dirs = {
            "reports": os.getenv("REPORTS_DIR", os.path.join(book_archive_dirs["master"], "rapporter")),
            "incoming": os.path.join(book_archive_dirs["master"], "innkommende"),
            "master": os.path.join(book_archive_dirs["master"], "master/EPUB"),
            "nlbpub": os.path.join(book_archive_dirs["master"], "master/NLBPUB"),
            "metadata": os.path.join(book_archive_dirs["master"], "metadata"),
            "dtbook_braille": os.path.join(book_archive_dirs["master"], "distribusjonsformater/DTBook-punktskrift"),
            "dtbook_tts": os.path.join(book_archive_dirs["master"], "distribusjonsformater/DTBook-til-talesyntese"),
            "dtbook_html": os.path.join(book_archive_dirs["master"], "distribusjonsformater/DTBook-til-HTML"),
            "html": os.path.join(book_archive_dirs["master"], "distribusjonsformater/HTML"),
            "docx": os.path.join(book_archive_dirs["master"], "distribusjonsformater/DOCX"),
            "epub_narration": os.path.join(book_archive_dirs["master"], "distribusjonsformater/EPUB-til-innlesing"),
            "ncc": os.path.join(book_archive_dirs["master"], "distribusjonsformater/NCC"),
            "pef": os.path.join(book_archive_dirs["master"], "distribusjonsformater/PEF"),
            "pub-ready-braille": os.path.join(book_archive_dirs["master"], "utgave-klargjort/punktskrift"),
            "pub-in-epub": os.path.join(book_archive_dirs["master"], "utgave-inn/EPUB"),
            "pub-in-audio": os.path.join(book_archive_dirs["master"], "utgave-inn/lydbok"),
            "pub-in-ebook": os.path.join(book_archive_dirs["master"], "utgave-inn/e-tekst"),
            "pub-in-braille": os.path.join(book_archive_dirs["master"], "utgave-inn/punktskrift"),
            "incoming_daisy": os.path.join(book_archive_dirs["share"], "daisy202"),
            "abstracts": os.path.join(book_archive_dirs["master"], "utgave-ut/baksidetekst")
        }

        # Define pipelines, input/output/report dirs, and email recipients
        self.pipelines = [
            # Mottak
            [ IncomingNordic(),                             "incoming",            "master",              "reports", ["ammar","jostein","marim","olav","sobia","thomas"]],
            [ NordicToNlbpub(),                             "master",              "nlbpub",              "reports", ["jostein","olav","per"]],
            [ UpdateMetadata(),                             "metadata",            "nlbpub",              "reports", ["jostein"],
                                                                                                                     {
                                                                                                                        "librarians": [
                                                                                                                            self.email["recipients"]["anya"],
                                                                                                                            self.email["recipients"]["elif"],
                                                                                                                            self.email["recipients"]["elih"],
                                                                                                                            self.email["recipients"]["hanne"],
                                                                                                                            self.email["recipients"]["ingvilda"],
                                                                                                                            self.email["recipients"]["kariga"],
                                                                                                                            self.email["recipients"]["karik"],
                                                                                                                            self.email["recipients"]["therese"],
                                                                                                                            self.email["recipients"]["wenche"],
                                                                                                                        ],
                                                                                                                        "default_librarian": self.email["recipients"]["elih"]
                                                                                                                     }],

            # EPUB
            [ InsertMetadataEpub(),                         "nlbpub",              "pub-in-epub",         "reports", ["jostein"]],

            # innlest lydbok
            [ InsertMetadataDaisy202(),                     "nlbpub",              "pub-in-audio",        "reports", ["jostein"]],
            [ NlbpubToNarrationEpub(),                      "pub-in-audio",        "epub_narration",      "reports", ["eivind","jostein","per"]],
            [ DummyPipeline("Innlesing med Hindenburg"),    "epub_narration",      None,                  "reports", ["jostein"]],

            # e-bok
            [ InsertMetadataXhtml(),                        "nlbpub",              "pub-in-ebook",        "reports", ["jostein"]],
            [ NlbpubToHtml(),                               "pub-in-ebook",        "html",                "reports", ["ammar","espen","jostein","olav"]],
            [ NLBpubToDocx(),                               "pub-in-ebook",        "docx",                "reports", ["espen","jostein"]],

            # punktskrift
            [ InsertMetadataBraille(),                      "nlbpub",              "pub-in-braille",      "reports", ["jostein"]],
            [ PrepareForBraille(),                          "pub-in-braille",      "pub-ready-braille",   "reports", ["ammar","jostein","karir"]],
            [ NlbpubToPef(),                                "pub-ready-braille",   "pef",                 "reports", ["ammar","jostein","karir"]],

            # TTS-lydbok
            [ EpubToDtbook(),                               "master",              "dtbook_tts",          "reports", ["ammar","jostein","marim","olav","sobia","thomas"]],
            [ DummyPipeline("Talesyntese i Pipeline 1"),    "dtbook_tts",          None,                  "reports", ["jostein"]],
            [ EpubToDtbookHTML(),                           "master",              "dtbook_html",         "reports", ["ammar","jostein","marim","olav","sobia","thomas"]],
            [ DummyPipeline("Pipeline 1 og Ammars skript"), "dtbook_html",         None,                  "reports", ["jostein"]],
            
            # DTBook for punktskrift
            [ EpubToDtbookBraille(),                        "master",              "dtbook_braille",      "reports", ["ammar","jostein","marim","olav","sobia","thomas"]],
            [ DummyPipeline("Punktskrift med NorBraille"),  "dtbook_braille",      None,                  "reports", ["jostein"]],

            # lydutdrag
            [ Audio_Abstract(),              "incoming_daisy",          "abstracts",        "reports", ["espen"]],
        ]


    # ---------------------------------------------------------------------------
    # Don't edit below this line if you only want to add/remove/modify a pipeline
    # ---------------------------------------------------------------------------

    def info(self, text):
        logging.info(text)
        Slack.slack(text, None)

    def run(self):
        try:
            self.info("Produksjonssystemet er startet")
            self._run()
        except Exception as e:
            self.info("En feil oppstod i produksjonssystemet: {}".format(str(e) if str(e) else "(ukjent)"))
        finally:
            self.info("Produksjonssystemet er stoppet")

    def _run(self):
        if "debug" in sys.argv:
            logging.getLogger().setLevel(logging.DEBUG)
        else:
            logging.getLogger().setLevel(logging.INFO)

        # Make sure that directories are defined properly
        for d in self.book_archive_dirs:
            for a in self.book_archive_dirs:
                if d == a:
                    continue
                d_norm = os.path.normpath(self.book_archive_dirs[d]) + "/"
                a_norm = os.path.normpath(self.book_archive_dirs[a]) + "/"
                assert not (a != d and a_norm == d_norm), "Two book archives must not be equal ({} == {})".format(self.book_archive_dirs[a], self.book_archive_dirs[d])
                assert not (a != d and a_norm.startswith(d_norm) or d_norm.startswith(a_norm)), "Book archives can not contain eachother ({} contains or is contained by {})".format(self.book_archive_dirs[a], self.book_archive_dirs[d])
        for d in self.dirs:
            self.dirs[d] = os.path.normpath(self.dirs[d])
        for d in self.dirs:
            if not d == "reports":
                assert [a for a in self.book_archive_dirs if self.dirs[d].startswith(self.book_archive_dirs[a])], "Directory \"" + d + "\" must be part of one of the book archives: " + self.dirs[d]
            assert not [a for a in self.book_archive_dirs if os.path.normpath(self.dirs[d]) == os.path.normpath(self.book_archive_dirs[a])], "The directory \"" + d + "\" must not be equal to any of the book archive dirs: " + self.dirs[d]
            assert len([x for x in self.dirs if self.dirs[x] == self.dirs[d]]), "The directory \"" + d + "\" is defined multiple times: " + self.dirs[d]

        # Make sure that the pipelines are defined properly
        for pipeline in self.pipelines:
            assert len(pipeline) == 5 or len(pipeline) == 6, "Pipeline declarations have five or six arguments (not " + len(pipeline) + ")"
            assert isinstance(pipeline[0], Pipeline), "The first argument of a pipeline declaration must be a pipeline instance"
            assert pipeline[1] == None or isinstance(pipeline[1], str), "The second argument of a pipeline declaration must be a string or None"
            assert pipeline[2] == None or isinstance(pipeline[2], str), "The third argument of a pipeline declaration must be a string or None"
            assert isinstance(pipeline[3], str), "The fourth argument of a pipeline declaration must be a string"
            assert isinstance(pipeline[4], list), "The fifth argument of a pipeline declaration must be a list"
            assert len(pipeline) <= 5 or isinstance(pipeline[5], dict), "The sixth argument of a pipelie, if present, must be a dict"
            assert pipeline[1] == None or pipeline[1] in self.dirs, "The second argument of a pipeline declaration (\"" + str(pipeline[1]) + "\") must be None or refer to a key in \"dirs\""
            assert pipeline[2] == None or pipeline[2] in self.dirs, "The third argument of a pipeline declaration (\"" + str(pipeline[2]) + "\") must be None or refer to a key in \"dirs\""
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
                                                          self.dirs[pipeline[1]] if pipeline[1] else None,
                                                          self.dirs[pipeline[2]] if pipeline[2] else None,
                                                          self.dirs[pipeline[3]],
                                                          email_settings,
                                                          self.book_archive_dirs,
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
                    self.info("Sender stoppsignal til alle pipelines...")
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

        self.info("Venter på at alle pipelinene skal stoppe...")
        for thread in threads:
            thread.join()

        self.info("Venter på at plotteren skal stoppe...")
        plotter.should_run = False
        graph_thread.join()

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
