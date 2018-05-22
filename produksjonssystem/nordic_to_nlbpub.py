#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import shutil
import tempfile

from core.utils.epub import Epub
from core.utils.xslt import Xslt
from core.utils.daisy_pipeline import DaisyPipelineJob

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class NordicToNlbpub(Pipeline):
    uid = "nordic-epub-to-nlbpub"
    title = "Nordisk EPUB til NLBPUB"
    labels = [ "EPUB", "Lydbok", "Innlesing", "Talesyntese", "Punktskrift", "e-bok" ]
    publication_format = None
    expected_processing_time = 686

    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "xslt"))

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB master slettet: " + self.book['name']

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")
        epub = Epub(self, self.book["source"])

        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass

        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return

        html_dir_obj = tempfile.TemporaryDirectory()
        html_dir = html_dir_obj.name
        html_file = os.path.join(html_dir, epub.identifier() + ".xhtml")
        temp_html_file_obj = tempfile.NamedTemporaryFile()
        temp_html_file = temp_html_file_obj.name

        self.utils.report.info("Konverterer fra Nordisk EPUB 3 til Nordisk HTML 5...")
        with DaisyPipelineJob(self, "nordic-epub3-to-html", {"epub": epub.asFile(), "fail-on-error": "true"}) as dp2_job:

            # get conversion report
            report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
            if os.path.isfile(report_file):
                with open(report_file, 'r') as result_report:
                    self.utils.report.attachment(result_report.readlines(),
                                                 os.path.join(self.utils.report.reportDir(), "report.html"),
                                                 "SUCCESS" if dp2_job.status == "DONE" else "ERROR")

            if dp2_job.status != "DONE":
                self.utils.report.error("Klarte ikke å konvertere boken")
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return

            dp2_html_dir = os.path.join(dp2_job.dir_output, "output-dir", epub.identifier())
            dp2_html_file = os.path.join(dp2_job.dir_output, "output-dir", epub.identifier(), epub.identifier() + ".xhtml")

            if not os.path.isdir(dp2_html_dir):
                self.utils.report.error("Finner ikke den konverterte boken: {}".format(dp2_html_dir))
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return False

            if not os.path.isfile(dp2_html_file):
                self.utils.report.error("Finner ikke den konverterte boken: {}".format(dp2_html_file))
                self.utils.report.info("Kanskje filnavnet er forskjellig fra IDen?")
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return False

            self.utils.filesystem.copy(dp2_html_dir, html_dir)

        self.utils.report.info("Rydder opp i nordisk HTML")
        xslt = Xslt(self, stylesheet=os.path.join(NordicToNlbpub.xslt_dir, NordicToNlbpub.uid, "nordic-cleanup.xsl"),
                    source=html_file,
                    target=temp_html_file)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return
        shutil.copy(temp_html_file, html_file)

        self.utils.report.info("Legger til EPUB-filer (OPF, NAV, container.xml, mediatype)...")
        nlbpub_tempdir_obj = tempfile.TemporaryDirectory()
        nlbpub_tempdir = nlbpub_tempdir_obj.name

        nlbpub = Epub.from_html(self, html_dir, nlbpub_tempdir)
        if nlbpub is None:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return

        self.utils.report.info("Boken ble konvertert. Kopierer til NLBPUB-arkiv.")
        archived_path = self.utils.filesystem.storeBook(nlbpub.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i NLBPUB-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle


if __name__ == "__main__":
    NordicToNlbpub().run()
