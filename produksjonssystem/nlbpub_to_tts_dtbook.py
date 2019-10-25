#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
from pathlib import Path

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from epub_to_dtbook_audio import EpubToDtbookAudio
from html_to_dtbook import HtmlToDtbook

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubToTtsDtbook(Pipeline):
    uid = "nlbpub-to-tts-dtbook"
    title = "NLBPUB til DTBook for talesyntese"
    labels = ["Lydbok", "Statped"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 21

    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "xslt"))

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

        self.utils.report.info("Locating HTML file")
        epub = Epub(self, self.book["source"])
        if not epub.isepub():
            return False
        assert epub.isepub(), "The input must be an EPUB"
        spine = epub.spine()
        if not len(spine) == 1:
            self.utils.report.warn("There must only be one item in the EPUB spine")
            return False
        html_file = os.path.join(self.book["source"], os.path.dirname(epub.opf_path()), spine[0]["href"])

        identifier = epub.identifier()

        self.utils.report.info("lag en kopi av boka")
        temp_resultdir_obj = tempfile.TemporaryDirectory()
        temp_resultdir = temp_resultdir_obj.name
        self.utils.filesystem.copy(os.path.dirname(html_file), temp_resultdir)
        temp_result = os.path.join(temp_resultdir, identifier + ".xml")

        self.utils.report.info("sletter EPUB-spesifikke filer")
        for root, dirs, files in os.walk(temp_resultdir):
            for file in files:
                if Path(file).suffix.lower() in [".xhtml", ".html", ".smil", ".mp3", ".wav", ".opf"]:
                    os.remove(os.path.join(root, file))
        shutil.copy(html_file, temp_result)

        temp_xslt_output_obj = tempfile.NamedTemporaryFile()
        temp_xslt_output = temp_xslt_output_obj.name

        # Transformasjon for å erstatte MathML med tekstuell representasjon
        # TODO Endre fra placeholder til riktig transformering når denne er klar
        self.utils.report.info("Erstatter matematiske formler med tekstuell representasjon")
        self.utils.report.debug("mathml-to-placeholder.xsl")
        self.utils.report.debug("    source = " + temp_result)
        self.utils.report.debug("    target = " + temp_xslt_output)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, "mathml-to-text", "mathml-to-placeholder.xsl"),
                    source=temp_result,
                    target=temp_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_xslt_output, temp_result)

        self.utils.report.info("Konverterer fra XHTML5 til DTBook...")
        self.utils.report.debug("html-to-dtbook.xsl")
        self.utils.report.debug("    source = " + temp_result)
        self.utils.report.debug("    target = " + temp_xslt_output)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, HtmlToDtbook.uid, "html-to-dtbook.xsl"),
                    source=temp_result,
                    target=temp_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_xslt_output, temp_result)

        self.utils.report.info("Gjør tilpasninger i DTBook")
        self.utils.report.debug("dtbook-cleanup.xsl")
        self.utils.report.debug("    source = " + temp_result)
        self.utils.report.debug("    target = " + temp_xslt_output)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, EpubToDtbookAudio.uid, "dtbook-cleanup.xsl"),
                    source=temp_result,
                    target=temp_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_xslt_output, temp_result)

        # Fjern denne transformasjonen hvis det oppstår kritiske proplemer med håndteringen av komplekst innhold
        self.utils.report.info("Legger inn ekstra informasjon om komplekst innhold")
        self.utils.report.debug("optimaliser-komplekst-innhold.xsl")
        self.utils.report.debug("    source = " + temp_result)
        self.utils.report.debug("    target = " + temp_xslt_output)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, EpubToDtbookAudio.uid, "optimaliser-komplekst-innhold.xsl"),
                    source=temp_result,
                    target=temp_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_xslt_output, temp_result)

        self.utils.report.info("Validerer DTBook...")
        with DaisyPipelineJob(self, "dtbook-validator", {"input-dtbook": temp_result, "check-images": "true"}) as dp2_job:

            # get validation report
            report_file = os.path.join(dp2_job.dir_output, "html-report/html-report.xml")
            if os.path.isfile(report_file):
                with open(report_file, 'r') as result_report:
                    self.utils.report.attachment(result_report.readlines(),
                                                 os.path.join(self.utils.report.reportDir(), "report.html"), "SUCCESS" if dp2_job.status == "DONE" else "ERROR")

            if dp2_job.status != "DONE":
                self.utils.report.error("Klarte ikke å validere boken")
                return False

        self.utils.report.info("Boken ble konvertert. Kopierer til DTBook-arkiv.")
        archived_path, stored = self.utils.filesystem.storeBook(temp_resultdir, identifier)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        return True


if __name__ == "__main__":
    NlbpubToTtsDtbook().run()
