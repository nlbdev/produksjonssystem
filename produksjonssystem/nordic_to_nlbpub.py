#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import time
import shutil
import tempfile
import subprocess

from lxml import etree as ElementTree
from datetime import datetime, timezone
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from core.utils.metadata import Metadata
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

        # ---------- convert from nordic epub to nordic html ----------

        html_dir = None
        html_file = None

        self.utils.report.info("Konverterer fra Nordisk EPUB 3 til Nordisk HTML 5...")
        dp2_job_epub3_to_html = DaisyPipelineJob(self, "nordic-epub3-to-html", { "epub": epub.asFile(), "fail-on-error": "true" })

        # get conversion report
        report_file = os.path.join(dp2_job_epub3_to_html.dir_output, "html-report/report.xhtml")
        if os.path.isfile(report_file):
            with open(report_file, 'r') as result_report:
                self.utils.report.attachment(result_report.readlines(), os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if dp2_job_epub3_to_html.status == "DONE" else "ERROR")

        if dp2_job_epub3_to_html.status != "DONE":
            self.utils.report.error("Klarte ikke å konvertere boken")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return

        html_dir = os.path.join(dp2_job_epub3_to_html.dir_output, "output-dir", epub.identifier())
        html_file = os.path.join(html_dir, epub.identifier() + ".xhtml")

        if not os.path.isdir(html_dir):
            self.utils.report.info("Finner ikke den konverterte boken. Kanskje filnavnet er forskjellig fra IDen?")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return


        # ---------- clean up nordic html ----------

        clean_html_obj = tempfile.NamedTemporaryFile()
        clean_html = clean_html_obj.name

        xslt = Xslt(self, stylesheet=os.path.join(NordicToNlbpub.xslt_dir, NordicToNlbpub.uid, "nordic-cleanup.xsl"),
                          source=html_file,
                          target=clean_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return

        shutil.copy(clean_html, html_file)


        # ---------- convert from html to generic epub ----------

        self.utils.report.info("Legger til EPUB-filer (OPF, NAV, container.xml, mediatype)...")
        nlbpub_tempdir_obj = tempfile.TemporaryDirectory()
        nlbpub_tempdir = nlbpub_tempdir_obj.name

        nlbpub = Epub.from_html(self, html_dir, nlbpub_tempdir)
        if nlbpub == None:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return


        # ---------- save EPUB ----------

        self.utils.report.info("Boken ble konvertert. Kopierer til NLBPUB-arkiv.")

        archived_path = self.utils.filesystem.storeBook(nlbpub.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i NLBPUB-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle


if __name__ == "__main__":
    NordicToNlbpub().run()
