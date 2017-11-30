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
        # Bruk sub-mapper for å unngå overskriving og filnavn-kollisjoner
        workspace_dir_object = tempfile.TemporaryDirectory()
        workspace_dir = workspace_dir_object.name
        
        book_dir = os.path.join(workspace_dir, "book")
        self.utils.filesystem.unzip(self.book["source"], book_dir)
        
        # sjekk at dette er en EPUB
        if not self.utils.epub.isepub(self.book["source"]):
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        book_id = self.utils.epub.meta(book_dir, "dc:identifier")
        
        if not book_id:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        book_file = os.path.join(workspace_dir, book_id + ".epub")
        
        # lag en zippet versjon av EPUBen også
        self.utils.report.info("Pakker sammen " + book_id + "...")
        self.utils.epub.zip(book_dir, book_file)
        
        self.utils.report.info("Validerer EPUB...")
        dp2_job = DaisyPipelineJob(self, "nordic-epub3-validate", { "epub": book_file })
        
        # get validation report
        report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
        if os.path.isfile(report_file):
            with open(report_file, 'r') as result_report:
                self.utils.report.attachment(result_report.readlines(), os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if dp2_job.status == "DONE" else "ERROR")
        
        if dp2_job.status != "DONE":
            self.utils.report.error("Klarte ikke å validere boken")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
        
        try:
            self.utils.report.info("Genererer ACE-rapport...")
            ace_dir = os.path.join(self.utils.report.reportDir(), "accessibility-report")
            process = self.utils.filesystem.run([self.ace_cli, "-o", ace_dir, book_file])
            
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
            self.utils.report.warn("Det tok for lang tid å lage ACE-rapporten for " + book_id + ", og prosessen ble derfor stoppet.")
        
        except Exception:
            logging.exception("En feil oppstod ved produksjon av ACE-rapporten for " + book_id)
            self.utils.report.warn("En feil oppstod ved produksjon av ACE-rapporten for " + book_id)
        
        self.utils.report.info("Boken er valid. Kopierer til EPUB master-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(book_dir, book_id)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.filesystem.deleteSource()
        self.utils.report.success(book_id+" ble lagt til i master-arkivet.")
        self.utils.report.title = self.title + ": " + book_id + " er valid 👍😄"
        
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
