#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tempfile

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.metadata import Metadata
from core.utils.daisy_pipeline import DaisyPipelineJob

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubToPef(Pipeline):
    uid = "nlbpub-to-pef"
    title = "NLBPUB til PEF"
    labels = ["Punktskrift", "Statped"]
    publication_format = "Braille"
    expected_processing_time = 880

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " HTML-kilde slettet: " + self.book['name']
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")

        self.utils.report.info("Lager en kopi av filsettet")
        temp_htmldir_obj = tempfile.TemporaryDirectory()
        temp_htmldir = temp_htmldir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_htmldir)

        self.utils.report.info("Finner HTML-fila")
        html_file = None
        for root, dirs, files in os.walk(temp_htmldir):
            for f in files:
                if f.endswith("html"):
                    html_file = os.path.join(root, f)
        if not html_file or not os.path.isfile(html_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne en HTML-fil.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        html_xml = ElementTree.parse(html_file).getroot()
        identifier = html_xml.xpath("/*/*[local-name()='head']/*[@name='dc:identifier']")

        metadata = Metadata.get_metadata_from_book(self, temp_htmldir)

        line_spacing = "single"
        duplex = "true"
        for e in html_xml.xpath("/*/*[local-name()='head']/*[@name='dc:format.linespacing']"):
            if "double" == e.attrib["content"]:
                line_spacing = "double"
        for e in html_xml.xpath("/*/*[local-name()='head']/*[@name='dc:format.printing']"):
            if "single-sided" == e.attrib["content"]:
                duplex = "false"
        self.utils.report.info("Linjeavstand: {}".format("åpen" if line_spacing == "double" else "enkel"))
        self.utils.report.info("Trykk: {}".format("enkeltsidig" if duplex == "false" else "dobbeltsidig"))

        bookTitle = ""
        bookTitle = " (" + html_xml.xpath("string(/*/*[local-name()='head']/*[local-name()='title']/text())") + ") "

        identifier = identifier[0].attrib["content"] if identifier and "content" in identifier[0].attrib else None
        if not identifier:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne boknummer i HTML-fil.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False
        epub_identifier = html_xml.xpath("/*/*[local-name()='head']/*[@name='nlbprod:identifier.epub']")
        epub_identifier = epub_identifier[0].attrib["content"] if epub_identifier and "content" in epub_identifier[0].attrib else None

        # ---------- konverter til PEF ----------

        braille_arguments = {
            "source": os.path.basename(html_file),
            "braille-standard": "(dots:6)(grade:0)",
            "line-spacing": line_spacing,
            "duplex": duplex
        }

        if metadata["library"].lower() == "statped":
            braille_arguments["apply-default-stylesheet"] = False
            braille_arguments["stylesheet"] = "https://raw.githubusercontent.com/StatpedEPUB/nlb-scss/master/src/scss/braille.scss"

        pef_tempdir_object = tempfile.TemporaryDirectory()

        # create context for Pipeline 2 job
        html_dir = os.path.dirname(html_file)
        html_context = {}
        for root, dirs, files in os.walk(html_dir):
            for file in files:
                fullpath = os.path.join(root, file)
                relpath = os.path.relpath(fullpath, html_dir)
                html_context[relpath] = fullpath

        self.utils.report.info("Konverterer fra HTML til PEF...")
        with DaisyPipelineJob(self,
                              "nlb:html-to-pef",
                              braille_arguments,
                              pipeline_and_script_version=("1.11.1-SNAPSHOT", "1.10.0-SNAPSHOT"),
                              context=html_context
                              ) as dp2_job:

            # get conversion report
            if os.path.isdir(os.path.join(dp2_job.dir_output, "preview-output-dir")):
                self.utils.filesystem.copy(os.path.join(dp2_job.dir_output, "preview-output-dir"),
                                           os.path.join(self.utils.report.reportDir(), "preview"))
                self.utils.report.attachment(None,
                                             os.path.join(self.utils.report.reportDir(), "preview" + "/" + identifier + ".pef.html"),
                                             "SUCCESS" if dp2_job.status == "SUCCESS" else "ERROR")

            if dp2_job.status != "SUCCESS":
                self.utils.report.info("Klarte ikke å konvertere boken")
                self.utils.report.title = self.title + ": " + identifier + " feilet 😭👎" + bookTitle
                return False

            dp2_pef_dir = os.path.join(dp2_job.dir_output, "pef-output-dir")

            if not os.path.isdir(dp2_pef_dir):
                self.utils.report.info("Finner ikke den konverterte boken.")
                self.utils.report.title = self.title + ": " + identifier + " feilet 😭👎" + bookTitle
                return False

            self.utils.filesystem.copy(dp2_pef_dir, pef_tempdir_object.name)

            self.utils.report.info("Boken ble konvertert.")

        self.utils.report.info("Kopierer til PEF-arkiv.")
        archived_path, stored = self.utils.filesystem.storeBook(pef_tempdir_object.name, identifier)
        self.utils.report.attachment(None, archived_path, "DEBUG")

        self.utils.report.title = self.title + ": " + identifier + " ble konvertert 👍😄" + bookTitle
        return True


if __name__ == "__main__":
    NlbpubToPef().run()
