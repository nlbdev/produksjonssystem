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
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NordicDTBookToEpub(Pipeline):
    uid = "nordic-dtbook-to-epub"
    title = "Nordisk DTBook til EPUB"
    labels = []
    publication_format = "EPUB"
    expected_processing_time = 3200

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

        metadata = Metadata.get_metadata_from_book(self.utils.report, self.book["source"])
        metadata["identifier"] = re.sub(r"[^\d]", "", metadata["identifier"])
        if not metadata["identifier"]:
            self.utils.report.error("Klarte ikke å bestemme boknummer for {}".format(self.book["name"]))
            return False
        if metadata["identifier"] != self.book["name"]:
            self.utils.report.info("Boknummer for {} er: {}".format(self.book["name"], metadata["identifier"]))

        self.utils.report.info("Lager en kopi av DTBoken")
        temp_dtbookdir_obj = tempfile.TemporaryDirectory()
        temp_dtbookdir = temp_dtbookdir_obj.name
        Filesystem.copy(self.utils.report, self.book["source"], temp_dtbookdir)

        # find DTBook XML
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

        # rename all files to lower case
        for root, dirs, files in os.walk(temp_dtbookdir):
            for f in files:
                if not f.lower() == f:
                    self.utils.report.warn("renaming to lowercase: {}".format(f))
                    shutil.move(os.path.join(root, f), os.path.join(root, f.lower()))

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

        self.utils.report.info("Validerer Nordisk DTBook...")

        # create context for Pipeline 2 job
        dtbook_dir = os.path.dirname(dtbook)
        dtbook_context = {}
        for root, dirs, files in os.walk(dtbook_dir):
            for file in files:
                fullpath = os.path.join(root, file)
                relpath = os.path.relpath(fullpath, dtbook_dir)
                dtbook_context[relpath] = fullpath

        with DaisyPipelineJob(self,
                              "nordic-dtbook-validate",
                              {"dtbook": os.path.basename(dtbook), "no-legacy": "false"},
                              pipeline_and_script_version=[
                                ("1.13.6", "1.4.6"),
                                ("1.13.4", "1.4.5"),
                                ("1.12.1", "1.4.2"),
                                ("1.11.1-SNAPSHOT", "1.3.0"),
                              ],
                              context=dtbook_context
                              ) as dp2_job_dtbook_validate:
            dtbook_validate_status = None
            if dp2_job_dtbook_validate.status == "SUCCESS":
                dtbook_validate_status = "SUCCESS"
            elif dp2_job_dtbook_validate.status in ["VALIDATION_FAIL", "FAIL"]:
                dtbook_validate_status = "WARN"
            else:
                dtbook_validate_status = "ERROR"

            report_file = os.path.join(dp2_job_dtbook_validate.dir_output, "html-report/report.xhtml")

            if dtbook_validate_status == "WARN":
                report_doc = ElementTree.parse(report_file)
                errors = report_doc.xpath('//*[@class="error" or @class="message-error"]')
                for error in errors:
                    error_text = " ".join([e.strip() for e in error.xpath('.//text()')]).strip()
                    error_text = " ".join(error_text.split()).strip() if bool(error_text) else error_text
                    if (bool(error_text) and (
                            error_text.startswith("[tpb124]") or
                            error_text.startswith("[tpb43]") or
                            error_text.startswith("[tpb10] Meta dc:Publisher") or
                            error_text.startswith("[tpb10] Meta dc:Date") or
                            error_text.startswith("[opf3g]") or
                            'element "h1" not allowed here' in error_text or
                            'element "h2" not allowed here' in error_text or
                            'element "h3" not allowed here' in error_text or
                            'element "h4" not allowed here' in error_text or
                            'element "h5" not allowed here' in error_text or
                            'element "h6" not allowed here' in error_text or
                            'token "toc-brief" invalid' in error_text
                            )):
                        continue  # ignorer disse feilmeldingene

                    if error_text.startswith("Incorrect file signature"):
                        magic_number = error.xpath('*[@class="message-details"]/*[last()]/*[last()]/text()')[0]
                        magic_number = " ".join(magic_number.split()).strip() if bool(magic_number) else magic_number

                        # JFIF already allowed: 0xFF 0xD8 0xFF 0xE0 0x?? 0x?? 0x4A 0x46 0x49 0x46

                        if magic_number.startswith("0xFF 0xD8 0xFF 0xDB"):  # Also allow JPEG RAW
                            continue
                        elif magic_number[:19] == "0xFF 0xD8 0xFF 0xE1" and magic_number[30:] == ("0x45 0x78 0x69 0x66"):  # Also allow EXIF
                            continue
                        else:
                            dtbook_validate_status = "ERROR"
                            self.utils.report.error(error_text)

                    else:
                        dtbook_validate_status = "ERROR"
                        self.utils.report.error(error_text)

            # get conversion report
            if os.path.isfile(report_file):
                with open(report_file, 'r') as result_report:
                    self.utils.report.attachment(result_report.readlines(),
                                                 os.path.join(self.utils.report.reportDir(), "report-dtbook.html"),
                                                 dtbook_validate_status)

            if dtbook_validate_status == "ERROR":
                self.utils.report.error("Klarte ikke å validere boken")
                return False

            if dtbook_validate_status == "WARN":
                self.utils.report.warn("DTBoken er ikke valid, men vi fortsetter alikevel.")

        self.utils.report.info("Konverterer fra Nordisk DTBook til Nordisk HTML...")
        temp_htmldir_obj = tempfile.TemporaryDirectory()
        temp_htmldir = temp_htmldir_obj.name
        temp_htmlfile = None
        with DaisyPipelineJob(self,
                              "nordic-dtbook-to-html",
                              {"dtbook": os.path.basename(dtbook), "fail-on-error": "false", "no-legacy": "false"},
                              pipeline_and_script_version=[
                                ("1.13.6", "1.4.6"),
                                ("1.13.4", "1.4.5"),
                                ("1.12.1", "1.4.2"),
                                ("1.11.1-SNAPSHOT", "1.3.0"),
                              ],
                              context=dtbook_context
                              ) as dp2_job_dtbook_to_html:
            convert_status = "SUCCESS" if dp2_job_dtbook_to_html.status == "SUCCESS" else "ERROR"

            convert_report_file = os.path.join(dp2_job_dtbook_to_html.dir_output, "html-report/report.xhtml")

            if convert_status != "SUCCESS":
                self.utils.report.error("Klarte ikke å konvertere boken fra DTBook til HTML")

                # get conversion report
                if os.path.isfile(convert_report_file):
                    with open(convert_report_file, 'r') as result_report:
                        self.utils.report.attachment(result_report.readlines(),
                                                     os.path.join(self.utils.report.reportDir(), "report-dtbook-to-html.html"),
                                                     convert_status)

                return False

            dp2_html_dir = os.path.join(dp2_job_dtbook_to_html.dir_output, "output-dir")

            if not os.path.isdir(dp2_html_dir):
                self.utils.report.error("Finner ikke 'output-dir' for den konverterte boken: {}".format(dp2_html_dir))
                return False

            Filesystem.copy(self.utils.report, dp2_html_dir, temp_htmldir)
            temp_htmlfile = os.path.join(temp_htmldir, metadata["identifier"] + ".xhtml")

        if not os.path.isfile(temp_htmlfile):
            self.utils.report.error("Finner ikke den konverterte boken: {}".format(temp_htmlfile))
            self.utils.report.info("Kanskje filnavnet er forskjellig fra IDen?")
            return False

        self.utils.report.info("Rydder opp i nordisk HTML")
        temp_html_xslt_output_obj = tempfile.NamedTemporaryFile()
        temp_html_xslt_output = temp_html_xslt_output_obj.name
        xslt = Xslt(self,
                    stylesheet=os.path.join(NordicDTBookToEpub.xslt_dir, NordicDTBookToEpub.uid, "nordic-cleanup-html.xsl"),
                    source=temp_htmlfile,
                    target=temp_html_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_html_xslt_output, temp_htmlfile)

        self.utils.report.info("Konverterer fra Nordisk HTML til Nordisk EPUB3...")

        # create context for Pipeline 2 job
        html_dir = os.path.dirname(temp_htmlfile)
        html_context = {}
        for root, dirs, files in os.walk(html_dir):
            for file in files:
                fullpath = os.path.join(root, file)
                relpath = os.path.relpath(fullpath, html_dir)
                html_context[relpath] = fullpath

        temp_epub_file_obj = tempfile.NamedTemporaryFile()
        temp_epub_file = temp_epub_file_obj.name
        with DaisyPipelineJob(self,
                              "nordic-html-to-epub3",
                              {"html": os.path.basename(temp_htmlfile), "fail-on-error": "false"},
                              pipeline_and_script_version=[
                                ("1.13.6", "1.4.6"),
                                ("1.13.4", "1.4.5"),
                                ("1.12.1", "1.4.2"),
                                ("1.11.1-SNAPSHOT", "1.3.0"),
                              ],
                              context=html_context
                              ) as dp2_job_html_to_epub:
            convert_status = "SUCCESS" if dp2_job_html_to_epub.status == "SUCCESS" else "ERROR"

            convert_report_file = os.path.join(dp2_job_html_to_epub.dir_output, "html-report/report.xhtml")

            if convert_status != "SUCCESS":
                self.utils.report.error("Klarte ikke å konvertere boken")

                # get conversion report
                if os.path.isfile(convert_report_file):
                    with open(convert_report_file, 'r') as result_report:
                        self.utils.report.attachment(result_report.readlines(),
                                                     os.path.join(self.utils.report.reportDir(), "report-html-to-epub3.html"),
                                                     convert_status)

                return False

            dp2_epub_file = os.path.join(dp2_job_html_to_epub.dir_output, "output-dir", metadata["identifier"] + ".epub")

            if not os.path.isfile(dp2_epub_file):
                self.utils.report.error("Finner ikke den konverterte boken: {}".format(dp2_epub_file))
                self.utils.report.info("Kanskje filnavnet er forskjellig fra IDen?")
                return False

            self.utils.report.info("Validerer Nordisk EPUB 3...")
            epub_file = dp2_epub_file.asFile()
            with DaisyPipelineJob(self,
                                  "nordic-epub3-validate",
                                  {"epub": os.path.basename(epub_file)},
                                  pipeline_and_script_version=[
                                    ("1.13.6", "1.4.6"),
                                    ("1.13.4", "1.4.5"),
                                    ("1.12.1", "1.4.2"),
                                    ("1.11.1-SNAPSHOT", "1.3.0"),
                                  ],
                                  context={
                                    os.path.basename(epub_file): epub_file
                                  }) as dp2_job_epub_validate:
                epub_validate_status = "SUCCESS" if dp2_job_epub_validate.status == "SUCCESS" else "ERROR"

                report_file = os.path.join(dp2_job_epub_validate.dir_output, "html-report/report.xhtml")

                if epub_validate_status == "ERROR":

                    # attach intermediary file from conversion
                    with open(temp_htmlfile, 'r') as intermediary_htmlfile:
                        self.utils.report.attachment(intermediary_htmlfile.readlines(),
                                                     os.path.join(self.utils.report.reportDir(), "intermediary-html.html"),
                                                     "DEBUG")

                    epub_validate_status = "WARN"

                    report_doc = ElementTree.parse(report_file)
                    errors = report_doc.xpath('//*[@class="error" or @class="message-error"]')
                    for error in errors:
                        error_text = " ".join([e.strip() for e in error.xpath('.//text()')]).strip()
                        error_text = " ".join(error_text.split()).strip() if bool(error_text) else error_text

                        if (bool(error_text) and (
                                error_text.startswith("[nordic280]") or
                                "PKG-021: Corrupted image file encountered." in error_text
                                )):
                            continue  # ignorer disse feilmeldingene
                        else:
                            self.utils.report.warn("Not ignoring: {}".format(error_text))

                        if error_text.startswith("Incorrect file signature"):
                            magic_number = error.xpath('*[@class="message-details"]/*[last()]/*[last()]/text()')[0]
                            magic_number = " ".join(magic_number.split()).strip() if bool(magic_number) else magic_number

                            # JFIF already allowed: 0xFF 0xD8 0xFF 0xE0 0x?? 0x?? 0x4A 0x46 0x49 0x46

                            if magic_number.startswith("0xFF 0xD8 0xFF 0xDB"):  # Also allow JPEG RAW
                                continue
                            elif magic_number[:19] == "0xFF 0xD8 0xFF 0xE1" and magic_number[30:] == ("0x45 0x78 0x69 0x66"):  # Also allow EXIF
                                continue
                            else:
                                epub_validate_status = "ERROR"
                                self.utils.report.error(error_text)

                        else:
                            epub_validate_status = "ERROR"
                            self.utils.report.error(error_text)

                # get conversion report
                if os.path.isfile(report_file):
                    with open(report_file, 'r') as result_report:
                        self.utils.report.attachment(result_report.readlines(),
                                                     os.path.join(self.utils.report.reportDir(), "report-epub3.html"),
                                                     epub_validate_status)

                if epub_validate_status == "ERROR":
                    self.utils.report.error("Klarte ikke å validere EPUB 3-versjonen av boken")
                    return False

            Filesystem.copy(self.utils.report, dp2_epub_file, temp_epub_file)

        epub = Epub(self.utils.report, temp_epub_file)
        if not epub.isepub():
            return False

        self.utils.report.info("Boken ble konvertert. Kopierer til EPUB3-fra-DTBook-arkiv.")
        archived_path, stored = self.utils.filesystem.storeBook(epub.asDir(), metadata["identifier"], overwrite=self.overwrite)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = "{}: {} ble konvertert 👍😄 ({})".format(self.title, metadata["identifier"], metadata["title"])
        return True


if __name__ == "__main__":
    NordicDTBookToEpub().run()
