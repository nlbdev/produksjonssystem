#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tempfile

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.kindlegen import KindleGen

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class EpubToKindle(Pipeline):
    uid = "epub-to-kindle"
    title = "EPUB til Mobi/KF8"
    labels = ["e-bok", "Statped"]
    publication_format = "XHTML"
    expected_processing_time = 7

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

        # ---------- konverter til Mobi/KF8 ----------

        # get OPF path
        opf_path = temp_epub.opf_path()
        if not opf_path:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne OPF-fila i EPUBen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return
        opf_path = os.path.join(temp_epubdir, opf_path)

        # create an empty directory which we'll use to temporarily store the Mobi/KF8-file
        temp_kindledir_obj = tempfile.TemporaryDirectory()
        temp_kindledir = temp_kindledir_obj.name
        temp_kindlefile = os.path.join(temp_kindledir, epub.identifier() + ".mobi")

        if not KindleGen.isavailable():
            self.utils.report.error("KindleGen not available, unable to convert to Mobi/KF8!")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return
        kindlegen = KindleGen(self, opf_path, temp_kindlefile)
        if not kindlegen.success:
            self.utils.report.error("An error occured when trying to convert to Mobi/KF8!")
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return

        self.utils.report.info("Boken ble konvertert. Kopierer til Kindle-arkiv.")

        archived_path, stored = self.utils.filesystem.storeBook(temp_epubdir, temp_epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    EpubToKindle().run()
