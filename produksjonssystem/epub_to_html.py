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

class EpubToHtml(Pipeline):
    uid = "epub-to-html"
    title = "EPUB til HTML"
    
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
        
        html_dir = None
        
        self.utils.report.info("Konverterer fra EPUB til HTML...")
        dp2_job = DaisyPipelineJob(self, "nordic-epub3-to-html", { "epub": epub.asFile() })
        
        # get conversion report
        report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
        if os.path.isfile(report_file):
            with open(report_file, 'r') as result_report:
                self.utils.report.attachment(result_report.readlines(), os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if dp2_job.status == "DONE" else "ERROR")
        
        if dp2_job.status != "DONE":
            self.utils.report.error("Klarte ikke å konvertere boken")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        
        html_dir = os.path.join(dp2_job.dir_output, "output-dir", epub.identifier())
        
        if not os.path.isdir(html_dir):
            self.utils.report.error("Finner ikke den konverterte boken: " + html_dir)
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        
        self.utils.report.info("Boken ble konvertert. Kopierer til HTML-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(html_dir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i HTML-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄"


if __name__ == "__main__":
    EpubToHtml().run()
