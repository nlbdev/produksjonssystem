#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import subprocess
import sys
import traceback

from core.pipeline import Pipeline
from core.utils.compare_with_reference import CompareWithReference
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class IncomingNordic(Pipeline):
    uid = "incoming-nordic"
    title = "Validering av Nordisk EPUB 3"
    labels = ["EPUB"]
    publication_format = None
    expected_processing_time = 300

    ace_cli = None

    @staticmethod
    def init_environment():
        if "ACE_CLI" in Pipeline.environment:
            IncomingNordic.ace_cli = Pipeline.environment["ACE_CLI"]
        elif os.path.exists("/usr/bin/ace"):
            IncomingNordic.ace_cli = "/usr/bin/ace"
        else:
            IncomingNordic.ace_cli = "ace"

    def __init__(self, *args, **kwargs):
        IncomingNordic.init_environment()
        super().__init__(*args, **kwargs)

    def on_book_deleted(self):
        self.utils.report.should_email = False
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: "+self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: "+self.book['name'])
        return self.on_book()

    def on_book(self):
        epub = Epub(self, self.book["source"])
        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass
        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return

        self.utils.report.info("Validerer EPUB med epubcheck og nordiske retningslinjer...")
        with DaisyPipelineJob(self, "nordic-epub3-validate", {"epub": epub.asFile()}) as dp2_job:

            # get validation report
            report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
            if os.path.isfile(report_file):
                with open(report_file, 'r') as result_report:
                    self.utils.report.attachment(result_report.readlines(),
                                                 os.path.join(self.utils.report.reportDir(), "report.html"),
                                                 "SUCCESS" if dp2_job.status == "DONE" else "ERROR")

            if dp2_job.status != "DONE":
                self.utils.report.error("Klarte ikke å validere boken")
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return

        try:
            self.utils.report.info("Genererer ACE-rapport...")
            ace_dir = os.path.join(self.utils.report.reportDir(), "accessibility-report")
            process = self.utils.filesystem.run([IncomingNordic.ace_cli, "-o", ace_dir, epub.asFile()])
            if process.returncode == 0:
                self.utils.report.info("ACE-rapporten ble generert.")
            else:
                self.utils.report.warn("En feil oppstod ved produksjon av ACE-rapporten for " + epub.identifier())
                self.utils.report.debug(traceback.format_stack())

            # attach report
            ace_status = None
            with open(os.path.join(ace_dir, "report.json")) as json_report:
                ace_status = json.load(json_report)["earl:result"]["earl:outcome"]
            if ace_status == "pass":
                ace_status = "SUCCESS"
            else:
                ace_status = "WARN"
            self.utils.report.attachment(None, os.path.join(ace_dir, "report.html"), ace_status)

        except subprocess.TimeoutExpired:
            self.utils.report.warn("Det tok for lang tid å lage ACE-rapporten for " + epub.identifier() + ", og prosessen ble derfor stoppet.")

        except Exception:
            self.utils.report.warn("En feil oppstod ved produksjon av ACE-rapporten for " + epub.identifier())
            self.utils.report.debug(traceback.format_exc(), preformatted=True)

        spine = epub.spine()
        try:
            self.utils.report.info("Sammenligner innholdet med referansefilen")
            html_paths = []
            for item in spine:
                html_paths.append(os.path.join(epub.asDir(), os.path.dirname(epub.opf_path()), item["href"]))

            reference = CompareWithReference(pipeline=self,
                                             reference=os.path.join(Xslt.xslt_dir, IncomingNordic.uid, "reference-files", "nordic.xhtml"),
                                             source=html_paths)

            if not reference.success:
                self.utils.report.warn("Validering av HTML i henhold til referansefil feilet")

        except Exception:
            self.utils.report.warn("En feil oppstod ved produksjon av referansefil-rapporten for " + epub.identifier())
            self.utils.report.debug(traceback.format_exc(), preformatted=True)

        self.utils.report.info("Boken er valid. Kopierer til EPUB master-arkiv.")

        archived_path = self.utils.filesystem.storeBook(epub.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.success(epub.identifier()+" ble lagt til i master-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " er valid 👍😄" + epubTitle
        self.utils.filesystem.deleteSource()
        return True


if __name__ == "__main__":
    IncomingNordic().run()
