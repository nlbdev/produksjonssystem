#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import tempfile

from core.utils.epub import Epub
from update_metadata import UpdateMetadata

from core.pipeline import Pipeline

class InsertMetadata(Pipeline):
    # Ikke instansier denne klassen; bruk heller InsertMetadataEpub osv.
    uid = "insert-metadata"
    title = "Sett inn metadata"
    publication_format = None
    
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
        
        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False
        
        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False
        
        if not UpdateMetadata.should_produce(self, epub, self.publication_format):
            self.utils.report.info("{} skal ikke produseres som {}. Avbryter.".format(epub.identifier(), self.publication_format))
            self.utils.report.should_email = False
            return True
        
        
        # ---------- lag en kopi av EPUBen ----------
        
        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_epubdir)
        temp_epub = Epub(self, temp_epubdir)
        
        
        # ---------- oppdater metadata ----------
        
        self.utils.report.info("Oppdaterer metadata...")
        updated = UpdateMetadata.update(self, temp_epub, publication_format=self.publication_format, insert=True)
        if isinstance(updated, bool) and updated == False:
            self.utils.report.title = self.title + ": " + temp_epub.identifier() + " feilet 😭👎"
            return False
        
        self.utils.report.info("Boken ble oppdatert med format-spesifik metadata. Kopierer til {}-arkiv.".format(self.publication_format))
        
        archived_path = self.utils.filesystem.storeBook(temp_epub.asDir(), epub.identifier())
        UpdateMetadata.add_production_info(self, epub.identifier(), publication_format=self.publication_format)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(temp_epub.identifier() + " ble lagt til i arkivet.")
        
        self.utils.report.title = "{}: {} har fått {}-spesifikk metadata 👍😄".format(self.title, epub.identifier(), self.publication_format)

class InsertMetadataEpub(InsertMetadata):
    uid = "insert-metadata-epub"
    title = "Sett inn metadata for EPUB"
    publication_format = "EPUB"
    
class InsertMetadataDaisy202(InsertMetadata):
    uid = "insert-metadata-daisy202"
    title = "Sett inn metadata for lydbok"
    publication_format = "DAISY 2.02"

class InsertMetadataXhtml(InsertMetadata):
    uid = "insert-metadata-xhtml"
    title = "Sett inn metadata for e-tekst"
    publication_format = "XHTML"

class InsertMetadataBraille(InsertMetadata):
    uid = "insert-metadata-braille"
    title = "Sett inn metadata for punktskrift"
    publication_format = "Braille"

#class InsertMetadataExternal(InsertMetadata):
#    uid = "insert-metadata-external"
#    title = "Sett inn metadata for ekstern produksjon"
#    publication_format = "External" # eller hva er formatet her?
