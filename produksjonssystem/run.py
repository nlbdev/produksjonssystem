#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
from logging.handlers import TimedRotatingFileHandler
import os
import sys

import datetime  # noqa
import threading  # noqa
import time  # noqa
import traceback  # noqa
from collections import OrderedDict  # noqa
from threading import Thread  # noqa

import psutil  # noqa
import pybrake  # noqa
import yaml  # noqa

import core.endpoints.creativeWorks  # noqa
import core.endpoints.directories  # noqa
import core.endpoints.editions  # noqa
import core.endpoints.health  # noqa
import core.endpoints.lines  # noqa
import core.endpoints.steps  # noqa
import core.server  # noqa

from core.config import Config  # noqa
from core.directory import Directory  # noqa
from core.pipeline import DummyPipeline, Pipeline  # noqa
from core.plotter import Plotter  # noqa
from core.utils.filesystem import Filesystem  # noqa
from core.utils.slack import Slack  # noqa
from core.utils.metadata import Metadata  # noqa

# Import pipelines
# from check_pef import CheckPef  # noqa
# from incoming_NLBPUB import (NLBPUB_incoming_validator,
#                              NLBPUB_incoming_warning, NLBPUB_validator)  # noqa
from daisy202_to_distribution import Daisy202ToDistribution # noqa
from incoming_nordic import IncomingNordic  # noqa
from insert_metadata import (InsertMetadataBraille, InsertMetadataDaisy202,
                             InsertMetadataXhtml)  # noqa
