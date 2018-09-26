#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.metadata import Metadata
from core.utils.schematron import Schematron
from core.utils.xslt import Xslt
from epub_to_dtbook_audio import EpubToDtbookAudio

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class EpubToDtbookHTML(Pipeline):
    uid = "epub-to-dtbook-HTML"
    title = "Epub til DTBook for ebok"
    labels = ["e-bok"]
    publication_format = "XHTML"
    expected_processing_time = 1059

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
            return False

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            return False

        if epub.identifier() != self.book["name"].split(".")[0]:
            self.utils.report.error(self.book["name"] + ": Filnavn stemmer ikke overens med dc:identifier: {}".format(epub.identifier()))
            return False

        should_produce, metadata_valid = Metadata.should_produce(self, epub, "XHTML")
        if not should_produce:
            self.utils.report.info("{} skal ikke produseres som e-bok. Avbryter.".format(epub.identifier()))
            self.utils.report.title = ("{}: {} Skal ikke produseres som {} {}".format(self.title, epub.identifier(), self.publication_format, epubTitle))
            return metadata_valid

        if not Metadata.is_in_quickbase(self.utils.report, epub.identifier()):
            self.utils.report.info("{} finnes ikke i Quickbase og vi lager derfor ikke en DTBook av den. Avbryter.".format(epub.identifier()))
            self.utils.report.title = ("{}: {} Skal ikke produseres som {} {}".format(self.title, epub.identifier(), self.publication_format, epubTitle))
            self.utils.report.should_email = False
            return False

        self.utils.report.info("Lager kopi av EPUB...")
        nordic_epubdir_obj = tempfile.TemporaryDirectory()
        nordic_epubdir = nordic_epubdir_obj.name
        self.utils.filesystem.copy(epub.asDir(), nordic_epubdir)
        nordic_epub = Epub(self, nordic_epubdir)

        self.utils.report.info("Oppdaterer metadata...")
        updated = Metadata.update(self, nordic_epub, publication_format="XHTML")
        if isinstance(updated, bool) and updated is False:
            return False
        nordic_epub.refresh_metadata()

        dtbook_dir_obj = tempfile.TemporaryDirectory()
        dtbook_dir = dtbook_dir_obj.name
        dtbook_file = os.path.join(dtbook_dir, nordic_epub.identifier() + ".xml")
        temp_dtbook_file_obj = tempfile.NamedTemporaryFile()
        temp_dtbook_file = temp_dtbook_file_obj.name

        self.utils.report.info("Konverterer fra nordisk EPUB til DTBook...")
        with DaisyPipelineJob(self, "nordic-epub3-to-dtbook", {"epub": nordic_epub.asFile(), "fail-on-error": "false"}) as dp2_job:

            self.utils.report.info("Henter rapport fra konvertering...")
            report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
            if os.path.isfile(report_file):
                with open(report_file, 'r') as result_report:
                    self.utils.report.attachment(result_report.readlines(),
                                                 os.path.join(self.utils.report.reportDir(), "report.html"),
                                                 "SUCCESS" if dp2_job.status == "DONE" else "ERROR")
            else:
                self.utils.report.warn("Ingen rapport ble funnet.")

            if dp2_job.status != "DONE":
                self.utils.report.error("Klarte ikke å konvertere boken")
                return False

            dp2_dtbook_dir = os.path.join(dp2_job.dir_output, "output-dir", nordic_epub.identifier())
            dp2_dtbook_file = os.path.join(dp2_job.dir_output, "output-dir", nordic_epub.identifier(), nordic_epub.identifier() + ".xml")

            if not os.path.isdir(dp2_dtbook_dir):
                self.utils.report.error("Finner ikke den konverterte boken: {}".format(dp2_dtbook_dir))
                return False

            if not os.path.isfile(dp2_dtbook_file):
                self.utils.report.error("Finner ikke den konverterte boken: {}".format(dp2_dtbook_file))
                return False

            self.utils.filesystem.copy(dp2_dtbook_dir, dtbook_dir)

        self.utils.report.info("Gjør tilpasninger i DTBook")
        self.utils.report.debug("dtbook-cleanup.xsl")
        self.utils.report.debug("    source = " + dtbook_file)
        self.utils.report.debug("    target = " + temp_dtbook_file)
        xslt = Xslt(self, stylesheet=os.path.join(Xslt.xslt_dir, EpubToDtbookAudio.uid, "dtbook-cleanup.xsl"),
                    source=dtbook_file,
                    target=temp_dtbook_file)
        if not xslt.success:
            return False
        shutil.copy(temp_dtbook_file, dtbook_file)

        self.utils.report.info("Validerer DTBook")
        sch = Schematron(self, schematron=os.path.join(Xslt.xslt_dir, EpubToDtbookAudio.uid, "validate-dtbook.sch"), source=dtbook_file)
        if not sch.success:
            self.utils.report.error("Validering av DTBook feilet")
            return False

        self.utils.report.info("Boken ble konvertert. Kopierer til DTBook-til-HTML-arkiv.")
        archived_path = self.utils.filesystem.storeBook(dtbook_dir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i DTBook-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    EpubToDtbookHTML().run()
