#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import subprocess
import sys
import tempfile
import traceback

import re

from docx import Document
from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NLBpubToDocx(Pipeline):
    uid = "nlbpub-to-docx"
    title = "NLBPUB til DOCX"
    labels = ["e-bok", "Statped"]
    publication_format = "XHTML"
    expected_processing_time = 9

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

        # language must be exctracted from epub or else docx default language (nb) wil be used in the converted file
        language = ""
        try:
            language = " (" + epub.meta("dc:language") + ") "
        except Exception:
            pass

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
            process = self.utils.filesystem.run([
                "/usr/bin/ebook-convert",
                html_file,
                os.path.join(temp_docxdir, epub.identifier() + ".docx"),
                "--chapter=/",
                "--chapter-mark=none",
                "--page-breaks-before=/",
                "--no-chapters-in-toc",
                "--toc-threshold=0",
                "--docx-page-size=a4",
                # "--linearize-tables",
                "--extra-css=" + os.path.join(Xslt.xslt_dir, self.uid, 'extra.css'),

                # NOTE: microsoft fonts must be installed:
                # sudo apt-get install ttf-mscorefonts-installer
                "--embed-font-family=Verdana",

                "--docx-page-margin-top=42",
                "--docx-page-margin-bottom=42",
                "--docx-page-margin-left=70",
                "--docx-page-margin-right=56",
                ("--language=" + language) if language else "",
                #"--base-font-size=13"
                #"--remove-paragraph-spacing",
                #"--remove-paragraph-spacing-indent-size=-1",
                "--font-size-mapping=13,13,13,13,13,13,13,13"
            ])
                                                            

            if process.returncode == 0:
                self.utils.report.info("Boken ble konvertert.")



# -------------  script from kvile ---------------

            

                document = Document(os.path.join(temp_docxdir, epub.identifier() + ".docx"))

                paragraphList = document.paragraphs
                emptyParagraph = False

                def delete_paragraph(paragraph):
                   # self.utils.report.info("Delete paragraph: ")
                    p = paragraph._element
                    p.getparent().remove(p)
                    p._p = p._element = None

                for paragraph in document.paragraphs:
                    if len(paragraph.text) <= 1:
                        paragraph.text = re.sub(r"^\s(.*)", r"\1", paragraph.text)  #remove space at beginning av p
                       # self.utils.report.info("Paragraph.text <= 1 ")
                        if len(paragraph.text) == 0 and emptyParagraph: #if last paragraph also was empty
                    #        self.utils.report.info("Paragraph.text == 0 ")
                            delete_paragraph(paragraph)
                        emptyParagraph = True
                    else:
                        emptyParagraph = False
                

                document.save(os.path.join(temp_docxdir, epub.identifier() + "_clean.docx"))
                self.utils.report.info("Temp-fil ble lagret: "+os.path.join(temp_docxdir, epub.identifier() + "_clean.docx"))
         
# ---------- end script from kvile -------


            else:
                self.utils.report.error("En feil oppstod ved konvertering til DOCX for " + epub.identifier())
                self.utils.report.debug(traceback.format_stack())
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

        archived_path, stored = self.utils.filesystem.storeBook(temp_docxdir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    NLBpubToDocx().run()
