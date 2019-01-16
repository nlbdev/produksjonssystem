#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NordicToNlbpub(Pipeline):
    uid = "nordic-epub-to-nlbpub"
    title = "Nordisk EPUB til NLBPUB"
    labels = ["EPUB", "Lydbok", "Punktskrift", "e-bok", "Statped"]
    publication_format = None
    expected_processing_time = 601

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

        temp_html_file_obj = tempfile.NamedTemporaryFile()
        temp_html_file = temp_html_file_obj.name

        temp_opf_file_obj = tempfile.NamedTemporaryFile()
        temp_opf_file = temp_opf_file_obj.name

        self.utils.report.info("Lager en kopi av EPUBen")
        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_epubdir)
        temp_epub = Epub(self, temp_epubdir)

        self.utils.report.info("Rydder opp i nordisk EPUB")
        nav_path = os.path.join(temp_epubdir, temp_epub.nav_path())
        for root, dirs, files in os.walk(temp_epubdir):
            for f in files:
                file = os.path.join(root, f)
                if not file.endswith(".xhtml"):
                    continue

                if file == nav_path:
                    xslt = Xslt(self,
                                stylesheet=os.path.join(Xslt.xslt_dir, NordicToNlbpub.uid, "nordic-cleanup-nav.xsl"),
                                source=file,
                                target=temp_html_file,
                                parameters={
                                    "cover": " ".join([item["href"] for item in temp_epub.spine()]),
                                    "base": os.path.dirname(os.path.join(temp_epubdir, temp_epub.opf_path())) + "/"
                                })
                    if not xslt.success:
                        return False
                    shutil.copy(temp_html_file, file)

                else:
                    xslt = Xslt(self,
                                stylesheet=os.path.join(Xslt.xslt_dir, NordicToNlbpub.uid, "nordic-cleanup-epub.xsl"),
                                source=file,
                                target=temp_html_file)
                    if not xslt.success:
                        return False
                    shutil.copy(temp_html_file, file)

        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NordicToNlbpub.uid, "nordic-cleanup-opf.xsl"),
                    source=os.path.join(temp_epubdir, temp_epub.opf_path()),
                    target=temp_opf_file)
        if not xslt.success:
            return False
        shutil.copy(temp_opf_file, os.path.join(temp_epubdir, temp_epub.opf_path()))
        temp_epub.refresh_metadata()

        html_dir_obj = tempfile.TemporaryDirectory()
        html_dir = html_dir_obj.name
        html_file = os.path.join(html_dir, epub.identifier() + ".xhtml")

        self.utils.report.info("Zipper oppdatert versjon av EPUBen...")
        temp_epub.asFile(rebuild=True)

        self.utils.report.info("Validerer Nordisk EPUB 3...")
        with DaisyPipelineJob(self, "nordic-epub3-validate", {"epub": temp_epub.asFile()}) as dp2_job_epub_validate:
            epub_validate_status = None
            if dp2_job_epub_validate.status == "DONE":
                epub_validate_status = "SUCCESS"
            elif dp2_job_epub_validate.status in ["VALIDATION_FAIL", "FAIL"]:
                epub_validate_status = "WARN"
            else:
                epub_validate_status = "ERROR"

            report_file = os.path.join(dp2_job_epub_validate.dir_output, "html-report/report.xhtml")

            if epub_validate_status == "WARN":
                report_doc = ElementTree.parse(report_file)
                errors = report_doc.xpath('//*[@class="error" or @class="message-error"]')
                for error in errors:
                    error_text = " ".join([e.strip() for e in error.xpath('.//text()')]).strip()
                    error_text = " ".join(error_text.split()).strip() if bool(error_text) else error_text
                    if (bool(error_text) and (
                            error_text.startswith("[opf") or
                            error_text.startswith("[nordic_nav") or
                            error_text.startswith("[nordic_opf") or
                            error_text.startswith("[nordic280]") or
                            "missing required attribute \"epub:prefix\"" in error_text or
                            "element \"title\" not allowed yet" in error_text or
                            "element \"style\" not allowed yet" in error_text or
                            "element \"meta\" not allowed yet" in error_text or
                            "element \"body\" incomplete; expected element \"header\" or \"nav\"" in error_text or
                            "Only UTF-8 and UTF-16 encodings are allowed" in error_text
                            )):
                        continue  # ignorer disse feilmeldingene; de forsvinner når vi konverterer til XHTML5

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
                                                 os.path.join(self.utils.report.reportDir(), "report-epub.html"),
                                                 epub_validate_status)

            if epub_validate_status == "ERROR":
                self.utils.report.error("Klarte ikke å validere boken")
                return False

            if epub_validate_status == "WARN":
                self.utils.report.warn("EPUBen er ikke valid, men vi fortsetter alikevel.")

        self.utils.report.info("Konverterer fra Nordisk EPUB 3 til Nordisk HTML 5...")
        with DaisyPipelineJob(self, "nordic-epub3-to-html", {"epub": temp_epub.asFile(), "fail-on-error": "false"}) as dp2_job_convert:
            convert_status = "SUCCESS" if dp2_job_convert.status == "DONE" else "ERROR"

            if convert_status != "SUCCESS":
                self.utils.report.error("Klarte ikke å konvertere boken")
                return False

            dp2_html_dir = os.path.join(dp2_job_convert.dir_output, "output-dir", epub.identifier())
            dp2_html_file = os.path.join(dp2_job_convert.dir_output, "output-dir", epub.identifier(), epub.identifier() + ".xhtml")

            if not os.path.isdir(dp2_html_dir):
                self.utils.report.error("Finner ikke den konverterte boken: {}".format(dp2_html_dir))
                return False

            if not os.path.isfile(dp2_html_file):
                self.utils.report.error("Finner ikke den konverterte boken: {}".format(dp2_html_file))
                self.utils.report.info("Kanskje filnavnet er forskjellig fra IDen?")
                return False

            self.utils.report.info("Validerer Nordisk HTML 5...")
            with DaisyPipelineJob(self, "nordic-html-validate", {"html": dp2_html_file}) as dp2_job_html_validate:
                html_validate_status = "SUCCESS" if dp2_job_html_validate.status == "DONE" else "ERROR"

                report_file = os.path.join(dp2_job_html_validate.dir_output, "html-report/report.xhtml")

                if html_validate_status == "ERROR":
                    html_validate_status = "WARN"

                    report_doc = ElementTree.parse(report_file)
                    errors = report_doc.xpath('//*[@class="error" or @class="message-error"]')
                    for error in errors:
                        error_text = error.xpath('.//text()[normalize-space()]')[0]
                        error_text = " ".join(error_text.split()).strip() if bool(error_text) else error_text

                        if (bool(error_text) and (
                                error_text.startswith("[nordic280]")
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
                                html_validate_status = "ERROR"
                                self.utils.report.error(error_text)

                        else:
                            html_validate_status = "ERROR"
                            self.utils.report.error(error_text)

                # get conversion report
                if os.path.isfile(report_file):
                    with open(report_file, 'r') as result_report:
                        self.utils.report.attachment(result_report.readlines(),
                                                     os.path.join(self.utils.report.reportDir(), "report-html.html"),
                                                     html_validate_status)

                if html_validate_status == "ERROR":
                    self.utils.report.error("Klarte ikke å validere HTML-versjonen av boken")
                    return False

            self.utils.filesystem.copy(dp2_html_dir, html_dir)

        self.utils.report.info("Rydder opp i nordisk HTML")
        xslt = Xslt(self, stylesheet=os.path.join(Xslt.xslt_dir, NordicToNlbpub.uid, "nordic-cleanup.xsl"),
                    source=html_file,
                    target=temp_html_file)
        if not xslt.success:
            return False
        shutil.copy(temp_html_file, html_file)

        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NordicToNlbpub.uid, "update-epub-prefixes.xsl"),
                    source=html_file,
                    target=temp_html_file)
        if not xslt.success:
            return False
        shutil.copy(temp_html_file, html_file)

        self.utils.report.info("Legger til EPUB-filer (OPF, NAV, container.xml, mediatype)...")
        nlbpub_tempdir_obj = tempfile.TemporaryDirectory()
        nlbpub_tempdir = nlbpub_tempdir_obj.name

        nlbpub = Epub.from_html(self, html_dir, nlbpub_tempdir)
        if nlbpub is None:
            return False

        self.utils.report.info("Boken ble konvertert. Kopierer til NLBPUB-arkiv.")
        archived_path, stored = self.utils.filesystem.storeBook(nlbpub.asDir(), temp_epub.identifier(), overwrite=self.overwrite)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    NordicToNlbpub().run()
