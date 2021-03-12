#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import tempfile
from pathlib import Path

from core.pipeline import DummyPipeline, Pipeline
from core.utils.epub import Epub
from core.utils.metadata import Metadata
from core.utils.filesystem import Filesystem


class InsertMetadata(Pipeline):
    # Ikke instansier denne klassen; bruk heller InsertMetadataBraille osv.
    uid = "insert-metadata"
    # gid = "insert-metadata"
    title = "Sett inn metadata"
    # group_title = "Sett inn metadata"
    labels = ["Statped"]
    publication_format = None
    expected_processing_time = 500

    logPipeline = None

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

        # check that this is an EPUB (we only insert metadata into EPUBs)
        if not epub.isepub():
            return False

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            return False

        if epub.identifier() != self.book["name"].split(".")[0]:
            self.utils.report.error(self.book["name"] + ": Filnavn stemmer ikke overens med dc:identifier: {}".format(epub.identifier()))
            return False

        should_produce, metadata_valid = Metadata.should_produce(epub.identifier(), self.publication_format, report=self.utils.report)
        if not metadata_valid:
            self.utils.report.info("{} har feil i metadata for {}. Avbryter.".format(epub.identifier(), self.publication_format))
            self.utils.report.title = "{}: {} har feil i metadata for {} 😭👎 {}".format(self.title, epub.identifier(), self.publication_format, epubTitle)
            return False
        if not should_produce:
            self.utils.report.info("{} skal ikke produseres som {}. Avbryter.".format(epub.identifier(), self.publication_format))
            self.utils.report.title = "{}: {} Skal ikke produseres som {} 🤷 {}".format(self.title, epub.identifier(), self.publication_format, epubTitle)
            return True

        self.utils.report.info("Lager en kopi av EPUBen")
        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        Filesystem.copy(self.utils.report, self.book["source"], temp_epubdir)
        temp_epub = Epub(self.utils.report, temp_epubdir)

        is_valid = Metadata.insert_metadata(self.utils.report, temp_epub, publication_format=self.publication_format, report_metadata_errors=False)
        if not is_valid:
            self.utils.report.error("Bibliofil-metadata var ikke valide. Avbryter.")
            return False

        self.utils.report.info("Boken ble oppdatert med format-spesifikk metadata. Kopierer til {}-arkiv.".format(self.publication_format))

        archived_path, stored = self.utils.filesystem.storeBook(temp_epub.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")

        self.utils.report.title = "{}: {} har fått {}-spesifikk metadata og er klar til å produseres 👍😄 {}".format(
            self.title, epub.identifier(), self.publication_format, temp_epub.meta("dc:title"))

        return True


class InsertMetadataDaisy202(InsertMetadata):
    uid = "insert-metadata-daisy202"
    title = "Sett inn metadata for lydbok"
    labels = ["Lydbok", "Metadata", "Statped"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 500


class InsertMetadataXhtml(InsertMetadata):
    uid = "insert-metadata-xhtml"
    title = "Sett inn metadata for e-bok"
    labels = ["e-bok", "Metadata", "Statped"]
    publication_format = "XHTML"
    expected_processing_time = 500


class InsertMetadataBraille(InsertMetadata):
    uid = "insert-metadata-braille"
    title = "Sett inn metadata for punktskrift"
    labels = ["Punktskrift", "Metadata", "Statped"]
    publication_format = "Braille"
    expected_processing_time = 500