from magazines_to_validation import MagazinesToValidation
from make_abstracts import Audio_Abstract  # noqa
from newsletter import Newsletter  # noqa
from newspaper_schibsted import DummyTtsNewspaperSchibsted, NewspaperSchibsted  # noqa
from nlbpub_previous import NlbpubPrevious  # noqa
from nlbpub_to_docx import NLBpubToDocx  # noqa
from nlbpub_to_epub import NlbpubToEpub  # noqa
from nlbpub_to_html import NlbpubToHtml  # noqa
from nlbpub_to_narration_epub import NlbpubToNarrationEpub  # noqa
from nlbpub_to_pef import NlbpubToPef  # noqa
from nlbpub_to_tts_dtbook import NlbpubToTtsDtbook  # noqa
# from nordic_dtbook_to_epub import NordicDTBookToEpub  # noqa
from nordic_to_nlbpub import NordicToNlbpub  # noqa
from prepare_for_braille import PrepareForBraille  # noqa
from prepare_for_docx import PrepareForDocx  # noqa
from prepare_for_ebook import PrepareForEbook
from statped_nlbpub_to_nlbpub import StatpedNlbpubToNlbpub  # noqa
# from update_metadata import UpdateMetadata  # noqa

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class Produksjonssystem():

    book_archive_dirs = None
    email = None
    dirs = None
    dirs_inactivity_timeouts = None
    pipelines = None
    environment = None
    emailDoc = []
    api = None
    airbrake_config = None

    def __init__(self, environment=None, verbose=False):
        logger = logging.getLogger()
        if os.environ.get("LOCATION_LOG_FILE") is not None:
            logfile = os.environ.get("LOCATION_LOG_FILE")
        else:
            logfile = "/tmp/produksjonssystem.log"
        handler = TimedRotatingFileHandler(logfile,
                                           when="D",
                                           interval=7,
                                           backupCount=5)
        fmt = "%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s"
        formatter = logging.Formatter(fmt=fmt)
        handler.setFormatter(formatter)
        handler.setLevel(level=logging.DEBUG if os.environ.get("DEBUG", "1") == "1" else logging.INFO)
        logger.addHandler(handler)
        if verbose:
            consoleHandler = logging.StreamHandler(sys.stdout)
            consoleHandler.setFormatter(formatter)
            consoleHandler.setLevel(level=logging.DEBUG if os.environ.get("DEBUG", "1") == "1" else logging.INFO)
            logger.addHandler(consoleHandler)

        # add airbrake.io handler
        self.airbrake_config = {
            "project_id": os.getenv("AIRBRAKE_PROJECT_ID", None),
            "project_key": os.getenv("AIRBRAKE_PROJECT_KEY", None),
            "environment": os.getenv("AIRBRAKE_ENVIRONMENT", "development")
        }
        if self.airbrake_config["project_id"] and self.airbrake_config["project_key"]:
            notifier = pybrake.Notifier(**self.airbrake_config)
            airbrake_handler = pybrake.LoggingHandler(notifier=notifier, level=logging.ERROR)
            logging.getLogger().addHandler(airbrake_handler)
        else:
            self.airbrake_config = None
            logging.warning("Airbrake.io not configured (missing AIRBRAKE_PROJECT_ID and/or AIRBRAKE_PROJECT_KEY)")

        # Set environment variables (mainly useful when testing)
        if environment:
            assert isinstance(environment, dict)
            for name in environment:
                os.environ[name] = environment[name]
            self.environment = environment
        else:
            self.environment = {}
        Pipeline.environment = self.environment  # Make environment available from pipelines
        # Check that archive dirs is defined
        assert os.environ.get("BOOK_ARCHIVE_DIRS"), (
            "The book archives must be defined as a space separated list in the environment variable BOOK_ARCHIVE_DIRS (as name=path pairs)")
        self.book_archive_dirs = {}
        for d in os.environ.get("BOOK_ARCHIVE_DIRS").split(" "):
            assert "=" in d, "Book archives must be specified as name=path. For instance: master=/media/archive. Note that paths can not contain spaces."
            archive_name = d.split("=")[0]
            archive_path = os.path.normpath(d.split("=")[1]) + "/"
            self.book_archive_dirs[archive_name] = archive_path

        # for convenience; both method variable and instance variable so you don't have to
        # write "self." all the time during initialization.
        book_archive_dirs = self.book_archive_dirs

        Config.set("test", os.environ.get("TEST", "false").lower() in ["true", "1"])
        Config.set("email.allowed_email_addresses_in_test", os.environ.get("ALLOWED_EMAIL_ADDRESSES_IN_TEST", "").split(","))

        # Configure email
        Config.set("email.sender.name", "NLBs Produksjonssystem")
        Config.set("email.sender.address", "produksjonssystem@nlb.no")
        Config.set("email.smtp.host", os.environ.get("MAIL_SERVER", None))
        Config.set("email.smtp.port", os.environ.get("MAIL_PORT", None))
        Config.set("email.smtp.user", os.environ.get("MAIL_USERNAME", None))
        Config.set("email.smtp.pass", os.environ.get("MAIL_PASSWORD", None))
        Config.set("email.formatklar.address", os.environ.get("MAIL_FORMATKLAR"))
        Config.set("email.filesize.address", os.environ.get("MAIL_FILESIZE"))
        Config.set("email.abklar.address", os.environ.get("MAIL_ABKLAR"))

        # Configure NLB API URL
        Config.set("nlb_api_url", os.environ.get("NLB_API_URL"))

        # Special directories
        Config.set("master_dir", os.path.join(book_archive_dirs["master"], "master/EPUB"))
        Config.set("newsfeed_dir", os.path.join(book_archive_dirs["master"], "innkommende/schibsted-aviser/avisfeeder"))
        Config.set("reports_dir", os.getenv("REPORTS_DIR", os.path.join(book_archive_dirs["master"], "rapporter")))
        Config.set("metadata_dir", os.getenv("METADATA_DIR", os.path.join(book_archive_dirs["master"], "metadata")))
        Config.set("nlbsamba.dir", os.environ.get("NLBSAMBA_DIR"))

        # Define directories (using OrderedDicts to preserve order when plotting)
        self.dirs_ranked = []

        self.dirs_ranked.append({
            "id": "incoming",
            "name": "Mottak",
            "dirs": OrderedDict()
        })
        # self.dirs_ranked[-1]["dirs"]["incoming_NLBPUB"] = os.path.join(book_archive_dirs["master"], "innkommende/NLBPUB")
        # self.dirs_ranked[-1]["dirs"]["nlbpub_manuell"] = os.path.join(book_archive_dirs["master"], "mottakskontroll/NLBPUB")
        self.dirs_ranked[-1]["dirs"]["incoming"] = os.path.join(book_archive_dirs["master"], "innkommende/nordisk")
        # self.dirs_ranked[-1]["dirs"]["incoming-for-approval"] = os.path.join(book_archive_dirs["master"], "innkommende/nordisk-manuell-mottakskontroll")
        self.dirs_ranked[-1]["dirs"]["old_dtbook"] = os.path.join(book_archive_dirs["master"], "grunnlagsfil/DTBook")
        self.dirs_ranked[-1]["dirs"]["incoming-statped-nlbpub"] = os.path.join(book_archive_dirs["master"], "innkommende/statped-nlbpub")

        self.dirs_ranked.append({
            "id": "source-in",
            "name": "Ubehandlet kildefil",
            "dirs": OrderedDict()
        })

        self.dirs_ranked.append({
            "id": "source-out",
            "name": "Behandlet kildefil",
            "dirs": OrderedDict()
        })

        self.dirs_ranked.append({
            "id": "master",
            "name": "Grunnlagsfil",
            "dirs": OrderedDict()
        })
        self.dirs_ranked[-1]["dirs"]["master"] = Config.get("master_dir")
        self.dirs_ranked[-1]["dirs"]["metadata"] = Config.get("metadata_dir")
        # self.dirs_ranked[-1]["dirs"]["grunnlag"] = os.path.join(book_archive_dirs["master"], "grunnlagsfil/NLBPUB")
        self.dirs_ranked[-1]["dirs"]["nlbpub"] = os.path.join(book_archive_dirs["master"], "master/NLBPUB")
        self.dirs_ranked[-1]["dirs"]["epub_from_dtbook"] = os.path.join(book_archive_dirs["master"], "grunnlagsfil/EPUB-fra-DTBook")
        self.dirs_ranked[-1]["dirs"]["news"] = Config.get("newsfeed_dir")
        self.dirs_ranked.append({
            "id": "version-control",
            "name": "Versjonskontroll",
            "dirs": OrderedDict()
        })
        self.dirs_ranked[-1]["dirs"]["nlbpub-previous"] = os.path.join(book_archive_dirs["master"], "master/NLBPUB-tidligere")

        self.dirs_ranked.append({
                "id": "publication-in",
                "name": "Format-spesifikk metadata",
                "dirs": OrderedDict()
        })
        self.dirs_ranked[-1]["dirs"]["pub-in-braille"] = os.path.join(book_archive_dirs["master"], "utgave-inn/punktskrift")
        self.dirs_ranked[-1]["dirs"]["pub-in-ebook"] = os.path.join(book_archive_dirs["master"], "utgave-inn/e-tekst")
        self.dirs_ranked[-1]["dirs"]["pub-in-audio"] = os.path.join(book_archive_dirs["master"], "utgave-inn/lydbok")

        self.dirs_ranked.append({
            "id": "publication-ready",
            "name": "Klar for produksjon",
            "dirs": OrderedDict()
        })
        self.dirs_ranked[-1]["dirs"]["pub-ready-braille"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/punktskrift")
        self.dirs_ranked[-1]["dirs"]["pub-ready-ebook"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/e-bok")
        self.dirs_ranked[-1]["dirs"]["pub-ready-docx"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DOCX")
        self.dirs_ranked[-1]["dirs"]["pub-ready-magazine"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/tidsskrifter")
        self.dirs_ranked[-1]["dirs"]["epub_narration"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/EPUB-til-innlesing")
        self.dirs_ranked[-1]["dirs"]["dtbook_tts"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DTBook-til-talesyntese")
        self.dirs_ranked[-1]["dirs"]["dtbook_news"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/DTBook-aviser-til-talesyntese")

        self.dirs_ranked.append({
            "id": "publication-out",
            "name": "Ferdig produsert",
            "dirs": OrderedDict()
        })
        self.dirs_ranked[-1]["dirs"]["pef"] = os.path.join(book_archive_dirs["master"], "utgave-ut/PEF")
        self.dirs_ranked[-1]["dirs"]["pef-checked"] = os.path.join(book_archive_dirs["master"], "utgave-ut/PEF-kontrollert")
        self.dirs_ranked[-1]["dirs"]["html"] = os.path.join(book_archive_dirs["master"], "utgave-ut/HTML")
        self.dirs_ranked[-1]["dirs"]["epub-ebook"] = os.path.join(book_archive_dirs["share"], "daisy202/EPUB")
        self.dirs_ranked[-1]["dirs"]["docx"] = os.path.join(book_archive_dirs["master"], "utgave-ut/DOCX")
        self.dirs_ranked[-1]["dirs"]["daisy202"] = os.path.join(book_archive_dirs["share"], "daisy202")
        self.dirs_ranked[-1]["dirs"]["abstracts"] = os.path.join(book_archive_dirs["distribution"], "www/abstracts")
        self.dirs_ranked[-1]["dirs"]["daisy202-ready"] = os.path.join(book_archive_dirs["master"], "utgave-klargjort/lydbok-til-validering")
        self.dirs_ranked[-1]["dirs"]["daisy202-dist"] = os.path.join(book_archive_dirs["share"], "daisy202")

        # Make a key/value version of dirs_ranked for convenience
        self.dirs = {
            "reports": Config.get("reports_dir")
        }
        for rank in self.dirs_ranked:
            for dir in rank["dirs"]:
                self.dirs[dir] = rank["dirs"][dir]

        # also make dirs available from static contexts
        Directory.dirs_ranked = self.dirs_ranked
        Directory.dirs_flat = self.dirs

        # by default, the inactivity timeout for all directories are 10 seconds,
        # but they can be overridden here
        # for instance: self.dirs_inactivity_timeouts["master"] = 300
        self.dirs_inactivity_timeouts = {}

        # Define pipelines and input/output/report dirs
        self.pipelines = [
            # Konvertering av gamle DTBøker til EPUB 3
            # [NordicDTBookToEpub(retry_missing=True,
            #                     only_when_idle=True),         "old_dtbook",          "epub_from_dtbook"],

            # Mottak, nordic guidelines 2015-1
            # [NLBPUB_incoming_validator(retry_all=True,
            #                            during_working_hours=True
            #                            ),                     "incoming_NLBPUB",     "grunnlag"],
            # [NLBPUB_incoming_warning(retry_all=True,
            #                          during_working_hours=True
            #                          ),                       "incoming_NLBPUB",     "nlbpub_manuell"],
            # [DummyPipeline("Manuell sjekk av NLBPUB",
            #                labels=["EPUB"]),                  "nlbpub_manuell",      "grunnlag"],
            #  [NLBPUB_validator(overwrite=False),                              "grunnlag",            "nlbpub"],

            [IncomingNordic(retry_all=True,
                            during_working_hours=True,
                            during_night_and_weekend=True),       "incoming",            "master"],
            [NordicToNlbpub(retry_missing=True,
                            overwrite=False,
                            during_working_hours=True,
                            during_night_and_weekend=True),   "master",              "nlbpub"],
            [StatpedNlbpubToNlbpub(retry_all=True,
                                   during_working_hours=True,
                                   during_night_and_weekend=True),       "incoming-statped-nlbpub",            "nlbpub"],

            # Grunnlagsfiler
            [NlbpubPrevious(retry_missing=True),               "nlbpub",              "nlbpub-previous"],

            # e-bok
            [InsertMetadataXhtml(retry_missing=True,
                                 retry_old=True,
                                 retry_complete=True,
                                 check_identifiers=True,
                                 during_night_and_weekend=True,
                                 during_working_hours=True),    "nlbpub",              "pub-in-ebook"],
            [PrepareForEbook(retry_missing=True,
                             check_identifiers=True,
                             during_night_and_weekend=True,
                             during_working_hours=True),        "pub-in-ebook",        "pub-ready-ebook"],
            [PrepareForDocx(retry_missing=True,
                            check_identifiers=True,
                            during_working_hours=True),         "pub-in-ebook",        "pub-ready-docx"],
            [NlbpubToEpub(retry_missing=True,
                          check_identifiers=True,
                          during_working_hours=True,
                          during_night_and_weekend=True),       "pub-ready-ebook",     "epub-ebook"],
            [NlbpubToHtml(retry_missing=True,
                          check_identifiers=True,
                          during_working_hours=True),           "pub-ready-ebook",     "html"],
            [NLBpubToDocx(retry_missing=True,
                          check_identifiers=True,
                          during_working_hours=True),           "pub-ready-docx",      "docx"],
            [Newsletter(during_working_hours=True,
                        during_night_and_weekend=True),         None,                  "pub-ready-braille"],
            [NewspaperSchibsted(during_working_hours=True,
                                during_night_and_weekend=True), "news",                "dtbook_news"],
            # punktskrift
            [InsertMetadataBraille(retry_missing=True,
                                   check_identifiers=True,
                                   during_working_hours=True),  "nlbpub",              "pub-in-braille"],
            [PrepareForBraille(retry_missing=True,
                               check_identifiers=True,
                               during_working_hours=True),      "pub-in-braille",      "pub-ready-braille"],
            [NlbpubToPef(retry_missing=True,
                         check_identifiers=True,
                         during_working_hours=True),            "pub-ready-braille",   "pef"],
            # [CheckPef(),                                        "pef",                 "pef-checked"],

            # innlest lydbok
            [InsertMetadataDaisy202(retry_missing=True,
                                    check_identifiers=True,
                                    during_working_hours=True), "nlbpub",              "pub-in-audio"],
            [NlbpubToNarrationEpub(retry_missing=True,
                                   check_identifiers=True,
                                   during_working_hours=True),  "pub-in-audio",        "epub_narration"],
            [DummyPipeline("Innlesing med Hindenburg",
                           labels=["Lydbok", "Statped"]),       "epub_narration",      "daisy202"],

            # TTS-lydbok
            [NlbpubToTtsDtbook(retry_missing=True,
                               check_identifiers=True,
                               during_working_hours=True,
                               during_night_and_weekend=True),  "pub-in-audio",        "dtbook_tts"],
            [DummyPipeline("Talesyntese i Pipeline 1",
                           labels=["Lydbok"]),                  "dtbook_tts",          "daisy202"],
            [DummyTtsNewspaperSchibsted("Talesyntese i Pipeline 1 for aviser",
                                        labels=["Lydbok"]),     "dtbook_news",          "daisy202"],

            # lydutdrag
            [Audio_Abstract(retry_missing=True,
                            during_working_hours=True,
                            during_night_and_weekend=True),     "daisy202",            "abstracts"],

            # lydbok distribusjon
            [Daisy202ToDistribution(retry_all=True,
                                    during_working_hours=True,
                                    during_night_and_weekend=True),       "daisy202-ready",            "daisy202-dist"],
            [MagazinesToValidation(retry_missing=False),       "pub-ready-magazine",            "daisy202-ready"],
        ]

    # Could possibly be moved to a configuration file
    production_lines = [
        {
            "id": "epub",
            "name": "Bestilling og mottak av EPUB",
            "steps": ["incoming-nordic", "dummy_manuellmottakskontroll", "nordic-epub-to-nlbpub"],
        },
        {
            "id": "narration",
            "name": "Innlesing",
            "steps": ["insert-metadata-daisy202", "nlbpub-to-narration-epub", "dummy_innlesingmedhindenburg", "create-abstracts", "daisy202-to-distribution"],
        },
        {
            "id": "tts",
            "name": "Talesyntese",
            "steps": ["insert-metadata-daisy202", "nlbpub-to-tts-dtbook", "dummy_talesynteseipipeline1", "create-abstracts", "daisy202-to-distribution"],
            "filters": {
                "libraries": ["NLB"],
            },
        },
        {
            "id": "schibsted",
            "name": "Schibsted-aviser",
            "steps": ["newspaper-schibsted", "dummy_talesynteseipipeline1foraviser", "create-abstracts", "daisy202-to-distribution"],
            "filters": {
                "libraries": ["NLB"],
            },
        },
        {
            "id": "braille",
            "name": "Punktskrift",
            "steps": ["insert-metadata-braille", "prepare-for-braille", "nlbpub-to-pef"],
        },
        {
            "id": "braille-newsletter",
            "name": "Nyhetsbrev i punktskrift",
            "steps": ["newsletter-to-braille", "nlbpub-to-pef"],
            "filters": {
                "libraries": ["NLB"],
            },
        },
        {
            "id": "e-book",
            "name": "E-bøker",
            "steps": ["insert-metadata-xhtml", "prepare-for-ebook", "nlbpub-to-epub"],
            "filters": {
                "libraries": ["NLB"],
            },
        },
        {
            "id": "html",
            "name": "E-bøker som HTML",
            "steps": ["insert-metadata-xhtml", "prepare-for-ebook", "nlbpub-to-html"],
            "filters": {
                "libraries": ["Statped"],
            },
        },
        {
            "id": "docx",
            "name": "E-bøker som DOCX",
            "steps": ["insert-metadata-xhtml", "prepare-for-docx", "nlbpub-to-docx"],
            "filters": {
                "libraries": ["Statped"],
            },
        },
    ]
    Config.set("production-lines", production_lines)

    # ---------------------------------------------------------------------------
    # Don't edit below this line if you only want to add/remove/modify a pipeline
    # ---------------------------------------------------------------------------

    def info(self, text):
        logging.info(text)
        Slack.slack(text, None)

    def run(self, debug=False, verbose=False):
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
        print("Dashboard: file://" + os.path.join(Config.get("reports_dir"), "dashboard.html"))
        for d in self.book_archive_dirs:
            print("Book archive \"{}\": file://{}".format(d, self.book_archive_dirs[d]))
        print("")

        # Make directories
        for d in self.dirs:
            os.makedirs(self.dirs[d], exist_ok=True)

        threads = []
        file_name = os.environ.get("CONFIG_FILE")
        self.emailDoc = ""
        with open(file_name, 'r') as f:
            try:
                self.emailDoc = yaml.load(f, Loader=yaml.FullLoader)
            except Exception as e:
                self.info("En feil oppstod under lasting av konfigurasjonsfilen. Sjekk syntaksen til produksjonssystem.yaml")
                traceback.print_exc(e)

        # Make pipelines available from static methods in the Pipeline class
        Pipeline.pipelines = [pipeline[0] for pipeline in self.pipelines]

        for common in self.emailDoc["common"]:
            for common_key in common:
                Config.set(common_key, common[common_key])

        self.shouldRun(True)

        self.server = core.server.start(hot_reload=False, airbrake_config=self.airbrake_config, shutdown_function=self.stop)

        self._configThread = Thread(target=self._config_thread, name="config")
        self._configThread.setDaemon(True)
        self._configThread.start()

        Config.set("dailyReports.enabled", os.environ.get("DAILY_REPORTS_ENABLED", "true").lower() in ["true", "1"])
        if Config.get("dailyReports.enabled"):
            self._dailyReportThread = Thread(target=self._daily_report_thread, name="daily report")
            self._dailyReportThread.setDaemon(True)
            self._dailyReportThread.start()

        self._systemStatusThread = Thread(target=self._system_status_thread, name="system status")
        self._systemStatusThread.setDaemon(True)
        self._systemStatusThread.start()

        Config.set("signatures.enabled", os.environ.get("SIGNATURES_ENABLED", "true").lower() in ["true", "1"])
        if Config.get("signatures.enabled"):
            self._signaturesRefreshThread = Thread(target=self._signatures_refresh_thread, name="signatures refresh")
            self._signaturesRefreshThread.setDaemon(True)
            self._signaturesRefreshThread.start()

        for pipeline in self.pipelines:
            email_settings = {
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

            inactivity_timeout = 10
            if pipeline[1] and pipeline[1] in self.dirs_inactivity_timeouts:
                self.dirs_inactivity_timeouts[pipeline[1]]
            thread = Thread(target=pipeline[0].run, name=pipeline[0].uid,
                            args=(inactivity_timeout,  # inactivity_timeout
                                  self.dirs[pipeline[1]] if pipeline[1] else None,  # dir_in
                                  self.dirs[pipeline[2]] if pipeline[2] else None,  # dir_out
                                  self.dirs["reports"],  # dir_reports
                                  email_settings,  # email_settings
                                  self.book_archive_dirs,  # dir_base
                                  pipeline_config  # config
                                  ))

            thread.setDaemon(True)
            thread.start()
            threads.append(thread)

        plotter = Plotter(self.pipelines, report_dir=self.dirs["reports"])
        graph_thread = Thread(target=plotter.run, name="graph")
        graph_thread.setDaemon(True)
        graph_thread.start()

        self.info("Produksjonssystemet er startet")

        last_thread_usage_log = time.time()
        system_process = psutil.Process()  # This process
        system_process.cpu_percent()  # first value returned is 0.0, which we ignore
        try:
            running = True
            time.sleep(5)  # wait a few seconds before starting to monitor the system (extra precaution to avoid race conditions during startup)
            while running:
                time.sleep(1)

                # TODO: The trigger directory mechanism, including the stopfile, is deprecated. Will be removed in the future.
                #       Use the stop function or shutdown API endpoint instead.
                stopfile = os.getenv("TRIGGER_DIR")
                if stopfile:
                    stopfile = os.path.join(stopfile, "stop")
                if os.path.exists(stopfile):
                    self.stop()
                    os.remove(stopfile)
                elif not self.shouldRun():
                    self.stop()

                if os.getenv("STOP_AFTER_FIRST_JOB", False):
                    running = 0
                    for pipeline in self.pipelines:
                        if pipeline[0].running:
                            running += 1
                    running = True if running > 0 else False

                else:
                    for thread in threads:
                        if not thread.is_alive():
                            self.info("thread is not running, will restart system: {} is not healty, will restart system...".format(thread))
                            running = False
                            break

                    for pipeline in self.pipelines:
                        if not pipeline[0].is_healthy():
                            self.info("pipeline is not healthy, will restart system: {}".format(pipeline[0].title))
                            running = False

                if time.time() - last_thread_usage_log > 600:
                    last_thread_usage_log = time.time()
                    with system_process.oneshot():
                        self.info("Total memory usage: {:.1f} % ({:.3} MB)".format(system_process.memory_percent(memtype='uss'),
                                                                                   system_process.memory_full_info().uss / 1000000))
                        self.info("Total CPU usage: {:.1f} % ({} cores)".format(system_process.cpu_percent(), psutil.cpu_count()))
                        # TODO: find a way to log thread cpu usage

        except KeyboardInterrupt:
            pass

        self.shouldRun(False)

        for pipeline in self.pipelines:
            pipeline[0].stop()

        self.info("Venter på at alle pipelinene skal stoppe...")
        for thread in threads:
            if thread:
                logging.debug("joining {}".format(thread.name))
            thread.join(timeout=5)

        is_alive = True
        join_start_time = time.time()
        while is_alive:
            is_alive = False
            for thread in threads:
                if thread and thread != threading.current_thread() and thread.is_alive():
                    if time.time() - join_start_time > 60 * 60:
                        self.info("Thread is still running (we've waited too long, let's ignore it): {}".format(thread.name))
                        thread.join(timeout=5)
                    else:
                        is_alive = True
                        self.info("Thread is still running: {}".format(thread.name))
                        thread.join(timeout=5)
            for pipeline in self.pipelines:
                if pipeline[0].running:
                    self.info("{} kjører fortsatt, venter på at den skal stoppe{}...".format(
                        pipeline[0].title,
                        " ({} / {})".format(pipeline[0].book["name"], pipeline[0].get_progress()) if pipeline[0].book else ""))
                if pipeline[0].shouldRun:
                    self.info("{} har startet igjen, sender nytt signal om at den skal stoppe...".format(pipeline[0].uid))
                    pipeline[0].stop()

        self.info("Venter på at plotteren skal stoppe...")
        time.sleep(5)  # gi plotteren litt tid på slutten
        plotter.should_run = False
        if graph_thread:
            logging.debug("joining {}".format(graph_thread.name))
        graph_thread.join()
        if graph_thread:
            logging.debug("joined {}".format(graph_thread.name))

        if Config.get("signatures.enabled"):
            self.info("Venter på at signatur-oppdateringstråden skal stoppe...")
            self._signaturesRefreshThread.join()

        self.info("Venter på at konfigtråden skal stoppe...")
        self._configThread.join()

        if Config.get("dailyReports.enabled"):
            self.info("Venter på at dagsrapport-tråden skal stoppe...")
            self._dailyReportThread.join()

        self.info("Venter på at systemstatus-tråden skal stoppe...")
        self._systemStatusThread.join()

        self.info("Venter på at API-tråden skal stoppe...")
        self.server.join(timeout=10)

    def shouldRun(self, set=None):
        if set is not None:
            Config.set("system.shouldRun", set)
        else:
            return Config.get("system.shouldRun")

    def wait_until_running(self, timeout=60):
        start_time = time.time()

        while time.time() - start_time < timeout:
            waiting = 0
            for pipeline in self.pipelines:
                if pipeline[0].shouldRun and not pipeline[0].running:
                    waiting += 1
            if waiting == 0:
                return True

        return False

    def stop(self):
        self.info("Sender stoppsignal til alle pipelines...")
        for pipeline in self.pipelines:
            pipeline[0].stop()

    def is_idle(self):
        for pipeline in self.pipelines:
            if not pipeline[0].is_idle():
                return False
        return True

    def _system_status_thread(self):
        # Update system status
        idle_start_time = time.time()
        while self.shouldRun():
            time.sleep(5)
            if not self.is_idle():
                idle_start_time = time.time()
            Config.set("system.idle", int(time.time() - idle_start_time))

    def _daily_report_thread(self):
        # Checks for reports in daily report dir for each pipeline. Only sends mail once each day after 7
        last_update = 0
        while self.shouldRun():
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

                if not self.shouldRun():
                    break
                if pipeline[0].uid == "insert-metadata-daisy202" or pipeline[0].uid == "insert-metadata-xhtml" or pipeline[0].uid == "insert-metadata-braille" or pipeline[0].uid == "create-abstracts":
                    continue
                if "dummy" in pipeline[0].uid:
                    continue
                if os.path.isfile(os.path.join(daily_dir, pipeline[0].uid + ".html")):
                    continue
                try:
                    number_produced = 0
                    number_failed = 0
                    file = os.path.join(daily_dir, pipeline[0].uid)
                    message = "## Produsert i pipeline: " + pipeline[0].title + ": " + yesterday + "\n"
                    content = "\n## Bøker som har gått gjennom:"
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

                    content = content + "\n## Bøker som har feilet:"
                    if (os.path.isfile(file + "-FAIL.txt")):
                        with open(file + "-FAIL.txt", "r") as report_file_fail:
                            report_content = report_file_fail.readlines()
                            content = content + self.format_email_report(report_content, dirs, dir_log, logfile, self.book_archive_dirs["master"])
                            for line in report_content:
                                if pipeline[0].title in line and line.startswith("["):
                                    number_failed += 1
                    else:
                        content = content + "\nIngen feilet\n"
                    message = message + "\n## Totalt ble {} produsert og {} feilet\n".format(number_produced, number_failed)
                    message = message + content
                    pipeline[0].daily_report(message)
                except Exception:
                    self.info("En feil oppstod under sending av dagsrapporten for " + pipeline[0].title)
                    self.info(traceback.format_exc())

    def _config_thread(self):
        fileName = os.environ.get("CONFIG_FILE")
        last_update = 0
        while self.shouldRun():

            if time.time() - last_update < 300:
                time.sleep(5)
                continue
            last_update = time.time()

            try:
                with open(fileName, 'r') as f:
                    tempEmailDoc = yaml.load(f, Loader=yaml.FullLoader)
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

    def _signatures_refresh_thread(self):
        idle_start_time = time.time()
        while self.shouldRun():
            time.sleep(5)
            if time.time() - Metadata.signatures_last_update > 3600*3:
                Metadata.get_signatures_from_quickbase("0", refresh=True)  # discard the result, we just want to trigger an update

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
        timeout = 600
        timeout_start = time.time()

        for line in content:
            if time.time() > timeout_start + timeout:
                return message
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
    threading.current_thread().setName("main thread")
    debug = "debug" in sys.argv or os.environ.get("DEBUG", "0") == "1"
    verbose = "verbose" in sys.argv or os.environ.get("VERBOSE", "0") == "1"
    produksjonssystem = Produksjonssystem(verbose=verbose)
    produksjonssystem.run(debug=debug)
