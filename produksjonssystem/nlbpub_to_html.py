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

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class NlbpubToHtml(Pipeline):
    uid = "nlbpub-to-html"
    title = "NLBPUB til HTML"
    
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
        
        
        # ---------- gjør tilpasninger i HTML-fila med XSLT ----------
        
        opf_path = temp_epub.opf_path()
        if not opf_path:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne OPF-fila i EPUBen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        opf_path = os.path.join(temp_epubdir, opf_path)
        opf_xml = ElementTree.parse(opf_path).getroot()
        
        html_file = opf_xml.xpath("/*/*[local-name()='manifest']/*[@id = /*/*[local-name()='spine']/*[1]/@idref]/@href")
        html_file = html_file[0] if html_file else None
        if not html_file:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila i OPFen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        html_file = os.path.join(os.path.dirname(opf_path), html_file)
        if not os.path.isfile(html_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        temp_html_obj = tempfile.NamedTemporaryFile()
        temp_html = temp_html_obj.name
        
        self.utils.report.info("Tilpasser innhold for e-tekst...")
        xslt = Xslt(self, stylesheet=os.path.join(NlbpubToHtml.xslt_dir, NlbpubToHtml.uid, "prepare-for-html.xsl"),
                          source=html_file,
                          target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎"
            return
        shutil.copy(temp_html, html_file)
        
        
        # ---------- hent nytt boknummer fra /html/head/meta[@name='dc:identifier'] og bruk som filnavn ----------
        
        html_xml = ElementTree.parse(temp_html).getroot()
        result_identifier = html_xml.xpath("/*/*[local-name()='head']/*[@name='dc:identifier']")
        result_identifier = result_identifier[0].attrib["content"] if result_identifier and "content" in result_identifier[0].attrib else None
        if not result_identifier:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne boknummer i ny HTML-fil.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return
        
        shutil.copy(html_file, temp_html)
        os.remove(html_file)
        html_file = os.path.join(os.path.dirname(html_file), result_identifier + ".html") # Bruk html istedenfor xhtml når det ikke er en EPUB
        shutil.copy(temp_html, html_file)
        # TODO: sett inn HTML5 doctype: <!DOCTYPE html>
        
        html_dir = os.path.dirname(opf_path)
        
        shutil.copy(os.path.join(NlbpubToHtml.xslt_dir, NlbpubToHtml.uid, "NLB_logo.jpg"),
                    os.path.join(html_dir, "NLB_logo.jpg"))
        
        shutil.copy(os.path.join(NlbpubToHtml.xslt_dir, NlbpubToHtml.uid, "default.css"),
                    os.path.join(html_dir, "default.css"))
        
        
        # ---------- slett EPUB-spesifikke filer ----------
        
        items = opf_xml.xpath("/*/*[local-name()='manifest']/*")
        for item in items:
            delete = False
            
            if "properties" in item.attrib and "nav" in re.split(r'\s+', item.attrib["properties"]):
                delete = True
            
            if "media-type" in item.attrib:
                if item.attrib["media-type"].startswith("audio/"):
                    delete = True
                elif item.attrib["media-type"] == "application/smil+xml":
                    delete = True
            
            if not delete or not "href" in item.attrib:
                continue
            
            fullpath = os.path.join(os.path.dirname(opf_path), item.attrib["href"])
            os.remove(fullpath)
        os.remove(opf_path)
        
        
        # ---------- lagre HTML-filsett ----------
        
        self.utils.report.info("Boken ble konvertert. Kopierer til HTML-arkiv.")
        
        archived_path = self.utils.filesystem.storeBook(html_dir, result_identifier)
        UpdateMetadata.add_production_info(self, epub.identifier(), publication_format="XHTML")
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i HTML-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄"


if __name__ == "__main__":
    NlbpubToHtml().run()
