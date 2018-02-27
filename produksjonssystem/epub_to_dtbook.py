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
from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from update_metadata import UpdateMetadata
from core.utils.schematron import Schematron
from core.utils.daisy_pipeline import DaisyPipelineJob

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class EpubToDtbook(Pipeline):
    uid = "epub-to-dtbook"
    title = "EPUB til DTBook"
    
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
        
        self.utils.report.info("Lager kopi av EPUB...")
        nordic_epubdir_obj = tempfile.TemporaryDirectory()
        nordic_epubdir = nordic_epubdir_obj.name
        self.utils.filesystem.copy(epub.asDir(), nordic_epubdir)
        nordic_epub = Epub(self, nordic_epubdir)
        
        
        # ---------- oppdater metadata ----------
        
        self.utils.report.info("Oppdaterer metadata...")
        updated = UpdateMetadata.update(self, nordic_epub, publication_format="DAISY 2.02")
        if isinstance(updated, bool) and updated == False:
            self.utils.report.title = self.title + ": " + nordic_epub.identifier() + " feilet 😭👎"
            return
        
        
        # ---------- konverter nordisk EPUB til nordisk DTBook ----------
        
        self.utils.report.info("Konverterer fra EPUB til DTBook...")
        dtbook_dir = None
        dp2_job = DaisyPipelineJob(self, "nordic-epub3-to-dtbook", { "epub": nordic_epub.asFile(), "fail-on-error": "false" })
        
        
        # ---------- hent rapport fra konvertering ----------
        
        self.utils.report.info("Henter rapport fra konvertering...")
        report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
        if os.path.isfile(report_file):
            with open(report_file, 'r') as result_report:
                self.utils.report.attachment(result_report.readlines(), os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if dp2_job.status == "DONE" else "ERROR")
        
        if dp2_job.status != "DONE":
            self.utils.report.error("Klarte ikke å konvertere boken")
            self.utils.report.title = self.title + ": " + nordic_epub.identifier() + " feilet 😭👎"
            return
        
        dtbook_dir = os.path.join(dp2_job.dir_output, "output-dir", nordic_epub.identifier())
        dtbook_file = os.path.join(dp2_job.dir_output, "output-dir", nordic_epub.identifier(), nordic_epub.identifier() + ".xml")
        
        if not os.path.isdir(dtbook_dir):
            self.utils.report.error("Finner ikke den konverterte boken: " + dtbook_dir)
            self.utils.report.title = self.title + ": " + nordic_epub.identifier() + " feilet 😭👎"
            return
        
        if not os.path.isfile(dtbook_file):
            self.utils.report.error("Finner ikke den konverterte boken: " + dtbook_file)
            self.utils.report.title = self.title + ": " + nordic_epub.identifier() + " feilet 😭👎"
            return
        
        
        # ---------- gjør tilpasninger i DTBook ----------
        
        temp_dtbook_obj = tempfile.NamedTemporaryFile()
        temp_dtbook = temp_dtbook_obj.name
        self.utils.report.debug("dtbook-cleanup.xsl")
        self.utils.report.debug("    source = " + dtbook_file)
        self.utils.report.debug("    target = " + temp_dtbook)
        xslt = Xslt(self, stylesheet=os.path.join(Xslt.xslt_dir, EpubToDtbook.uid, "dtbook-cleanup.xsl"),
                          source=dtbook_file,
                          target=temp_dtbook)
        if not xslt.success:
            return False
        
        shutil.copy(temp_dtbook, dtbook_file)
        
        
        # ---------- valider resultat ----------
        
        self.utils.report.info("Validerer DTBook")
        sch = Schematron(self, schematron=os.path.join(Xslt.xslt_dir, EpubToDtbook.uid, "validate-dtbook.sch"),
                               source=dtbook_file)
        if not sch.success:
            self.utils.report.error("Validering av DTBook feilet")
            return False
        
        
        # ---------- lagre DTBook ----------
        
        self.utils.report.info("Boken ble konvertert. Kopierer til DTBook-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(dtbook_dir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i DTBook-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄"


if __name__ == "__main__":
    EpubToDtbook().run()
