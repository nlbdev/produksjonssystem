#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import subprocess
import sys
import tempfile

from pathlib import Path
import traceback

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from core.utils.metadata import Metadata
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NordicToNlbpub(Pipeline):
    uid = "nordic-epub-to-nlbpub"
    title = "Nordisk EPUB til NLBPUB"
    labels = ["EPUB", "Lydbok", "Punktskrift", "e-bok", "Statped"]
    publication_format = None
    expected_processing_time = 2000

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
        epub = Epub(self.utils.report, self.book["source"])

        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass

        # sjekk at dette er en EPUB
        if not epub.isepub():
            return False

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            return False

        if epub.identifier() != self.book["name"].split(".")[0]:
            self.utils.report.error(self.book["name"] + ": Filnavn stemmer ikke overens med dc:identifier: {}".format(epub.identifier()))
            return False

        # temp_xml_file_obj = tempfile.NamedTemporaryFile()
        # temp_xml_file = temp_xml_file_obj.name

        html_dir_obj = tempfile.TemporaryDirectory()
        html_dir = html_dir_obj.name
        # html_file = os.path.join(html_dir, epub.identifier() + ".xhtml")

        self.utils.report.info("Konverterer fra Nordisk EPUB 3 til NLBPUB...")
        success = False
        try:
            command = ["src/run.py", self.book["source"], html_dir, "--add-header-element=false"]

            epub_to_html_home = os.getenv("EPUB_TO_HTML_HOME")
            if not epub_to_html_home:
                self.utils.report.warning("EPUB_TO_HTML_HOME is not set. Using default value: /opt/nordic-epub3-dtbook-migrator")
                epub_to_html_home = "/opt/nordic-epub3-dtbook-migrator"

            process = Filesystem.run_static(command, epub_to_html_home, self.utils.report)
            success = process.returncode == 0

        except subprocess.TimeoutExpired:
            self.utils.report.error("Epubcheck for {} took too long and were therefore stopped.".format(os.path.basename(self.book["source"])))

        except Exception:
            self.utils.report.debug(traceback.format_exc(), preformatted=True)
            self.utils.report.error("An error occured while running EPUB to HTML (for " + str(self.book["source"]) + ")")

        if not success:
            self.utils.report.error("Klarte ikke å konvertere boken")
            return False

        self.utils.report.debug("Output directory contains: " + str(os.listdir(html_dir)))
        html_dir = os.path.join(html_dir, epub.identifier())

        if not os.path.isdir(html_dir):
            self.utils.report.error("Finner ikke den konverterte boken: {}".format(html_dir))
            return False

        self.utils.report.info("Boken ble konvertert. Kopierer til NLBPUB-arkiv.")
        archived_path, _ = self.utils.filesystem.storeBook(html_dir, epub.identifier(), overwrite=self.overwrite)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    NordicToNlbpub().run()
