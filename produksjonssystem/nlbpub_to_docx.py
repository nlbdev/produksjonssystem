#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import sys
import time
import shutil
import pathlib
import tempfile
import subprocess

from lxml import etree as ElementTree
from datetime import datetime, timezone
from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from update_metadata import UpdateMetadata
from nlbpub_to_html import NlbpubToHtml

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)

class NLBpubToDocx(Pipeline):
    uid = "nlbpub-to-docx"
    title = "NLBPUB til DOCX"
    labels = [ "e-bok" ]
    publication_format = "XHTML"

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

        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass

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

        #self.utils.report.info("Oppdaterer metadata...")
        #updated = UpdateMetadata.update(self, temp_epub, publication_format="XHTML")
        #if isinstance(updated, bool) and updated == False:
        #    self.utils.report.title = self.title + ": " + temp_epub.identifier() + " feilet 😭👎"
        #    return


        # ---------- gjør tilpasninger i HTML-fila med XSLT ----------

        opf_path = temp_epub.opf_path()
        if not opf_path:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne OPF-fila i EPUBen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return
        opf_path = os.path.join(temp_epubdir, opf_path)
        opf_xml = ElementTree.parse(opf_path).getroot()

        html_file = opf_xml.xpath("/*/*[local-name()='manifest']/*[@id = /*/*[local-name()='spine']/*[1]/@idref]/@href")
        html_file = html_file[0] if html_file else None
        if not html_file:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila i OPFen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return
        html_file = os.path.join(os.path.dirname(opf_path), html_file)
        if not os.path.isfile(html_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return

        temp_html_obj = tempfile.NamedTemporaryFile()
        temp_html = temp_html_obj.name

        xslt = Xslt(self, stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToHtml.uid, "prepare-for-html.xsl"),
                          source=html_file,
                          target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return

        html_dir = os.path.dirname(opf_path)

        shutil.copy(temp_html, html_file)


        # ---------- hent nytt boknummer fra /html/head/meta[@name='dc:identifier'] og bruk som filnavn ----------

        html_xml = ElementTree.parse(html_file).getroot()
        result_identifier = html_xml.xpath("/*/*[local-name()='head']/*[@name='dc:identifier']")
        result_identifier = result_identifier[0].attrib["content"] if result_identifier and "content" in result_identifier[0].attrib else None
        if not result_identifier:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne boknummer i ny HTML-fil.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return


        shutil.copy(os.path.join(Xslt.xslt_dir, NlbpubToHtml.uid, "NLB_logo.jpg"),
                    os.path.join(html_dir, "NLB_logo.jpg"))

        shutil.copy(os.path.join(Xslt.xslt_dir, NlbpubToHtml.uid, "default.css"),
                    os.path.join(html_dir, "default.css"))

        pathlib.Path(os.path.join(self.dir_out,result_identifier)).mkdir(parents=True, exist_ok=True)

        try:
            self.utils.report.info("Konverterer fra XHTML til DOCX...")
            process = self.utils.filesystem.run(["/usr/bin/ebook-convert",
                                                html_file,
                                                os.path.join(self.dir_out,result_identifier,result_identifier + ".docx")])
                                                #"--insert-blank-line"])

            self.utils.report.info("Boken ble konvertert. Kopierer til DOCX-arkiv.")

        except subprocess.TimeoutExpired as e:
            self.utils.report.warn("Det tok for lang tid å konvertere " + epub.identifier() + " til DOCX, og Calibre-prosessen ble derfor stoppet.")

        except Exception:
            self.utils.report.warn("En feil oppstod ved konvertering til DOCX for " + epub.identifier())
            traceback.print_exc(e)

        #archived_path = self.utils.filesystem.storeBook(html_dir, result_identifier)
        UpdateMetadata.add_production_info(self, epub.identifier(), publication_format="XHTML")
        self.utils.report.attachment(None, os.path.join(self.dir_out,result_identifier), "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i DOCX-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle


if __name__ == "__main__":
    NLBpubToDocx().run()
