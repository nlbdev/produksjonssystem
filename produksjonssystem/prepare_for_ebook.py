#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
import time

import requests
from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.epubcheck import Epubcheck
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class PrepareForEbook(Pipeline):
    uid = "prepare-for-ebook"
    title = "Klargjør for e-bok"
    labels = ["e-bok", "Statped"]
    publication_format = "XHTML"
    expected_processing_time = 8

    css_tempfile_obj = None

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB slettet: " + self.book['name']
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

        # ---------- gjør tilpasninger i HTML-fila med XSLT ----------

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
        html_dir = os.path.dirname(opf_path)
        html_file = os.path.join(html_dir, html_file)
        if not os.path.isfile(html_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        temp_xml_obj = tempfile.NamedTemporaryFile()
        temp_xml = temp_xml_obj.name

        self.utils.report.info("Generating hidden headlines where necessary")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "create-hidden-headlines.xsl"),
                    source=html_file,
                    target=temp_xml,
                    parameters={
                        "cover-headlines": "from-type",
                        "frontmatter-headlines": "from-type",
                        "bodymatter-headlines": "from-text",
                        "backmatter-headlines": "from-type"
                    })
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_xml, html_file)

        self.utils.report.info("Tilpasser innhold for e-tekst...")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "prepare-for-ebook.xsl"),
                    source=html_file,
                    target=temp_xml)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_xml, html_file)

        # Use library-specific logo and stylesheet if available

        library = temp_epub.meta("schema:library")
        library = library.upper() if library else library
        logo = os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "{}_logo.png".format(library))
        stylesheet = os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "{}.css".format(library))

        if os.path.isfile(logo):
            shutil.copy(logo, os.path.join(html_dir, os.path.basename(logo)))

        PrepareForEbook.update_css()

        if not os.path.isfile(stylesheet):
            stylesheet = PrepareForEbook.css_tempfile_obj.name
        shutil.copy(stylesheet, os.path.join(html_dir, "ebok.css"))

        self.utils.report.info("Adding logo item to OPF manifest")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "add-to-opf-manifest.xsl"),
                    source=opf_path,
                    target=temp_xml,
                    parameters={
                        "href": os.path.basename(logo),
                        "media-type": "image/png"
                    })
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_xml, opf_path)

        self.utils.report.info("Adding CSS item to OPF manifest")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "add-to-opf-manifest.xsl"),
                    source=opf_path,
                    target=temp_xml,
                    parameters={
                        "href": "ebok.css",
                        "media-type": "text/css"
                    })
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_xml, opf_path)

        if Epubcheck.isavailable():
            epubcheck = Epubcheck(self, opf_path)
            if not epubcheck.success:
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return
        else:
            self.utils.report.warn("Epubcheck not available, EPUB will not be validated!")

        # ---------- lagre filsett ----------

        self.utils.report.info("Boken ble konvertert. Kopierer til HTML-arkiv.")

        archived_path, stored = self.utils.filesystem.storeBook(temp_epubdir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True

    @staticmethod
    def update_css():
        if PrepareForEbook.css_tempfile_obj is None:
            PrepareForEbook.css_tempfile_obj = tempfile.NamedTemporaryFile()

        css_tempfile = PrepareForEbook.css_tempfile_obj.name

        stat = os.stat(css_tempfile)
        st_size = stat.st_size
        st_mtime = round(stat.st_mtime)

        if st_size == 0 or time.time() - st_mtime > 3600 * 3:
            if st_size == 0:
                default_path = os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "ebok.css")
                shutil.copy(default_path, css_tempfile)

            latest_url = "https://raw.githubusercontent.com/nlbdev/nlb-scss/master/dist/css/ebok.css"
            response = requests.get(latest_url)
            if response.status_code == 200:
                with open(css_tempfile, "wb") as target_file:
                    target_file.write(response.content)


if __name__ == "__main__":
    PrepareForEbook().run()
