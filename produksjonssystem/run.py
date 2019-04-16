#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import logging
import os
import sys
import threading
import time
import traceback
import yaml
import psutil
from collections import OrderedDict
from email.headerregistry import Address
from threading import Thread
from core.config import Config
from core.pipeline import DummyPipeline, Pipeline
from core.plotter import Plotter
from core.utils.slack import Slack
from core.utils.filesystem import Filesystem

# Import pipelines
from check_pef import CheckPef
from epub_to_dtbook_audio import EpubToDtbookAudio
from epub_to_dtbook_braille import EpubToDtbookBraille
from epub_to_dtbook_html import EpubToDtbookHTML
#from generate_resources import GenerateResources
from html_to_dtbook import HtmlToDtbook
from incoming_NLBPUB import (NLBPUB_incoming_validator,
                             NLBPUB_incoming_warning, NLBPUB_validator)
from incoming_nordic import IncomingNordic
from insert_metadata import (InsertMetadataBraille, InsertMetadataDaisy202,
                             InsertMetadataXhtml)
from make_abstracts import Audio_Abstract
from nlbpub_previous import NlbpubPrevious
from nlbpub_to_docx import NLBpubToDocx
from nlbpub_to_html import NlbpubToHtml
from nlbpub_to_narration_epub import NlbpubToNarrationEpub
from nlbpub_to_pef import NlbpubToPef
from nordic_dtbook_to_epub import NordicDTBookToEpub
from nordic_to_nlbpub import NordicToNlbpub
from prepare_for_braille import PrepareForBraille
from prepare_for_docx import PrepareForDocx
from prepare_for_ebook import PrepareForEbook
from update_metadata import UpdateMetadata
from newsletter import Newsletter

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Produksjonssystem():

    config = None
    pipelines = None

    def __init__(self, environment=None):
        self.config = Config()

        # Set environment variables (mainly useful when testing)
        if environment:
            assert isinstance(environment, dict)
            for name in environment:
                os.environ[name] = environment[name]
            environment = environment
        else:
            environment = {}

        # Check that archive dirs is defined
        book_archive_dirs = {}
        assert os.environ.get("BOOK_ARCHIVE_DIRS"), (
            "The book archives must be defined as a space separated list in the environment variable BOOK_ARCHIVE_DIRS (as name=path pairs)")
        book_archive_dirs = {}
        for d in os.environ.get("BOOK_ARCHIVE_DIRS").split(" "):
            assert "=" in d, "Book archives must be specified as name=path. For instance: master=/media/archive. Note that paths can not contain spaces."
            archive_name = d.split("=")[0]
            archive_path = os.path.normpath(d.split("=")[1]) + "/"
            book_archive_dirs[archive_name] = archive_path
        self.config.set("book_archive_dirs", book_archive_dirs)

        # Configure email
        email_smtp = {}
        if os.environ.get("MAIL_SERVER", None):
            email_smtp["host"] = os.environ.get("MAIL_SERVER", None)
        if os.environ.get("MAIL_PORT", None):
            email_smtp["port"] = os.environ.get("MAIL_PORT", None)
        if os.environ.get("MAIL_USERNAME", None):
            email_smtp["user"] = os.environ.get("MAIL_USERNAME", None)
        if os.environ.get("MAIL_PASSWORD", None):
            email_smtp["pass"] = os.environ.get("MAIL_PASSWORD", None)
        self.config.set("email.smtp", email_smtp)
        self.config.set("email.sender", ["NLBs Produksjonssystem", "produksjonssystem", "nlb.no"])

        # Special directories
        self.config.set("dir.master", os.path.join(book_archive_dirs["master"], "master/EPUB"))
        self.config.set("dir.reports", os.getenv("REPORTS_DIR", os.path.join(book_archive_dirs["master"], "rapporter")))
        self.config.set("dir.metadata", os.getenv("METADATA_DIR", os.path.join(book_archive_dirs["master"], "metadata")))

        # Define directories (using OrderedDicts to preserve order when plotting)
        dirs_ranked = []

        dirs_ranked.append({
            "id": "incoming",
            "name": "Mottak",
            "dirs": OrderedDict()
        })
        dirs_ranked[-1]["dirs"]["incoming_NLBPUB"] = os.path.join(book_archive_dirs["master"], "innkommende/NLBPUB")
        dirs_ranked[-1]["dirs"]["nlbpub_manuell"] = os.path.join(book_archive_dirs["master"], "mottakskontroll/NLBPUB")
        dirs_ranked[-1]["dirs"]["incoming"] = os.path.join(book_archive_dirs["master"], "innkommende/nordisk")

        dirs_ranked.append({
            "id": "source-in",
            "name": "Ubehandlet kildefil",
            "dirs": OrderedDict()
        })

        dirs_ranked.append({
            "id": "source-out",
            "name": "Behandlet kildefil",
            "dirs": OrderedDict()
        })

        dirs_ranked.append({
            "id": "master",
            "name": "Grunnlagsfil",
            "dirs": OrderedDict()
        })
        dirs_ranked[-1]["dirs"]["master"] = self.config.get("dir.master")
        dirs_ranked[-1]["dirs"]["metadata"] = self.config.get("dir.metadata")
        dirs_ranked[-1]["dirs"]["grunnlag"] = os.path.join(book_archive_dirs["master"], "grunnlagsfil/NLBPUB")
        dirs_ranked[-1]["dirs"]["nlbpub"] = os.path.join(book_archive_dirs["master"], "master/NLBPUB")
        dirs_ranked[-1]["dirs"]["old_dtbook"] = os.path.join(book_archive_dirs["master"], "grunnlagsfil/DTBook")
        dirs_ranked[-1]["dirs"]["epub_from_dtbook"] = os.path.join(book_archive_dirs["master"], "grunnlagsfil/EPUB-fra-DTBook")

        dirs_ranked.append({
            "id": "version-control",
            "name": "Versjonskontroll",
            "dirs": OrderedDict()
        })
        dirs_ranked[-1]["dirs"]["nlbpub-previous"] = os.path.join(book_archive_dirs["master"], "master/NLBPUB-tidligere")

        dirs_ranked.append({
                "id": "publication-in",
                "name": "Format-spesifikk metadata",
                "dirs": OrderedDict()
        })
        dirs_ranked[-1]["dirs"]["pub-in-epub"] = os.path.join(book_archive_dirs["master"], "utgave-inn/EPUB")
        dirs_ranked[-1]["dirs"]["pub-in-braille"] = os.path.join(book_archive_dirs["master"], "utgave-inn/punktskrift")
        dirs_ranked[-1]["dirs"]["pub-in-ebook"] = os.path.join(book_archive_dirs["master"], "utgave-inn/e-tekst")
        dirs_ranked[-1]["dirs"]["pub-in-audio"] = os.path.join(book_archive_dirs["master"], "utgave-inn/lydbok")

        dirs_ranked.append({
            "id": "publication-ready",
            "name": "Klar for produksjon",
            "dirs": OrderedDict()
        })
        dirs_ranked[-1]["dirs"]["dtbook"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DTBook")
        dirs_ranked[-1]["dirs"]["newsletter-in"] = os.path.join(book_archive_dirs["master"], "nyhetsbrev/inn")
        dirs_ranked[-1]["dirs"]["pub-ready-braille"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/punktskrift")
        dirs_ranked[-1]["dirs"]["pub-ready-ebook"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/e-bok")
        dirs_ranked[-1]["dirs"]["pub-ready-docx"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DOCX")
        dirs_ranked[-1]["dirs"]["epub_narration"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/EPUB-til-innlesing")
        dirs_ranked[-1]["dirs"]["dtbook_tts"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DTBook-til-talesyntese")
        dirs_ranked[-1]["dirs"]["dtbook_html"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DTBook-til-HTML")
        dirs_ranked[-1]["dirs"]["dtbook_braille"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DTBook-punktskrift")

        dirs_ranked.append({
            "id": "publication-out",
            "name": "Ferdig produsert",
            "dirs": OrderedDict()
        })
        dirs_ranked[-1]["dirs"]["pef"] = os.path.join(book_archive_dirs["master"], "utgave-ut/PEF")
        dirs_ranked[-1]["dirs"]["html"] = os.path.join(book_archive_dirs["master"], "utgave-ut/HTML")
        dirs_ranked[-1]["dirs"]["docx"] = os.path.join(book_archive_dirs["master"], "utgave-ut/DOCX")
        dirs_ranked[-1]["dirs"]["daisy202"] = os.path.join(book_archive_dirs["share"], "daisy202")

        dirs_ranked.append({
            "id": "distribution",
            "name": "Klar til distribusjon",
            "dirs": OrderedDict()
        })
        dirs_ranked[-1]["dirs"]["abstracts"] = os.path.join(book_archive_dirs["distribution"], "www/abstracts")
        dirs_ranked[-1]["dirs"]["pef-checked"] = os.path.join(book_archive_dirs["master"], "utgave-ut/PEF-kontrollert")

        # make dirs available from anywhere
        self.config.set("dirs_ranked", dirs_ranked)

        # Make a key/value version of dirs_ranked for convenience
        dirs = {
            "reports": self.config.get("dir.reports")
        }
        for rank in dirs_ranked:
            for dir in rank["dirs"]:
                dirs[dir] = rank["dirs"][dir]
        self.config.set("dir", dirs)

        # Define pipelines and input/output/report dirs
        self.pipelines = [
            # Konvertering av gamle DTBøker til EPUB 3
            [NordicDTBookToEpub(retry_missing=True),          "old_dtbook",          "epub_from_dtbook"],

            # Mottak, nordic guidelines 2015-1
            [NLBPUB_incoming_validator(retry_all=True,
                                       during_working_hours=True
                                       ),                     "incoming_NLBPUB",     "grunnlag"],
            [NLBPUB_incoming_warning(retry_all=True,
                                     during_working_hours=True
                                     ),                       "incoming_NLBPUB",     "nlbpub_manuell"],
            [DummyPipeline("Manuell sjekk av NLBPUB",
                           labels=["EPUB"]),                  "nlbpub_manuell",      "grunnlag"],
            # [NLBPUB_validator(overwrite=False),                              "grunnlag",            "nlbpub"],
            [IncomingNordic(retry_all=True,
                            during_working_hours=True),       "incoming",            "master"],
            [NordicToNlbpub(retry_missing=True,
                            overwrite=False),                 "master",              "nlbpub"],

            # Grunnlagsfiler
            [NlbpubPrevious(retry_missing=True),              "nlbpub",              "nlbpub-previous"],
            [UpdateMetadata(),                                "metadata",            "nlbpub"],
            [HtmlToDtbook(),                                  "nlbpub",              "dtbook"],

            # EPUB
            # [InsertMetadataEpub(),                            "nlbpub",              "pub-in-epub"],

            # e-bok
            [InsertMetadataXhtml(),                           "nlbpub",              "pub-in-ebook"],
            [PrepareForEbook(retry_missing=True),             "pub-in-ebook",        "pub-ready-ebook"],
            [PrepareForDocx(retry_missing=True),              "pub-in-ebook",        "pub-ready-docx"],
            [NlbpubToHtml(retry_missing=True),                "pub-ready-ebook",     "html"],
            [NLBpubToDocx(retry_missing=True),                "pub-ready-docx",      "docx"],
            [Newsletter(during_working_hours=True, during_night_and_weekend=True),   None,                    "pub-ready-braille"],

            # punktskrift
            [InsertMetadataBraille(),                         "nlbpub",              "pub-in-braille"],
            [PrepareForBraille(retry_missing=True),           "pub-in-braille",      "pub-ready-braille"],
            [NlbpubToPef(retry_missing=True),                 "pub-ready-braille",   "pef"],
            [CheckPef(),                                      "pef",                 "pef-checked"],

            # innlest lydbok
            [InsertMetadataDaisy202(),                        "nlbpub",              "pub-in-audio"],
            [NlbpubToNarrationEpub(retry_missing=True),       "pub-in-audio",        "epub_narration"],
            [DummyPipeline("Innlesing med Hindenburg",
                           labels=["Lydbok", "Statped"]),     "epub_narration",      "daisy202"],

            # TTS-lydbok
            [EpubToDtbookAudio(),                             "master",              "dtbook_tts"],
            [DummyPipeline("Talesyntese i Pipeline 1",
                           labels=["Lydbok"]),                "dtbook_tts",          "daisy202"],

            # e-bok basert på DTBook
            #[EpubToDtbookHTML(),                              "master",              "dtbook_html"],
            #[DummyPipeline("Pipeline 1 og Ammars skript",
            #               labels=["e-bok"]),                 "dtbook_html",         None],

            # DTBook for punktskrift
            #[EpubToDtbookBraille(),                           "master",              "dtbook_braille"],
            #[DummyPipeline("Punktskrift med NorBraille",
            #               labels=["Punktskrift"]),           "dtbook_braille",      None],

            # lydutdrag
            [Audio_Abstract(retry_missing=True),              "daisy202",            "abstracts"],
        ]

    # ---------------------------------------------------------------------------
    # Don't edit below this line if you only want to add/remove/modify a pipeline
    # ---------------------------------------------------------------------------

    def info(self, text):
        logging.info(text)
        Slack.slack(text, None)

    def run(self, debug=False):
        try:
            if debug:
                logging.getLogger().setLevel(logging.DEBUG)
            else:
                logging.getLogger().setLevel(logging.INFO)
            self.info("Starter produksjonssystemet...")
            self._run()
        except Exception as e:
            self.info("En feil oppstod i produksjonssystemet: {}".format(str(e) if str(e) else "(ukjent)"))
            logging.exception("En feil oppstod i produksjonssystemet")
        finally:
            self.info("Produksjonssystemet er stoppet")

    def _run(self):
        assert os.getenv("CONFIG_FILE"), "CONFIG_FILE must be defined"

        # Make sure that directories are defined properly
        for d in self.book_archive_dirs:
            for a in self.book_archive_dirs:
                if d == a:
                    continue
                d_norm = os.path.normpath(self.book_archive_dirs[d]) + "/"
                a_norm = os.path.normpath(self.book_archive_dirs[a]) + "/"
                assert not (a != d and a_norm == d_norm), "Two book archives must not be equal ({} == {})".format(
                    self.book_archive_dirs[a], self.book_archive_dirs[d])
                assert not (a != d and a_norm.startswith(d_norm) or d_norm.startswith(a_norm)), (
                    "Book archives can not contain eachother ({} contains or is contained by {})".format(self.book_archive_dirs[a], self.book_archive_dirs[d]))
        for d in self.dirs:
            self.dirs[d] = os.path.normpath(self.dirs[d])
        for d in self.dirs:
            if not d == "reports":
                assert [a for a in self.book_archive_dirs if self.dirs[d].startswith(self.book_archive_dirs[a])], (
                    "Directory \"" + d + "\" must be part of one of the book archives: " + self.dirs[d])
            assert not [a for a in self.book_archive_dirs if os.path.normpath(self.dirs[d]) == os.path.normpath(self.book_archive_dirs[a])], (
                "The directory \"" + d + "\" must not be equal to any of the book archive dirs: " + self.dirs[d])
            assert len([x for x in self.dirs if self.dirs[x] == self.dirs[d]]), "The directory \"" + d + "\" is defined multiple times: " + self.dirs[d]

        # Make sure that the pipelines are defined properly
        for pipeline in self.pipelines:
            assert len(pipeline) == 3, "Pipeline declarations have three arguments (not " + len(pipeline) + ")"
            assert isinstance(pipeline[0], Pipeline), "The first argument of a pipeline declaration must be a pipeline instance"
            assert pipeline[1] is None or isinstance(pipeline[1], str), "The second argument of a pipeline declaration must be a string or None"
            assert pipeline[2] is None or isinstance(pipeline[2], str), "The third argument of a pipeline declaration must be a string or None"
            assert pipeline[1] is None or pipeline[1] in self.dirs, (
                "The second argument of a pipeline declaration (\"" + str(pipeline[1]) + "\") must be None or refer to a key in \"dirs\"")
            assert pipeline[2] is None or pipeline[2] in self.dirs, (
                "The third argument of a pipeline declaration (\"" + str(pipeline[2]) + "\") must be None or refer to a key in \"dirs\"")

        # Some useful output to stdout before starting everything else
        print("")
        print("Dashboard: file://" + os.path.join(self.config.get("dir.reports"), "dashboard.html"))
        book_archive_dirs = self.config.get("book_archive_dirs")
        for d in book_archive_dirs:
            print("Book archive \"{}\": file://{}".format(d, book_archive_dirs[d]))
        print("")

        # Make directories
        for d in self.dirs:
            os.makedirs(self.dirs[d], exist_ok=True)

        threads = []
        file_name = os.environ.get("CONFIG_FILE")
        self.emailDoc = ""
        with open(file_name, 'r') as f:
                try:
                    self.emailDoc = yaml.load(f)
                except Exception as e:
                    self.info("En feil oppstod under lasting av konfigurasjonsfilen. Sjekk syntaksen til produksjonssystem.yaml")
                    traceback.print_exc(e)

        # Make pipelines available from static methods in the Pipeline class
        Pipeline.pipelines = [pipeline[0] for pipeline in self.pipelines]

        for common in self.emailDoc["common"]:
            for common_key in common:
                Config.set(common_key, common[common_key])

        for pipeline in self.pipelines:
            email_settings = {
                "smtp": self.email["smtp"],
                "sender": self.email["sender"],
                "recipients": []
            }
            pipeline_config = {}
            if pipeline[0].uid in self.emailDoc:
                for recipient in self.emailDoc[pipeline[0].uid]:
                    if isinstance(recipient, str):
                        email_settings["recipients"].append(recipient)
                    elif isinstance(recipient, dict):
                        for key in recipient:
                            pipeline_config[key] = recipient[key]

            thread = Thread(target=pipeline[0].run, name=pipeline[0].uid,
                            args=(10,
                                  self.dirs[pipeline[1]] if pipeline[1] else None,
                                  self.dirs[pipeline[2]] if pipeline[2] else None,
                                  self.dirs["reports"],
                                  email_settings,
                                  self.book_archive_dirs,
                                  pipeline_config
                                  ))

        self.config.set("system.shouldRun", True)
            thread.start()
            threads.append(thread)

        configProcess = BusProcess(target=self.config_process, name="config", daemon=True)
        self._configThread = Thread(target=self._config_thread, name="config")
        self._configThread.setDaemon(True)
        self._configThread.start()

        self._dailyReportThread = Thread(target=self._daily_report_thread, name="daily report")
        self._dailyReportThread.setDaemon(True)
        self._dailyReportThread.start()

        plotter = Plotter(self.pipelines, report_dir=self.dirs["reports"])
        graph_thread = Thread(target=plotter.run, name="graph")
        graph_thread.setDaemon(True)
        graph_thread.start()

        self.info("Produksjonssystemet er startet")

        last_thread_usage_log = time.time()
        system_process = psutil.Process()  # This process
        system_process.cpu_percent()  # first value returned is 0.0, which we ignore
        try:
            stopfile = os.getenv("TRIGGER_DIR")
            if stopfile:
                stopfile = os.path.join(stopfile, "stop")

            running = True
            while running:
                time.sleep(1)

                if os.path.exists(stopfile):
                    self.info("Sender stoppsignal til hele systemet...")
                    os.remove(stopfile)
                    self.config.set("system.shouldRun", False)
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

                if time.time() - last_thread_usage_log > 600:
                    last_thread_usage_log = time.time()
                    with system_process.oneshot():
                        self.info("Total memory usage: {:.1f} % ({:.3} MB)".format(system_process.memory_percent(memtype='uss'),
                                                                                   system_process.memory_full_info().uss / 1000000))
                        self.info("Total CPU usage: {:.1f} % ({} cores)".format(system_process.cpu_percent(), psutil.cpu_count()))
                        # TODO: find a way to log thread cpu usage

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
                    self.info("Thread is still running: {}".format(thread.name))
                    thread.join(timeout=5)
            for pipeline in self.pipelines:
                if pipeline[0].running:
                    self.info("{} kjører fortsatt, venter på at den skal stoppe{}...".format(
                        pipeline[0].title,
                        " ({} / {})".format(pipeline[0].book["name"], pipeline[0].get_progress()) if pipeline[0].book else ""))

        self.info("Venter på at plotteren skal stoppe...")
        time.sleep(5)  # gi plotteren litt tid på slutten
        self.config.set("plotter.shouldRun", False)
        if graph_thread:
            logging.debug("joining {}".format(graph_thread.name))
        graph_thread.join()
        if graph_thread:
            logging.debug("joined {}".format(graph_thread.name))

        self.info("Venter på at konfigtråden skal stoppe...")
        self.shouldRun = False
        self._configThread.join()
        self.info("Venter på at dagsrapport tråden skal stoppe...")
        self._dailyReportThread

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

    def _daily_report_thread(self):
        # Checks for reports in daily report dir for each pipeline. Only sends mail once each day after 7
        last_update = 0
        while self.shouldRun:
            if time.time() - last_update < 3600 or datetime.datetime.now().hour < 7:
                time.sleep(5)
                continue
            last_update = time.time()
            yesterday = datetime.datetime.now() - datetime.timedelta(1)
            yesterday = str(yesterday.strftime("%Y-%m-%d"))
            daily_dir = os.path.join(self.dirs["reports"], "logs", "dagsrapporter", yesterday)
            if not os.path.isdir(daily_dir):
                continue
            for pipeline in self.pipelines:
                if "dummy" in pipeline[0].uid:
                    continue
                if os.path.isfile(os.path.join(daily_dir, pipeline[0].uid + ".html")):
                    continue
                try:
                    number_produced = 0
                    number_failed = 0
                    file = os.path.join(daily_dir, pipeline[0].uid)
                    message = "<h1>Produsert i pipeline: " + pipeline[0].title + ": " + yesterday + "</h1>\n"
                    content = "\n<h2>Bøker som har gått gjennom:</h2>"
                    report_content = ""
                    dirs = []
                    if pipeline[0].dir_out:
                        dirs.append(pipeline[0].dir_out)
                    if pipeline[0].dir_in:
                        dirs.append(pipeline[0].dir_in)
                    dir_log = self.dirs["reports"]
                    logfile = os.path.join(pipeline[0].uid, "log.txt")
                    if (os.path.isfile(file + "-SUCCESS.txt")):
                        with open(file + "-SUCCESS.txt", "r") as report_file_success:
                            report_content = report_file_success.readlines()
                            content = content + self.format_email_report(report_content, dirs, dir_log, logfile, self.book_archive_dirs["master"])
                            for line in report_content:
                                if pipeline[0].title in line and line.startswith("["):
                                    number_produced += 1
                    else:
                        content = content + "\nIngen ble produsert\n"

                    content = content + "\n<h2>Bøker som har feilet:</h2>"
                    if (os.path.isfile(file + "-FAIL.txt")):
                        with open(file + "-FAIL.txt", "r") as report_file_fail:
                            report_content = report_file_fail.readlines()
                            content = content + self.format_email_report(report_content, dirs, dir_log, logfile, self.book_archive_dirs["master"])
                            for line in report_content:
                                if pipeline[0].title in line and line.startswith("["):
                                    number_failed += 1
                    else:
                        content = content + "\nIngen feilet\n"
                    message = message + "\n<h2>Totalt ble {} produsert og {} feilet</h2>\n".format(number_produced, number_failed)
                    message = message + content
                    pipeline[0].daily_report(message)
                except Exception:
                    self.info("En feil oppstod under sending av dagsrapporten for " + pipeline[0].title)
                    self.info(traceback.format_exc())

    def _config_thread(self):
        fileName = os.environ.get("CONFIG_FILE")
        last_update = 0
        while(self.shouldRun):

            if time.time() - last_update < 300:
                time.sleep(5)
                continue
            last_update = time.time()

            try:
                with open(fileName, 'r') as f:
                    tempEmailDoc = yaml.load(f)
                if tempEmailDoc != self.emailDoc:
                    self.info("Oppdaterer konfig fra fil")

                    try:
                        for tempkey in tempEmailDoc:
                            changes = self.find_diff(tempEmailDoc, self.emailDoc, tempkey)
                            if not changes == "":
                                self.info(changes)
                    except Exception:
                        pass

                    self.emailDoc = tempEmailDoc

                    for common in self.emailDoc["common"]:
                        for common_key in common:
                            Config.set(common_key, common[common_key])

                    for pipeline in self.pipelines:
                        if not pipeline[0].running:
                            continue

                        recipients = []
                        pipeline_config = {}

                        if pipeline[0].uid in self.emailDoc and self.emailDoc[pipeline[0].uid]:
                            for recipient in self.emailDoc[pipeline[0].uid]:
                                if isinstance(recipient, str):
                                    recipients.append(recipient)
                                elif isinstance(recipient, dict):
                                    for key in recipient:
                                        pipeline_config[key] = recipient[key]

                        pipeline[0].email_settings["recipients"] = recipients
                        pipeline[0].config = pipeline_config

            except Exception:
                self.info("En feil oppstod under lasting av konfigurasjonsfil. Sjekk syntaksen til" + fileName)
                self.info(traceback.format_exc())

    def find_diff(self, new_config, old_config, tempkey):
        for key_in_config in new_config[tempkey]:
            if isinstance(key_in_config, str):

                if len(new_config[tempkey]) > len(old_config[tempkey]):
                    delta = (yaml.dump(list(set(new_config[tempkey])-set(old_config[tempkey])), default_flow_style=False))
                    return ("Følgende mottakere ble lagt til i {} : \n{}" .format(tempkey, delta))

                if len(new_config[tempkey]) < len(old_config[tempkey]):
                    delta = (yaml.dump(list(set(old_config[tempkey])-set(new_config[tempkey])), default_flow_style=False))
                    return ("Følgende mottakere ble fjernet i {} : \n{}" .format(tempkey, delta))

            elif isinstance(key_in_config, dict):
                for i in range(0, len(new_config[tempkey])):
                    if isinstance(new_config[tempkey][i], dict):

                        for item in new_config[tempkey][i]:
                            tempset_new = set(new_config[tempkey][i][item])
                            tempset_old = set(old_config[tempkey][i][item])

                            if (len(tempset_new) > len(tempset_old)):
                                delta = (yaml.dump(list(tempset_new-tempset_old), default_flow_style=False))
                                return ("Følgende mottakere ble lagt til i {}: {} : \n{}" .format(tempkey, item, delta))

                            elif (len(tempset_new) < len(tempset_old)):
                                delta = (yaml.dump(list(tempset_old-tempset_new), default_flow_style=False))
                                return ("Følgende mottakere ble fjernet i {}: {} : \n{}" .format(tempkey, item, delta))
        return ""

    @staticmethod
    def format_email_report(content, dirs, dir_log, logfile, book_archive):
        # Formats the daily report message in html format for email. img_string penguin for linux

        img_string = ("<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAYCAYAAADzoH0MAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA"
                      "sTAAALEwEAmpwYAAAAB3RJTUUH4goFCTApeBNtqgAAA2pJREFUOMt1lF1rI2UYhu/JfCST6bRp2kyCjmWzG0wllV1SULTSyoLpcfHU5jyLP6IUQX+"
                      "DLqw/wBbPWiUeaLHBlijpiZbNR9PdDUPKSjL5mszX48Ha6U6HveGBeeGd67nf+3lnGCIi3FKv10e9/hQMw+Du3XuYn4/hjaJbqtVqtL29Tfn8KuXz"
                      "q1QsFqlardKb5AFs26ZyuUzZbJZUVSVFUUgQBBIEgTKZDB0cHJDjOEGAaZrU6XTo6OiICoUCqapKxWKRdnd3aXZ2liRJIkmSaHNzkzqdThDw5Mn3t"
                      "La2Rul0mmKxGOXzq3R4eEiNRoMWFxdJlmWSZZkymQxVKpUAgFtaUvH5w3t43jLx429jXF62sb+/j6urK9i2DZZlAQCu68IwjECG3MbGp7h//wFedp"
                      "9Bc77BTz+Xsbe3BwDeywAgCALC4XAAEGJZFgsLC3j3vQcoPfoSiqKAZdlADYdDnJ2dBQDszs7OzvVCVVXE4/MwXv4NnmMxI8/AcUOwbRuu60LXdWx"
                      "tbYHn+RsHPjuhEBJxEV9/McK3JQsPV+dfnZPjwHEczs/PUS7/4j/C64tut4uZyA9Y+sRG8kMWf/zjwLZthEIhhEIhWJaFx4+/84XpAWzbRvvyL7z/"
                      "cQvMOzKO2wq07r9e9+tqNpuo1WpBQK/XgyQ/gyh8BGADv/+agOu6gTBN00SlUrkZ4/WDruuIzX4ABp9hqA/R6XzlC+t1XVxcYDweIxqN3jgwTRMC/"
                      "xZc+22MR3GY5qvuHMdBEASfi36/j8lk4ncwnU7Bshwsy4JlWV76kiSB4zj0+33Pgeu6cBzHDyAiOI6N6ZQBy7KQJAk8zyORSMAwDIxGIw8giiI4jv"
                      "eH6LouRqMRDGMChmGQTqcRDoeRyWQQDofB87xX8Xgc0ajodyAIAgaDgdelUChA0zTkciuo1+vgOG8rUqkUIpGIHxCPx9FqtbyNc3NzKJVK0DQNROS"
                      "biKIkg2NMJpPQdR2NRhOpVNL7Eh3HgSAIPoBhTEBEYBjmBsCyLJaXlyHLMk5PTyGKIkRRRCQSgaIoGI/HHuD4+Bi5XA4rKytgbv+VNU1Dtfon6vWn"
                      "4Hked+6k0ev1cHJyghcvnnsjlmUZ6+vrQYDjOLAsC5OJAdd1EI1G/78nJtrtCzSaTQz0AVKpJLLZLP4DF17fodMaIVYAAAAASUVORK5CYII")
                      # + siste del: "=\" alt=\"DATA\">")

        message = ""
        first_dir_log = True
        for line in content:
            if "(li) " in line:
                line = line.replace("(li) ", "")
                message = message + "\n<ul>\n<li>" + line + "</li>\n</ul>"
            elif "(href) " in line:
                line = line.replace("(href) ", "")
                for dir in dirs:
                    dir_unc = Filesystem.networkpath(dir)[2]
                    if dir_unc in line:
                        split_href = line.split(", ")
                        if len(split_href) == 3:
                            smb_img_string = img_string + "=\" alt=\"{}\">".format(split_href[-1])
                            message = message + "\n<ul>\n<li><a href=\"file:///{}\">{}</a> {}</li>\n</ul>".format(split_href[1], split_href[0], smb_img_string)
                if logfile in line:
                    if first_dir_log:
                        split_href = line.split(", ")
                        smb_img_string = img_string + "=\" alt=\"{}\">".format(split_href[-1])
                        if len(split_href) == 3:
                            short_path = "log.txt"
                            message = message + "\n<ul>\n<li><a href=\"file:///{}\">{}</a> {}</li>\n</ul>".format(split_href[1], short_path, smb_img_string)
                            first_dir_log = False
            elif line != "":
                first_dir_log = True
                if "mail:" in line:
                    splitline = line.split("mail: ")
                    splitmail = splitline[-1].split(", ")
                    smb_img_string = img_string + "=\" alt=\"{}\">".format(splitmail[-1])
                    message = message + "\n<p><b>{}<a href=\"file:///{}\">Link</a> {}</b></p>".format(splitline[0], splitmail[0], smb_img_string)
                    continue
                elif "[" in line:
                    message = message + "\n" + "<p><b>" + line + "</b></p>"
        return message


if __name__ == "__main__":
    log_level = logging.INFO
    if "debug" in sys.argv or os.environ.get("DEBUG", "1") == "1":
        log_level = logging.DEBUG

    config = Config()
    config.set("logging.level", log_level)
    config.set("logging.format", "%(asctime)s %(levelname)-8s [%(processName)-25s] [%(threadName)-11s] %(message)s")
    Config.init_logging(config)
    threading.current_thread().setName("main thread")

    produksjonssystem = Produksjonssystem()
    produksjonssystem.run()
