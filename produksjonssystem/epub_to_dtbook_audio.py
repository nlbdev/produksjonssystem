#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile

from core.pipeline import Pipeline, DummyPipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.metadata import Metadata
from core.utils.schematron import Schematron
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class EpubToDtbookAudio(Pipeline):
    uid = "epub-to-dtbook-audio"
    title = "EPUB til DTBook for talesyntese"
    labels = ["Lydbok"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 1408

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

        should_produce, metadata_valid = Metadata.should_produce(epub.identifier(), self.publication_format, report=self.utils.report)
        if not metadata_valid:
            self.utils.report.info("{} har feil i metadata for lydbok. Avbryter.".format(epub.identifier()))
            self.utils.report.title = ("{}: {} har feil i metadata for {} - {}".format(self.title, epub.identifier(), self.publication_format, epubTitle))
            return False
        if not should_produce:
            self.utils.report.info("{} skal ikke produseres som lydbok. Avbryter.".format(epub.identifier()))
            self.utils.report.title = ("{}: {} Skal ikke produseres som {} - {}".format(self.title, epub.identifier(), self.publication_format, epubTitle))
            return True

        if Metadata.is_old(epub.identifier(), report=self.utils.report):
            self.utils.report.info("{} er gammel, og vi lager derfor ikke en DTBook av den. Avbryter.".format(epub.identifier()))
            self.utils.report.title = ("{}: {} Skal ikke produseres som {} {}".format(self.title, epub.identifier(), self.publication_format, epubTitle))
            self.utils.report.should_email = False
            return False

        self.utils.report.info("Lager kopi av EPUB...")
        nordic_epubdir_obj = tempfile.TemporaryDirectory()
        nordic_epubdir = nordic_epubdir_obj.name
        self.utils.filesystem.copy(epub.asDir(), nordic_epubdir)
        nordic_epub = Epub(self, nordic_epubdir)

        self.utils.report.info("Oppdaterer metadata...")
        updated = Metadata.update(self.utils.report, nordic_epub, publication_format=self.publication_format)
        if isinstance(updated, bool) and updated is False:
            return False
        nordic_epub.refresh_metadata()

        dtbook_dir_obj = tempfile.TemporaryDirectory()
        dtbook_dir = dtbook_dir_obj.name
        dtbook_file = os.path.join(dtbook_dir, nordic_epub.identifier() + ".xml")
        temp_dtbook_file_obj = tempfile.NamedTemporaryFile()
        temp_dtbook_file = temp_dtbook_file_obj.name

        self.utils.report.info("Konverterer fra nordisk EPUB til DTBook...")
        with DaisyPipelineJob(self, "nordic-epub3-to-dtbook", {"epub": nordic_epub.asFile(), "fail-on-error": "false", "priority": "low"}) as dp2_job:

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

        # 2019-01-15, Per Sennels:
        # Fjern denne transformasjonen hvis det oppstår kritiske proplemer med håndteringen av komplekst innhold
        self.utils.report.info("Legger inn ekstra informasjon om komplekst innhold")
        self.utils.report.debug("optimaliser-komplekst-innhold.xsl")
        self.utils.report.debug("    source = " + dtbook_file)
        self.utils.report.debug("    target = " + temp_dtbook_file)
        xslt = Xslt(self, stylesheet=os.path.join(Xslt.xslt_dir, EpubToDtbookAudio.uid, "optimaliser-komplekst-innhold.xsl"),
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

        self.utils.report.info("Boken ble konvertert. Kopierer til DTBook-til-talesyntese-arkiv.")
        archived_path, stored = self.utils.filesystem.storeBook(dtbook_dir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True

    def should_retry_book(self, source):
        if not self.logPipeline:
            self.logPipeline = DummyPipeline(uid=self.uid + "-dummylogger", title=self.title + " dummy logger", inherit_config_from=self)

        epub = Epub(self, source)
        if not epub.isepub(report_errors=False):
            self.logPipeline.utils.report.warning("Boken er ikke en EPUB, kan ikke avgjøre om den skal trigges eller ikke. Antar at den skal det: {}".format(source))
            return True

        if Metadata.is_old(epub.identifier()):
            self.logPipeline.utils.report.error("{} er gammel. Boken blir ikke trigget.".format(epub.identifier()))
            return False

        should_produce, _ = Metadata.should_produce(epub.identifier(),
                                                    self.publication_format,
                                                    report=self.logPipeline.utils.report,
                                                    skip_metadata_validation=True)
        production_complete, _ = Metadata.production_complete(epub.identifier(), self.publication_format, report=self.logPipeline.utils.report)
        return should_produce and not production_complete


if __name__ == "__main__":
    EpubToDtbookAudio().run()
