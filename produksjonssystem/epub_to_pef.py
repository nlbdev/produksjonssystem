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

class EpubToPef(Pipeline):
    title = "EPUB til PEF"
    
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
        
        self.utils.report.attachment(None, self.book["source"], "DEBUG")
        
        # Bruk sub-mapper for å unngå overskriving og filnavn-kollisjoner
        workspace_dir_object = tempfile.TemporaryDirectory()
        workspace_dir = workspace_dir_object.name
        
        book_id = self.book["name"]
        
        if not os.path.isdir(self.book["source"]):
            self.utils.report.info(book_id + " er ikke en mappe.")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
        
        if not os.path.isfile(os.path.join(self.book["source"], "EPUB/package.opf")):
            self.utils.report.info(book_id + ": EPUB/package.opf eksisterer ikke.")
            self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
            return
        
        # kopier boka til en midlertidig mappe
        book_dir = os.path.join(workspace_dir, book_id)
        self.utils.filesystem.copy(self.book["source"], book_dir)
        
        # lag en zippet versjon av EPUBen også
        book_file = os.path.join(workspace_dir, book_id + ".epub")
        self.utils.report.info("Pakker sammen " + book_id + "...")
        self.utils.epub.zip(book_dir, book_file)
        
        braille_versions = {
            "fullskrift": [ "--braille-standard", "(dots:6)(grade:0)", "--line-spacing", "single", "--duplex", "true" ],
            "kortskrift": [ "--braille-standard", "(dots:6)(grade:2)", "--line-spacing", "single", "--duplex", "true" ],
            "lesetrening": [ "--braille-standard", "(dots:6)(grade:0)", "--line-spacing", "double", "--duplex", "false" ]
        }
        for braille_version in braille_versions:
            job_dir  = os.path.join(workspace_dir, "epub3-to-pef", braille_version)
            os.makedirs(job_dir)

            result_dir = os.path.join(job_dir, "result/")
            
            job_id = None
            result_status = None
            pef_dir = None
            
            try:
                self.utils.report.info("Konverterer fra EPUB til PEF (" + braille_version + ")...")
                cmd = [self.dp2_cli, "nlb:epub3-to-pef", "--epub", book_file]
                cmd.extend(braille_versions[braille_version])
                cmd.extend([ "--output", result_dir, "-p"])
                process = self.utils.filesystem.run(cmd)
                
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
                if os.path.isdir(os.path.join(result_dir, "preview-output-dir")):
                    self.utils.filesystem.copy(os.path.join(result_dir, "preview-output-dir"), os.path.join(self.utils.report.reportDir(), "preview-" + braille_version))
                    self.utils.report.attachment(None, os.path.join(self.utils.report.reportDir(), "preview-" + braille_version + "/" + book_id + ".pef.html"), "SUCCESS" if result_status == "DONE" else "ERROR")
                
                pef_dir = os.path.join(result_dir, "pef-output-dir")
                
            except subprocess.TimeoutExpired as e:
                self.utils.report.info("Konvertering av " + book_id + " fra EPUB til PEF tok for lang tid og ble derfor stoppet.")
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
            
            if not os.path.isdir(pef_dir):
                self.utils.report.info("Finner ikke den konverterte boken. Kanskje filnavnet er forskjellig fra IDen?")
                self.utils.report.title = self.title + ": " + book_id + " feilet 😭👎"
                return
            
            self.utils.report.info("Boken ble konvertert. Kopierer til PEF-arkiv.")
            
            archived_path = self.utils.filesystem.storeBook(pef_dir, book_id, subdir=braille_version)
            self.utils.report.attachment(None, archived_path, "DEBUG")
            self.utils.report.info(book_id + " ble lagt til i arkivet under PEF/" + braille_version + ".")
        
        self.utils.report.title = self.title + ": " + book_id + " ble konvertert 👍😄"


if __name__ == "__main__":
    EpubToPef().run()
