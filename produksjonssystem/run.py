#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import yaml
import logging
import threading
import traceback
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

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class Produksjonssystem():

    book_archive_dirs = None
    email = None
    dirs = None
    pipelines = None
    environment = None
    emailDoc = []

    def __init__(self, environment=None):
        logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(levelname)-8s [%(threadName)-40s] %(message)s")

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
            "sender": Address("NLBs Produksjonssystem", "produksjonssystem", "nlb.no")
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
            "daisy202": os.path.join(book_archive_dirs["share"], "daisy202"),
            "abstracts": os.path.join(book_archive_dirs["master"], "utgave-ut/lydsnutter")
        }
        # Define pipelines and input/output/report dirs
        self.pipelines = [
            # Mottak
            [ IncomingNordic(retry=True),                   "incoming",            "master"],
            [ NordicToNlbpub(),                             "master",              "nlbpub"],
            [ UpdateMetadata(),                             "metadata",            "nlbpub"],

            # EPUB
            [ InsertMetadataEpub(),                         "nlbpub",              "pub-in-epub"],

            # e-bok
            [ InsertMetadataXhtml(),                        "nlbpub",              "pub-in-ebook"],
            [ NlbpubToHtml(),                               "pub-in-ebook",        "html"],
            [ NLBpubToDocx(),                               "pub-in-ebook",        "docx"],

            # punktskrift
            [ InsertMetadataBraille(),                      "nlbpub",              "pub-in-braille"],
            [ PrepareForBraille(),                          "pub-in-braille",      "pub-ready-braille"],
            [ NlbpubToPef(),                                "pub-ready-braille",   "pef"],

            # innlest lydbok
            [ InsertMetadataDaisy202(),                     "nlbpub",              "pub-in-audio"],
            [ NlbpubToNarrationEpub(),                      "pub-in-audio",        "epub_narration"],
            [ DummyPipeline("Innlesing med Hindenburg",
                            labels=["Lydbok","Innlesing"]),   "epub_narration",      "daisy202"],

            # TTS-lydbok
            [ EpubToDtbook(),                               "master",              "dtbook_tts"],
            [ DummyPipeline("Talesyntese i Pipeline 1",
                            labels=["Lydbok","Talesyntese"]), "dtbook_tts",          "daisy202"],

            # e-bok basert på DTBook
            [ EpubToDtbookHTML(),                           "master",              "dtbook_html"],
            [ DummyPipeline("Pipeline 1 og Ammars skript",
                            labels=["e-bok"]),                "dtbook_html",         None],

            # DTBook for punktskrift
            [ EpubToDtbookBraille(),                        "master",              "dtbook_braille"],
            [ DummyPipeline("Punktskrift med NorBraille",
                            labels=["Punktskrift"]),          "dtbook_braille",      None],

            # lydutdrag
            [ Audio_Abstract(),                             "daisy202",            "abstracts"],
        ]

    # ---------------------------------------------------------------------------
    # Don't edit below this line if you only want to add/remove/modify a pipeline
    # ---------------------------------------------------------------------------

    def info(self, text):
        logging.info(text)
        Slack.slack(text, None)

    def run(self):
        try:
            threading.main_thread().setName("main thread")
            self.info("Produksjonssystemet er startet")
            self._run()
        except Exception as e:
            self.info("En feil oppstod i produksjonssystemet: {}".format(str(e) if str(e) else "(ukjent)"))
            traceback.print_exc(e)
        finally:
            self.info("Produksjonssystemet er stoppet")

    def _run(self):
        assert os.getenv("CONFIG_FILE"), "CONFIG_FILE must be defined"

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
            assert len(pipeline) == 3, "Pipeline declarations have three arguments (not " + len(pipeline) + ")"
            assert isinstance(pipeline[0], Pipeline), "The first argument of a pipeline declaration must be a pipeline instance"
            assert pipeline[1] == None or isinstance(pipeline[1], str), "The second argument of a pipeline declaration must be a string or None"
            assert pipeline[2] == None or isinstance(pipeline[2], str), "The third argument of a pipeline declaration must be a string or None"
            assert pipeline[1] == None or pipeline[1] in self.dirs, "The second argument of a pipeline declaration (\"" + str(pipeline[1]) + "\") must be None or refer to a key in \"dirs\""
            assert pipeline[2] == None or pipeline[2] in self.dirs, "The third argument of a pipeline declaration (\"" + str(pipeline[2]) + "\") must be None or refer to a key in \"dirs\""

        # Make directories
        for d in self.dirs:
            os.makedirs(self.dirs[d], exist_ok=True)

        if os.environ.get("DEBUG", "1") == "1":
            time.sleep(1)
            logging.basicConfig(stream=sys.stdout, level=logging.DEBUG, format="%(asctime)s %(levelname)-8s [%(threadName)-40s] %(message)s")

        threads = []
        file_name=os.environ.get("CONFIG_FILE")
        emailDoc=""
        with open(file_name, 'r') as f:
                try:
                    emailDoc = yaml.load(f)
                except Exception as e:
                    self.info("En feil oppstod under lasting av konfigurasjonsfilen. Sjekk syntaksen til produksjonssystem.yaml")

        # Make pipelines available from static methods in the Pipeline class
        Pipeline.pipelines = [pipeline[0] for pipeline in self.pipelines]

        for pipeline in self.pipelines:
            email_settings = {
                "smtp": self.email["smtp"],
                "sender": self.email["sender"],
                "recipients": []
            }
            pipeline_config = {}
            if pipeline[0].uid in emailDoc:
                for recipient in emailDoc[pipeline[0].uid]:
                    if isinstance(recipient, str):
                        email_settings["recipients"].append(recipient)
                    elif isinstance(recipient, dict):
                        for key in recipient:
                            pipeline_config[key] = recipient[key]
            thread = Thread(target=pipeline[0].run, name=pipeline[0].title,
                                                    args=(10,
                                                          self.dirs[pipeline[1]] if pipeline[1] else None,
                                                          self.dirs[pipeline[2]] if pipeline[2] else None,
                                                          self.dirs["reports"],
                                                          email_settings,
                                                          self.book_archive_dirs,
                                                          pipeline_config
                                                          ))
            thread.setDaemon(True)
            thread.start()
            threads.append(thread)

        self.shouldRun=True
        self._configThread = Thread(target=self._config_thread)
        self._configThread.setDaemon(True)
        self._configThread.start()
        
        plotter = Plotter(self.pipelines, report_dir=self.dirs["reports"])
        graph_thread = Thread(target=plotter.run, name="graph")
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
            if thread:
                logging.debug("joining {}".format(thread.name))
            thread.join(timeout=5)
        
        is_alive = True
        while is_alive:
            is_alive = False
            for thread in threads:
                if thread and thread != threading.current_thread() and thread.is_alive():
                    is_alive = True
                    logging.info("Thread is still running: {}".format(thread.name))
                    thread.join(timeout=5)
            for pipeline in self.pipelines:
                if pipeline[0].running:
                    self.info("{} kjører fortsatt, venter på at den skal stoppe{}...".format(pipeline[0].title, " ({} / {})".format(pipeline[0].book["name"], pipeline[0].get_progress()) if pipeline[0].book else ""))
        
        self.info("Venter på at plotteren skal stoppe...")
        time.sleep(5) # gi plotteren litt tid på slutten
        plotter.should_run = False
        if graph_thread:
            logging.debug("joining {}".format(graph_thread.name))
        graph_thread.join()
        if graph_thread:
            logging.debug("joined {}".format(graph_thread.name))
        
        self.info("Venter på at konfigtråden skal stoppe...")
        self.shouldRun = False
        
        #self._configThread.join()
    
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
            f.write("stop")

    def _config_thread(self):
        fileName=os.environ.get("CONFIG_FILE")
        emailDoc=""
        while(self.shouldRun):
            time.sleep(300)
            try:
                with open(fileName, 'r') as f:
                    tempEmailDoc = yaml.load(f)
                if tempEmailDoc != emailDoc:
                    self.info("Oppdaterer konfig fra fil")
                    emailDoc = tempEmailDoc
                    for pipeline in self.pipelines:
                        recipients = []
                        pipeline_config = {}
                        if pipeline[0].uid in emailDoc and emailDoc[pipeline[0].uid]:
                            for recipient in emailDoc[pipeline[0].uid]:
                                if isinstance(recipient, str):
                                    recipients.append(recipient)
                                elif isinstance(recipient, dict):
                                    for key in recipient:
                                        pipeline_config[key] = recipient[key]
                        pipeline[0].email_settings["recipients"] = recipients
                        pipeline[0].config = pipeline_config
            except Exception as e:
                self.info("En feil oppstod under lasting av konfigurasjonsfil. Sjekk syntaksen til" + fileName)

if __name__ == "__main__":
    produksjonssystem = Produksjonssystem()
    produksjonssystem.run()
