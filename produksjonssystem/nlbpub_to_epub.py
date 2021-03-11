#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
import datetime
import threading
import time
import logging

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.bibliofil import Bibliofil
from core.utils.epub import Epub
from core.utils.epubcheck import Epubcheck
from core.utils.xslt import Xslt
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubToEpub(Pipeline):
    uid = "nlbpub-to-epub"
    title = "NLBPUB til EPUB"
    labels = ["e-bok", "Statped"]
    publication_format = "XHTML"
    expected_processing_time = 550

    _triggerEpubCatalogThread = None

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self._triggerEpubCatalogThread = threading.Thread(target=self._trigger_epub_catalog_thread, name="Update catalog XHTML thread")
        self._triggerEpubCatalogThread.setDaemon(True)
        self._triggerEpubCatalogThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching for needed catalog changes in XHTML distribution formats")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def _trigger_epub_catalog_thread(self):
        last_check = 0

        self.watchdog_bark()
        while self.shouldRun:
            time.sleep(5)
            self.watchdog_bark()

            if not self.dirsAvailable():
                continue

            # Check for update every 3 days
            max_update_interval = 60 * 60 * 24 * 3
            if time.time() - last_check < max_update_interval:
                continue

            last_check = time.time()
            logging.info("Updating formatklar and filesize for ebooks")
            list_books = Filesystem.list_book_dir(self.dir_out)
            Bibliofil.update_list_of_books("XHTML", list_books)


    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB-kilde slettet: " + self.book['name']

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")
        epub = Epub(self.utils.report, self.book["source"])

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
        Filesystem.copy(self.utils.report, self.book["source"], temp_epubdir)
        temp_epub = Epub(self.utils.report, temp_epubdir)

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

        temp_xml_obj = tempfile.NamedTemporaryFile()
        temp_xml = temp_xml_obj.name

        self.utils.report.info("Flater ut NLBPUB")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToEpub.uid, "nlbpub-flatten.xsl"),
                    source=html_file,
                    target=temp_xml)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return
        shutil.copy(temp_xml, html_file)

        self.utils.report.info("Deler opp NLBPUB i flere HTML-filer")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToEpub.uid, "nlbpub-split.xsl"),
                    source=html_file,
                    target=temp_xml,
                    parameters={
                        "output-dir": os.path.dirname(html_file)
                    })
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return
        os.remove(html_file)

        spine_hrefs = []
        for href in sorted(os.listdir(os.path.dirname(html_file))):
            if href.endswith(".xhtml") and href not in ["nav.xhtml", os.path.basename(html_file)]:
                spine_hrefs.append(href)

        self.utils.report.info("Oppdaterer OPF-fil")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToEpub.uid, "update-opf.xsl"),
                    source=opf_path,
                    target=temp_xml,
                    parameters={
                        "spine-hrefs": ",".join(spine_hrefs)
                    })
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return
        shutil.copy(temp_xml, opf_path)

        nav_path = os.path.join(temp_epubdir, temp_epub.nav_path())

        self.utils.report.info("Lager nytt navigasjonsdokument")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToEpub.uid, "generate-nav.xsl"),
                    source=opf_path,
                    target=nav_path)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return

        self.utils.report.info("Legger til properties i OPF etter behov")
        temp_epub.update_opf_properties()

        if Epubcheck.isavailable():
            epubcheck = Epubcheck(self, opf_path)
            if not epubcheck.success:
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return
        else:
            self.utils.report.warn("Epubcheck not available, EPUB will not be validated!")

        self.utils.report.info("Boken ble konvertert. Kopierer til e-bok-arkiv.")

        archived_path, stored = self.utils.filesystem.storeBook(temp_epubdir, temp_epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        Bibliofil.book_available(NlbpubToEpub.publication_format, temp_epub.identifier())
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    NlbpubToEpub().run()
