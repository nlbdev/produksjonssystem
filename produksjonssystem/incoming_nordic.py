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
        if self.first_job:
            try:
                # start engine if it's not started already
                process = self.utils.filesystem.run([self.dp2_cli, "help"], shell=True)
                
            except subprocess.TimeoutExpired as e:
                self.utils.report.info("Oppstart av Pipeline 2 tok for lang tid og ble derfor stoppet.")
                
            except subprocess.CalledProcessError as e:
                self.utils.report.debug("En feil oppstod når Pipeline 2 startet. Vi venter noen sekunder og håper det går bra alikevel...")
                time.sleep(5)
            
            self.first_job = False
        
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
        
        job_dir  = os.path.join(workspace_dir, "nordic-epub3-validate/")
        os.makedirs(job_dir)

        result_dir = os.path.join(job_dir, "result/")
        
        job_id = None
        result_status = None
        
        try:
            self.utils.report.info("Validerer EPUB...")
            process = self.utils.filesystem.run([self.dp2_cli, "nordic-epub3-validate", "--epub", book_file, "--output", result_dir, "-p"])
            
            # get dp2 job id
            job_id = None
            for line in process.stdout.decode("utf-8").split("\n"):
                # look for: Job {id} sent to the server
                m = re.match("^Job (.*) sent to the server$", line)
                if m:
                    job_id = m.group(1)
                    break
            assert job_id, "Could not find the job ID for the validation job"
            
            # get validation log (the run method will log stdout/stderr as debug output)
            process = self.utils.filesystem.run([self.dp2_cli, "log", job_id])
            
            # get validation status
            process = self.utils.filesystem.run([self.dp2_cli, "status", job_id])
            result_status = None
            for line in process.stdout.decode("utf-8").split("\n"):
                # look for: Job {id} sent to the server
                m = re.match("^Status: (.*)$", line)
                if m:
                    result_status = m.group(1)
                    break
            assert result_status, "Klarte ikke å finne jobb-status for validerings-jobben"
            self.utils.report.debug("Pipeline 2 status: " + result_status)
            
            # get validation report
            with open(os.path.join(result_dir, "html-report/report.xhtml"), 'r') as result_report:
                self.utils.report.attachment(result_report.readlines(), os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if result_status == "DONE" else "ERROR")
            
        except subprocess.TimeoutExpired as e:
            self.utils.report.error("Validering av " + book_id + " tok for lang tid og ble derfor stoppet.")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
            
        finally:
            if job_id:
                try:
                    process = self.utils.filesystem.run([self.dp2_cli, "delete", job_id])
                except subprocess.TimeoutExpired as e:
                    self.utils.report.warn("Klarte ikke å slette Pipeline 2 jobb med ID " + job_id)
        
        if result_status != "DONE":
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
