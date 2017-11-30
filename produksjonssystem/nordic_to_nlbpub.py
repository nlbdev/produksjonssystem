#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import tempfile
import time
from datetime import datetime, timezone
import subprocess
import shutil
import re

from core.utils.epub import Epub
from core.utils.daisy_pipeline import DaisyPipelineJob

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class NordicToNlbpub(Pipeline):
    uid = "nordic-epub-to-nlbpub"
    title = "Nordisk EPUB til NLBPUB"
    
    dp2_home = os.getenv("PIPELINE2_HOME", "/opt/daisy-pipeline2")
    dp2_cli = dp2_home + "/cli/dp2"
    saxon_cli = "java -jar " + os.path.join(dp2_home, "system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar")
    
    first_job = True # Will be set to false after first job is triggered
    
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
        
        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        # ---------- step 1: convert from nordic epub to nordic html ----------
        
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
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        
        html_dir = os.path.join(dp2_job_epub3_to_html.dir_output, "output-dir", epub.identifier())
        html_file = os.path.join(html_dir, epub.identifier() + ".xhtml")
        
        if not os.path.isdir(html_dir):
            self.utils.report.info("Finner ikke den konverterte boken. Kanskje filnavnet er forskjellig fra IDen?")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        
        
        # TODO: XSLT-steg her for å rydde opp nordisk EPUB
        
        
        # ---------- step 2: convert from nordic html to generic epub ----------
        
        self.utils.report.info("Konverterer fra Nordic HTML5 til generisk EPUB3...")
        dp2_job_html_to_epub3 = DaisyPipelineJob(self, "html-to-epub3", { "html": html_file, "metadata": html_file })
        
        if dp2_job_html_to_epub3.status != "DONE":
            self.utils.report.error("Klarte ikke å konvertere boken")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        
        nlbpub_path = os.path.join(dp2_job_html_to_epub3.dir_output, "output-dir", epub.identifier() + ".epub")
        nlbpub = Epub(self, nlbpub_path)
        
        if not nlbpub.isepub():
            self.utils.report.error("Resultatet ble ikke en gyldig EPUB")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        
        # ---------- step 3: unzip and save EPUB
        
        self.utils.report.info("Boken ble konvertert. Kopierer til NLBPUB-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(nlbpub.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i NLBPUB-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄"


if __name__ == "__main__":
    EpubToHtml().run()
