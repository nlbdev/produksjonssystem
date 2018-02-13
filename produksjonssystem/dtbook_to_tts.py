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
from core.utils.xslt import Xslt
from update_metadata import UpdateMetadata
from core.utils.daisy_pipeline import DaisyPipelineJob

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class DtbookToTts(Pipeline):
    uid = "dtbook-to-tts"
    title = "DTBook til TTS"
    
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
        dtbook_dir = self.book["source"]
        
        # enkel sjekk av at dette er en DTBook
        if not os.path.isdir(dtbook_dir):
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        identifier = os.path.basename(os.path.normpath(dtbook_dir))
        dtbook_file = os.path.join(dtbook_dir, identifier + ".xml")
        
        if not os.path.isfile(dtbook_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på mappenavn.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        
        # ---------- lag en kopi av DTBooken ----------
        
        self.utils.report.info("Lager kopi av EPUB...")
        tts_dtbook_dir_obj = tempfile.TemporaryDirectory()
        tts_dtbook_dir = tts_dtbook_dir_obj.name
        self.utils.filesystem.copy(dtbook_dir, tts_dtbook_dir)
        dtbook_dir = tts_dtbook_dir
        
        dtbook_file = os.path.join(dtbook_dir, identifier + ".xml")
        
        
        # ---------- gjør tilpasninger i DTBook ----------
        
        temp_dtbook_obj = tempfile.NamedTemporaryFile()
        temp_dtbook = temp_dtbook_obj.name
        self.utils.report.debug("prepare-for-tts.xsl")
        self.utils.report.debug("    source = " + dtbook_file)
        self.utils.report.debug("    target = " + temp_dtbook)
        xslt = Xslt(self, stylesheet=os.path.join(DtbookToTts.xslt_dir, DtbookToTts.uid, "prepare-for-tts.xsl"),
                          source=dtbook_file,
                          target=temp_dtbook)
        if not xslt.success:
            return False
        
        new_identifier = None
        dtbook_xml = ElementTree.parse(temp_dtbook).getroot()
        metadata = dtbook_xml.findall('{http://www.daisy.org/z3986/2005/dtbook/}head')[0]
        meta = metadata.findall("*")
        for m in meta:
            if m.attrib["name"] == "dtb:uid":
                new_identifier = m.attrib["content"]
        if not new_identifier:
            self.utils.report.error("Finner ikke det nye boknummeret")
            self.utils.report.title = self.title + ": " + identifier + " feilet 😭👎"
            return
        shutil.copy(temp_dtbook, os.path.join(dtbook_dir, new_identifier + ".xml"))
        if new_identifier != identifier:
            os.remove(dtbook_file)
        
        
        # ---------- lagre DTBook ----------
        
        self.utils.report.info("Boken ble konvertert. Kopierer til DTBook-TTS-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(dtbook_dir, new_identifier)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(new_identifier + " ble lagt til i DTBook-TTS-arkivet.")
        self.utils.report.title = self.title + ": " + identifier + " ble konvertert 👍😄"


if __name__ == "__main__":
    DtbookToTts().run()
