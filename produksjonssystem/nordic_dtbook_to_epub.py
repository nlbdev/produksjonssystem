#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import shutil
import sys
import tempfile

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.metadata import Metadata
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NordicDTBookToEpub(Pipeline):
    uid = "nordic-dtbook-to-epub"
    title = "Nordisk DTBook til EPUB"
    labels = []
    publication_format = "EPUB"
    expected_processing_time = 600

    xslt_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "xslt"))

    def on_book_deleted(self):
        self.utils.report.should_email = False
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")

        metadata = Metadata.get_metadata_from_book(self, self.book["source"])
        metadata["identifier"] = re.sub(r"[^\d]", "", metadata["identifier"])
        if not metadata["identifier"]:
            self.utils.report.error("Klarte ikke å bestemme boknummer for {}".format(self.book["name"]))
            return False
        if metadata["identifier"] != self.book["name"]:
            self.utils.report.info("Boknummer for {} er: {}".format(self.book["name"], metadata["identifier"]))

        self.utils.report.info("Lager en kopi av DTBoken")
        temp_dtbookdir_obj = tempfile.TemporaryDirectory()
        temp_dtbookdir = temp_dtbookdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_dtbookdir)

        dtbook = None
        for root, dirs, files in os.walk(temp_dtbookdir):
            for f in files:
                if f.endswith(".xml"):
                    xml = ElementTree.parse(os.path.join(root, f)).getroot()
                    if xml.xpath("namespace-uri()") == "http://www.daisy.org/z3986/2005/dtbook/":
                        dtbook = os.path.join(root, f)
                        break
                if dtbook is not None:
                    break
        if not dtbook:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne DTBook")
            return False

        temp_dtbook_file_obj = tempfile.NamedTemporaryFile()
        temp_dtbook_file = temp_dtbook_file_obj.name

        self.utils.report.info("Rydder opp i nordisk DTBook")
        xslt = Xslt(self,
                    stylesheet=os.path.join(NordicDTBookToEpub.xslt_dir, NordicDTBookToEpub.uid, "nordic-cleanup-dtbook.xsl"),
                    source=dtbook,
                    target=temp_dtbook_file)
        if not xslt.success:
            return False
        shutil.copy(temp_dtbook_file, dtbook)

        self.utils.report.info("Konverterer Nordisk DTBook til Nordisk EPUB 3...")
        epub = None
        with DaisyPipelineJob(self, "nordic-dtbook-to-epub3", {"dtbook": dtbook}) as dp2_job_dtbook_to_epub3:
            dtbook_to_epub3_job_status = None
            if dp2_job_dtbook_to_epub3.status == "DONE":
                dtbook_to_epub3_job_status = "SUCCESS"
            else:
                dtbook_to_epub3_job_status = "ERROR"

            epub_file = os.path.join(dp2_job_dtbook_to_epub3.dir_output, "output-dir", metadata["identifier"] + ".epub")
            for root, dirs, files in os.walk(dp2_job_dtbook_to_epub3.dir_output):
                for f in files:
                    self.utils.report.info(os.path.join(root, f))
                for d in dirs:
                    self.utils.report.info(os.path.join(root, d) + "/")
            report_file = os.path.join(dp2_job_dtbook_to_epub3.dir_output, "html-report/report.xhtml")

            # get conversion report
            if os.path.isfile(report_file):
                with open(report_file, 'r') as result_report:
                    self.utils.report.attachment(result_report.readlines(),
                                                 os.path.join(self.utils.report.reportDir(), "report-dtbook-to-epub3.html"),
                                                 dtbook_to_epub3_job_status)

            if dtbook_to_epub3_job_status == "ERROR":
                self.utils.report.error("Klarte ikke å konvertere boken")
                return False

            if not os.path.isfile(epub_file):
                self.utils.report.error("Finner ikke EPUBen som skal ha blitt laget: {}".format(
                    os.path.relpath(epub_file, dp2_job_dtbook_to_epub3.dir_output)))
                return False

            epub = Epub(self, epub_file)
            if not epub.isepub():
                return False

        self.utils.report.info("Boken ble konvertert. Kopierer til EPUB3-fra-DTBook-arkiv.")
        archived_path = self.utils.filesystem.storeBook(epub.asDir(), metadata["identifier"], overwrite=self.overwrite)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info("{} ble lagt til i EPUB3-fra-DTBook-arkivet.".format(metadata["identifier"]))
        self.utils.report.title = "{}: {} ble konvertert 👍😄 ({})".format(self.title, metadata["identifier"], metadata["title"])
        return True


if __name__ == "__main__":
    NordicDTBookToEpub().run()
