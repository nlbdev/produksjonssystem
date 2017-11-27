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

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class NordicToNlbpub(Pipeline):
    title = "Nordisk EPUB til NLBPUB"
    
    dp2_home = os.getenv("PIPELINE2_HOME", "/opt/daisy-pipeline2")
    dp2_cli = dp2_home + "/cli/dp2"
    saxon_cli = "java -jar " + os.path.join(dp2_home, "system/framework/org.daisy.libs.saxon-he-9.5.1.5.jar")
    
    first_job = True # Will be set to false after first job is triggered
    
    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB master slettet: " + book_id
    
    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        self.on_book()
    
    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
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
        
        job_dir  = os.path.join(workspace_dir, "epub3-to-nlbpub/")
        os.makedirs(job_dir)
        
        
        # ---------- step 1: convert from nordic epub to nordic html ----------
        
        result_dir = os.path.join(job_dir, "result-nordic-html/")
        
        job_id = None
        result_status = None
        html_dir = None
        html_file = None
        
        try:
            self.utils.report.info("Konverterer fra Nordisk EPUB 3 til Nordisk HTML 5...")
            process = self.utils.filesystem.run([self.dp2_cli, "nordic-epub3-to-html", "--epub", book_file, "--fail-on-error", "true", "--output", result_dir, "-p"])
            
            # get dp2 job id
            job_id = None
            for line in process.stdout.decode("utf-8").split("\n"):
                # look for: Job {id} sent to the server
                m = re.match("^Job (.*) sent to the server$", line)
                if m:
                    job_id = m.group(1)
                    break
            assert job_id, "Could not find the job ID for the conversion job"
            
            # get conversion log (the run method will log stdout/stderr as debug output)
            process = self.utils.filesystem.run([self.dp2_cli, "log", job_id])
            
            # get conversion status
            process = self.utils.filesystem.run([self.dp2_cli, "status", job_id])
            result_status = None
            for line in process.stdout.decode("utf-8").split("\n"):
                # look for: Job {id} sent to the server
                m = re.match("^Status: (.*)$", line)
                if m:
                    result_status = m.group(1)
                    break
            assert result_status, "Klarte ikke å finne jobb-status for konverterings-jobben"
            self.utils.report.debug("Pipeline 2 status: " + result_status)
            
            # get conversion report
            with open(os.path.join(result_dir, "html-report/report.xhtml"), 'r') as result_report:
                self.utils.report.attachment(result_report.readlines(), os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if result_status == "DONE" else "ERROR")
            
            html_dir = os.path.join(result_dir, "output-dir", book_id)
            html_file = os.path.join(html_dir, book_id + ".xhtml")
            
        except subprocess.TimeoutExpired as e:
            self.utils.report.info("Konvertering av " + book_id + " fra Nordic EPUB til NLBPUB tok for lang tid og ble derfor stoppet.")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
            
        finally:
            if job_id:
                try:
                    process = self.utils.filesystem.run([self.dp2_cli, "delete", job_id])
                except subprocess.TimeoutExpired as e:
                    self.utils.report.warn("Klarte ikke å slette Pipeline 2 jobb med ID " + job_id)
                    pass
        
        if result_status != "DONE":
            self.utils.report.info("Klarte ikke å konvertere boken")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
        
        if not os.path.isdir(html_dir):
            self.utils.report.info("Finner ikke den konverterte boken. Kanskje filnavnet er forskjellig fra IDen?")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
        
        
        # ---------- step 2: convert from nordic html to generic epub ----------
        
        result_dir = os.path.join(job_dir, "result-generic-epub/")
        
        job_id = None
        result_status = None
        generic_epub = None
        
        try:
            self.utils.report.info("Konverterer fra Nordic HTML5 til generisk EPUB3...")
            process = self.utils.filesystem.run([self.dp2_cli, "html-to-epub3", "--html", html_file, "--metadata", html_file, "--output", result_dir, "-p"])
            
            # get dp2 job id
            job_id = None
            for line in process.stdout.decode("utf-8").split("\n"):
                # look for: Job {id} sent to the server
                m = re.match("^Job (.*) sent to the server$", line)
                if m:
                    job_id = m.group(1)
                    break
            assert job_id, "Could not find the job ID for the conversion job"
            
            # get conversion log (the run method will log stdout/stderr as debug output)
            process = self.utils.filesystem.run([self.dp2_cli, "log", job_id])
            
            # get conversion status
            process = self.utils.filesystem.run([self.dp2_cli, "status", job_id])
            result_status = None
            for line in process.stdout.decode("utf-8").split("\n"):
                # look for: Job {id} sent to the server
                m = re.match("^Status: (.*)$", line)
                if m:
                    result_status = m.group(1)
                    break
            assert result_status, "Klarte ikke å finne jobb-status for konverterings-jobben"
            self.utils.report.debug("Pipeline 2 status: " + result_status)
            
            generic_epub = os.path.join(result_dir, "output-dir", book_id + ".epub")
            
        except subprocess.TimeoutExpired as e:
            self.utils.report.info("Konvertering av " + book_id + " fra Nordic HTML5 til generisk EPUB3 tok for lang tid og ble derfor stoppet.")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
            
        finally:
            if job_id:
                try:
                    process = self.utils.filesystem.run([self.dp2_cli, "delete", job_id])
                except subprocess.TimeoutExpired as e:
                    self.utils.report.warn("Klarte ikke å slette Pipeline 2 jobb med ID " + job_id)
                    pass
        
        if result_status != "DONE":
            self.utils.report.info("Klarte ikke å konvertere boken")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
        
        if not os.path.isdir(html_dir):
            self.utils.report.info("Finner ikke den konverterte boken. Kanskje filnavnet er forskjellig fra IDen?")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
        
        
        # ---------- step 3: unzip EPUB
        
        result_dir = os.path.join(job_dir, "unzipped-nlbpub/")
        self.utils.report.info("Pakker ut EPUB")
        os.makedirs(result_dir)
        self.utils.filesystem.unzip(generic_epub, result_dir)
        
        
        self.utils.report.info("Boken ble konvertert. Kopierer til NLBPUB-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(result_dir, book_id)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(book_id + " ble lagt til i NLBPUB-arkivet.")
        self.utils.report.title = self.title + ": " + book_id + " ble konvertert 👍😄"


if __name__ == "__main__":
    EpubToHtml().run()
