#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
from pathlib import Path

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class HtmlToDtbook(Pipeline):
    uid = "html-to-dtbook"
    title = "HTML til DTBook"
    labels = []
    publication_format = "DTBook"
    expected_processing_time = 10

    _book_title = None  # cache book title

    def book_identifier(self):
        return Path(self.book["source"]).stem

    def book_title(self):
        if self._book_title is not None:
            return self._book_title

        html_file = self.html_file()
        if not html_file:
            self.utils.report.warn("Finner ikke HTML-fila: {}".format(html_file))
            return False
        htmldoc = ElementTree.parse(html_file).getroot()
        self._book_title = htmldoc.xpath("/*/*[local-name()='head']/*[local-name()='title']")
        self._book_title = self._book_title[0].text if len(self._book_title) else ""
        return self._book_title

    def html_file(self):
        identifier = self.book_identifier()

        html_file = None

        if os.path.isfile(self.book["source"]):
            if self.book["name"] == identifier + ".xhtml":
                return self.book["source"]
            else:
                self.utils.report.error("Filen '{}' har feil navn. Forventet '{}.xhtml'.".format(self.book["name"], identifier))
                return False

        elif os.path.isdir(self.book["source"]):
            for root, dirs, files in os.walk(self.book["source"]):
                if (identifier + ".xhtml") in files:
                    if html_file is not None:
                        self.utils.report.error("Det finnes flere filer som heter '{}.xhtml'.".format(identifier))
                        return None
                    html_file = os.path.join(root, identifier + ".xhtml")
            if html_file is None:
                self.utils.report.error("Finner ingen fil som heter '{}.xhtml'.".format(identifier))
                return None
        return html_file

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok: " + self.book["name"])
        self.utils.report.title = "Slettet bok: " + self.book["name"]

    def on_book_modified(self):
        self.utils.report.info("Endret bok: " + self.book["name"])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok: " + self.book["name"])
        return self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")

        identifier = self.book_identifier()

        html_file = self.html_file()
        if not html_file:
            return False

        # ---------- lag en kopi av boka ----------

        temp_dtbookdir_obj = tempfile.TemporaryDirectory()
        temp_dtbookdir = temp_dtbookdir_obj.name
        self.utils.filesystem.copy(os.path.dirname(html_file), temp_dtbookdir)
        temp_dtbook = os.path.join(temp_dtbookdir, identifier + ".xml")

        # ---------- slett EPUB-spesifikke filer ----------

        for root, dirs, files in os.walk(temp_dtbookdir):
            for file in files:
                if Path(file).suffix.lower() in [".xhtml", ".html", ".smil", ".mp3", ".wav"]:
                    os.remove(os.path.join(root, file))
        shutil.copy(html_file, temp_dtbook)

        # ---------- konverter fra XHTML5 til DTBook ----------

        temp_html_obj = tempfile.NamedTemporaryFile()
        temp_html = temp_html_obj.name

        self.utils.report.info("Konverterer fra XHTML5 til DTBook...")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, HtmlToDtbook.uid, "html-to-dtbook.xsl"),
                    source=temp_dtbook,
                    target=temp_html)
        if not xslt.success:
            return False
        shutil.copy(temp_html, temp_dtbook)

        self.utils.report.info("Validerer DTBook...")
        with DaisyPipelineJob(self, "dtbook-validator", {"input-dtbook": temp_dtbook, "check-images": "true"}) as dp2_job:

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
        archived_path = self.utils.filesystem.storeBook(temp_dtbookdir, identifier)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(identifier + " ble lagt til i DTBook-arkivet.")
        return True


if __name__ == "__main__":
    HtmlToDtbook().run()
