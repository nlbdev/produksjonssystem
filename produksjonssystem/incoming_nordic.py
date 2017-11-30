#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import tempfile
import time
import subprocess
import shutil
import re
import json
import logging

from core.utils.epub import Epub
from core.utils.daisy_pipeline import DaisyPipelineJob

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class IncomingNordic(Pipeline):
    uid = "incoming-nordic"
    title = "Validering av Nordisk EPUB 3"
    
    dp2_home = os.getenv("PIPELINE2_HOME", "/opt/daisy-pipeline2")
    dp2_cli = dp2_home + "/cli/dp2"
    saxon_cli = "java -jar " + os.path.join(dp2_home, "system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar")
    ace_cli = "/usr/bin/ace"
    
    first_job = True # Will be set to false after first job is triggered
    
    def on_book_deleted(self):
        self.utils.report.should_email = False
    
    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: "+self.book['name'])
        self.on_book()
    
    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: "+self.book['name'])
        self.on_book()
    
    def on_book(self):
        epub = Epub(self, self.book["source"])
        
        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        self.utils.report.info("Validerer EPUB...")
        dp2_job = DaisyPipelineJob(self, "nordic-epub3-validate", { "epub": epub.asFile() })
        
        # get validation report
        report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
        if os.path.isfile(report_file):
            with open(report_file, 'r') as result_report:
                self.utils.report.attachment(result_report.readlines(), os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if dp2_job.status == "DONE" else "ERROR")
        
        if dp2_job.status != "DONE":
            self.utils.report.error("Klarte ikke å validere boken")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        
        try:
            self.utils.report.info("Genererer ACE-rapport...")
            ace_dir = os.path.join(self.utils.report.reportDir(), "accessibility-report")
            process = self.utils.filesystem.run([self.ace_cli, "-o", ace_dir, epub.asFile()])
            
            # attach report
            ace_status = None
            with open(os.path.join(ace_dir, "report.json")) as json_report:
                ace_status = json.load(json_report)["earl:result"]["earl:outcome"]
            if ace_status == "pass":
                ace_status = "SUCCESS"
            else:
                ace_status = "WARN"
            self.utils.report.attachment(None, os.path.join(ace_dir, "report.html"), ace_status)
            
        except subprocess.TimeoutExpired as e:
            self.utils.report.warn("Det tok for lang tid å lage ACE-rapporten for " + epub.identifier() + ", og prosessen ble derfor stoppet.")
        
        except Exception:
            logging.exception("En feil oppstod ved produksjon av ACE-rapporten for " + epub.identifier())
            self.utils.report.warn("En feil oppstod ved produksjon av ACE-rapporten for " + epub.identifier())
        
        self.utils.report.info("Boken er valid. Kopierer til EPUB master-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(epub.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.success(epub.identifier()+" ble lagt til i master-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " er valid 👍😄"
        self.utils.filesystem.deleteSource()
        
        # TODO:
        # - self.utils.epubCheck på mottatt EPUB
        # - EPUB 3 Accessibility Checker på mottatt EPUB
        # - separat pipeline(?):
        #   - Konverter til NLBPUB
        #       if self.utils.epub.meta(book_dir, "nordic:guidelines") == "2015-1":
        #           nordic-epub3-to-nlbpub (= preprocessing + epub-to-nlbpub ?)
        #       else:
        #           epub-to-nlbpub
        #   - self.utils.epubCheck på NLBPUB
        #   - EPUB 3 Accessibility Checker på NLBPUB
        # - separat pipeline: EPUB til DTBook
        # - separat pipeline: EPUB til HTML
        # - separat pipeline: EPUB til innlesnings-EPUB
        # - separat pipeline: Zippet versjon av EPUB-master


if __name__ == "__main__":
    IncomingNordic().run()
