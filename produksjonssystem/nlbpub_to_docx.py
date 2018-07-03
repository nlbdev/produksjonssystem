#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tempfile
import traceback
import subprocess

from lxml import etree as ElementTree
from core.pipeline import Pipeline
from core.utils.epub import Epub

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NLBpubToDocx(Pipeline):
    uid = "nlbpub-to-docx"
    title = "NLBPUB til DOCX"
    labels = ["e-bok"]
    publication_format = "XHTML"
    expected_processing_time = 43

    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "xslt"))

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB master slettet: " + self.book['name']
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")
        epub = Epub(self, self.book["source"])

        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass

        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        # ---------- lag en kopi av EPUBen ----------

        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_epubdir)
        temp_epub = Epub(self, temp_epubdir)

        opf_path = temp_epub.opf_path()
        if not opf_path:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne OPF-fila i EPUBen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False
        opf_path = os.path.join(temp_epubdir, opf_path)
        opf_xml = ElementTree.parse(opf_path).getroot()

        html_file = opf_xml.xpath("/*/*[local-name()='manifest']/*[@id = /*/*[local-name()='spine']/*[1]/@idref]/@href")
        html_file = html_file[0] if html_file else None
        if not html_file:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila i OPFen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False
        html_file = os.path.join(os.path.dirname(opf_path), html_file)
        if not os.path.isfile(html_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        # ---------- konverter HTML-fila til DOCX ----------

        temp_docxdir_obj = tempfile.TemporaryDirectory()
        temp_docxdir = temp_docxdir_obj.name

        try:
            self.utils.report.info("Konverterer fra XHTML til DOCX...")
            process = self.utils.filesystem.run(["/usr/bin/ebook-convert",
                                                 html_file,
                                                 os.path.join(temp_docxdir, epub.identifier() + ".docx"),
                                                 "--no-chapters-in-toc",
                                                 "--toc-threshold=0",
                                                 "--docx-page-size=a4",
                                                 "--insert-blank-line"])
            if process.returncode == 0:
                self.utils.report.info("Boken ble konvertert.")
            else:
                self.utils.report.error("En feil oppstod ved konvertering til DOCX for " + epub.identifier())
                self.pipeline.utils.report.debug(traceback.format_stack())
                self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
                return False

        except subprocess.TimeoutExpired:
            self.utils.report.error("Det tok for lang tid å konvertere " + epub.identifier() + " til DOCX, og Calibre-prosessen ble derfor stoppet.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        except Exception:
            self.utils.report.error("En feil oppstod ved konvertering til DOCX for " + epub.identifier())
            self.utils.report.info(traceback.format_exc(), preformatted=True)
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        archived_path = self.utils.filesystem.storeBook(temp_docxdir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i DOCX-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    NLBpubToDocx().run()
