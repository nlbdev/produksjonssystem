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
from update_metadata import UpdateMetadata
from core.utils.daisy_pipeline import DaisyPipelineJob

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class EpubToPef(Pipeline):
    uid = "epub-to-pef"
    title = "EPUB til PEF"
    
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
        
        
        # ---------- lag en kopi av EPUBen ----------
        
        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_epubdir)
        temp_epub = Epub(self, temp_epubdir)
        
        
        # ---------- oppdater metadata ----------
        
        self.utils.report.info("Oppdaterer metadata...")
        updated = UpdateMetadata.update(self, temp_epub, publication_format="Braille")
        if isinstance(updated, bool) and updated == False:
            self.utils.report.title = self.title + ": " + temp_epub.identifier() + " feilet 😭👎"
            return
        
        
        # ---------- konverter til PEF ----------
        
        braille_arguments = {
            "fullskrift": {
                "epub": temp_epub.asFile(),
                "braille-standard": "(dots:6)(grade:0)",
                "line-spacing": "single",
                "duplex": "true"
            },
            "kortskrift": {
                "epub": temp_epub.asFile(),
                "braille-standard": "(dots:6)(grade:2)",
                "line-spacing": "single",
                "duplex": "true"
            },
            "lesetrening": {
                "epub": temp_epub.asFile(),
                "braille-standard": "(dots:6)(grade:0)",
                "line-spacing": "double",
                "duplex": "false"
            }
        }
        for braille_version in braille_arguments:
            pef_dir = None
            
            self.utils.report.info("Konverterer fra EPUB til PEF (" + braille_version + ")...")
            dp2_job = DaisyPipelineJob(self, "nlb:epub3-to-pef", braille_arguments[braille_version])
            
            # get conversion report
            if os.path.isdir(os.path.join(dp2_job.dir_output, "preview-output-dir")):
                self.utils.filesystem.copy(os.path.join(dp2_job.dir_output, "preview-output-dir"), os.path.join(self.utils.report.reportDir(), "preview-" + braille_version))
                self.utils.report.attachment(None, os.path.join(self.utils.report.reportDir(), "preview-" + braille_version + "/" + temp_epub.identifier() + ".pef.html"), "SUCCESS" if dp2_job.status == "DONE" else "ERROR")
            
            if dp2_job.status != "DONE":
                self.utils.report.info("Klarte ikke å konvertere boken")
                self.utils.report.title = self.title + ": " + temp_epub.identifier() + " feilet 😭👎"
                return
            
            pef_dir = os.path.join(dp2_job.dir_output, "pef-output-dir")
            
            if not os.path.isdir(pef_dir):
                self.utils.report.info("Finner ikke den konverterte boken. Kanskje filnavnet er forskjellig fra IDen?")
                self.utils.report.title = self.title + ": " + temp_epub.identifier() + " feilet 😭👎"
                return
            
            self.utils.report.info("Boken ble konvertert. Kopierer til PEF-arkiv.")
            
            archived_path = self.utils.filesystem.storeBook(pef_dir, temp_epub.identifier(), subdir=braille_version)
            self.utils.report.attachment(None, archived_path, "DEBUG")
            self.utils.report.info(temp_epub.identifier() + " ble lagt til i arkivet under PEF/" + braille_version + ".")
        
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄"


if __name__ == "__main__":
    EpubToPef().run()
