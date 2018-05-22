#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import tempfile

from core.utils.epub import Epub
from core.utils.metadata import Metadata

from core.pipeline import Pipeline


class InsertMetadata(Pipeline):
    # Ikke instansier denne klassen; bruk heller InsertMetadataEpub osv.
    uid = "insert-metadata"
    title = "Sett inn metadata"
    labels = ["Metadata"]
    publication_format = None
    expected_processing_time = 33

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
            return False

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        if not Metadata.should_produce(self, epub, self.publication_format):
            self.utils.report.info("{} skal ikke produseres som {}. Avbryter.".format(epub.identifier(), self.publication_format))
            self.utils.report.should_email = False
            return True

        self.utils.report.info("Lager en kopi av EPUBen")
        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_epubdir)
        temp_epub = Epub(self, temp_epubdir)

        self.utils.report.info("Oppdaterer metadata...")
        updated = Metadata.update(self, temp_epub, publication_format=self.publication_format, insert=True)
        if isinstance(updated, bool) and updated is False:
            self.utils.report.title = self.title + ": " + temp_epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        temp_epub.refresh_metadata()

        self.utils.report.info("Boken ble oppdatert med format-spesifik metadata. Kopierer til {}-arkiv.".format(self.publication_format))

        archived_path = self.utils.filesystem.storeBook(temp_epub.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(temp_epub.identifier() + " ble lagt til i arkivet.")

        self.utils.report.title = "{}: {} har fått {}-spesifikk metadata 👍😄 {}".format(self.title, epub.identifier(), self.publication_format, epubTitle)


class InsertMetadataEpub(InsertMetadata):
    uid = "insert-metadata-epub"
    title = "Sett inn metadata for EPUB"
    labels = ["EPUB", "Metadata"]
    publication_format = "EPUB"
    expected_processing_time = 42


class InsertMetadataDaisy202(InsertMetadata):
    uid = "insert-metadata-daisy202"
    title = "Sett inn metadata for lydbok"
    labels = ["Lydbok", "Innlesing", "Talesyntese", "Metadata"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 22


class InsertMetadataXhtml(InsertMetadata):
    uid = "insert-metadata-xhtml"
    title = "Sett inn metadata for e-tekst"
    labels = ["e-bok", "Metadata"]
    publication_format = "XHTML"
    expected_processing_time = 155


class InsertMetadataBraille(InsertMetadata):
    uid = "insert-metadata-braille"
    title = "Sett inn metadata for punktskrift"
    labels = ["Punktskrift", "Metadata"]
    publication_format = "Braille"
    expected_processing_time = 21


#class InsertMetadataExternal(InsertMetadata):
#    uid = "insert-metadata-external"
#    title = "Sett inn metadata for ekstern produksjon"
#    publication_format = "External" # eller hva er formatet her?
