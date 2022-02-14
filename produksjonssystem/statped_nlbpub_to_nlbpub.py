#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import subprocess
import sys
import tempfile

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.filesystem import Filesystem
from core.utils.mathml_to_text import Mathml_validator

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class StatpedNlbpubToNlbpub(Pipeline):
    uid = "statped-nlbpub-to-nlbpub"
    title = "Mottak av nlbpub fra Statped"
    labels = ["EPUB", "Statped"]
    publication_format = None
    expected_processing_time = 20

    def on_book_deleted(self):
        self.utils.report.should_email = False
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: "+self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: "+self.book['name'])
        return self.on_book()

    def on_book(self):
        epub = Epub(self.utils.report, self.book["source"])
        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass
        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return

        temp_obj = tempfile.TemporaryDirectory()
        temp_dir = temp_obj.name
        temp_epub = Epub(self.utils.report, temp_dir)
        library = temp_epub.meta("schema:library")

        if library.lower() != "statped":
            self.utils.report.error("Ikke en Statped bok. Avbryter")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

#        Filesystem.copy(self.utils.report, self.book["source"], temp_dir)

        self.utils.report.info("Kopierer til EPUB master-arkiv.")

        archived_path, stored = self.utils.filesystem.storeBook(temp_dir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " er valid 👍😄" + epubTitle
        self.utils.filesystem.deleteSource()
        return True


if __name__ == "__main__":
    StatpedNlbpubToNlbpub().run()
