#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tempfile

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.filesystem import Filesystem
from core.utils.metadata import Metadata

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
        Filesystem.copy(self.utils.report, self.book["source"], temp_dir)

        self.utils.report.info("Henter metadata fra api.nlb.no")
        creative_work_metadata = None
        edition_metadata = None

        timeout = 0
        while creative_work_metadata is None and timeout < 5:

            timeout = timeout + 1
            creative_work_metadata = Metadata.get_creative_work_from_api(self.book["name"], editions_metadata="all", use_cache_if_possible=True, creative_work_metadata="all")
            edition_metadata = Metadata.get_edition_from_api(self.book["name"])
            if creative_work_metadata is not None:
                break

        if creative_work_metadata is None:
            self.utils.report.warning("Klarte ikke finne et åndsverk tilknyttet denne utgaven. Prøver igjen senere.")
            return False

        library = edition_metadata["library"].lower()

        # in case of wrong upper lower cases
        if library == "nlb":
            library = "NLB"
        elif library == "statped":
            library = "Statped"
        elif library == "kabb":
            library = "KABB"

        if library.lower() != "statped":
            self.utils.report.error("Ikke en Statped bok. Avbryter")
            self.utils.report.should_email = False
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
