#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import mimetypes
import os
import sys
import tempfile
import traceback

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.metadata import Metadata
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


def transfer_metadata_from_html_to_pef(html_file, pef_file, additional_metadata):
    html_xml = ElementTree.parse(html_file).getroot()
    pef_xml_document = ElementTree.parse(pef_file)
    pef_xml = pef_xml_document.getroot()
    html_meta_elements = html_xml.xpath("/*/*[local-name()='head']/*")
    pef_meta = pef_xml.xpath("/*/*[local-name()='head']/*[local-name()='meta']")[0]
    pef_meta_elements = pef_xml.xpath("/*/*[local-name()='head']/*[local-name()='meta']/*")

    dc = "{http://purl.org/dc/elements/1.1/}"
    tail = None
    lasttail = None
    for meta in pef_meta_elements:
        if tail is None:
            tail = meta.tail
        lasttail = meta.tail
        if meta.tag in [f"{dc}format", f"{dc}date"] or meta.tag.endswith("sheet-count"):
            meta.tail = tail  # keep, and make sure the trailing whitespace is the same for all elements

    for meta in html_meta_elements:
        tag = None
        text = None
        name = meta.tag.split("}")[-1]
        namespace = None
        namespace = meta.tag.split("}")[0].split("{")[-1]

        # title has its own element in HTML, so we need to handle it explicitly here
        if name == "title":
            namespace = "http://purl.org/dc/elements/1.1/"
            tag = "{" + namespace + "}title"
            text = meta.text

        # meta charset, link, script etc.
        elif name != "meta" or "name" not in meta.attrib or "content" not in meta.attrib:
            continue  # not relevant

        # we use the dc:format from the preexisting PEF metadata, and ignore some other metadata as well
        elif meta.attrib["name"] in ["dc:format", "dcterms:modified", "viewport"]:
            continue  # ignore these

        # description doesn't use a prefix in HTML, so we need to handle it explicitly here
        elif meta.attrib["name"] == "description":
            namespace = "http://purl.org/dc/elements/1.1/"
            tag = "{" + namespace + "}description.abstract"
            text = meta.attrib["content"]

        # all other meta elements
        else:
            prefix = meta.attrib["name"].split(":")[0] if ":" in meta.attrib["name"] else None
            namespace = None
            if prefix is not None:
                namespace = meta.nsmap.get(prefix)
            if namespace is None:
                continue  # namespace not found - only metadata with a namespace will (can) be included

            tag = "{" + namespace + "}" + meta.attrib["name"].split(":")[1]
            text = meta.attrib["content"]

        element = ElementTree.Element(tag, nsmap={prefix: meta.nsmap[prefix] for prefix in meta.nsmap if meta.nsmap[prefix] == namespace})
        element.text = text
        if namespace == "http://purl.org/dc/elements/1.1/":
            element = ElementTree.Comment(" " + ElementTree.tounicode(element) + " ")
        element.tail = tail
        pef_meta.append(element)

    for (tagname, prefix, namespace, attribname, value) in additional_metadata:
        element = ElementTree.Element("{" + namespace + "}" + tagname, nsmap={prefix: namespace})
        if attribname is not None:
            element.attrib["name"] = attribname
        element.text = value
        if namespace == "http://purl.org/dc/elements/1.1/":
            element = ElementTree.Comment(" " + ElementTree.tounicode(element) + " ")
        element.tail = tail
        pef_meta.append(element)

    # set correct whitespace trailing the last meta element
    pef_meta.xpath("*")[-1].tail = lasttail

    pef_xml_document.write(pef_file, method='XML', xml_declaration=True, encoding='UTF-8', pretty_print=False)


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
        Filesystem.copy(self.utils.report, self.book["source"], temp_htmldir)

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

        # create context for Pipeline 2 job
        html_dir = os.path.dirname(html_file)
        html_context = {}
        for root, dirs, files in os.walk(html_dir):
            for file in files:
                kind = mimetypes.guess_type(file)[0]
                if kind is not None and kind.split("/")[0] in ["image", "video", "audio"]:
                    continue  # ignore media files
                fullpath = os.path.join(root, file)
                relpath = os.path.relpath(fullpath, html_dir)
                html_context[relpath] = fullpath

        script_id = "nlb:html-to-pef"
        pipeline_and_script_version = [
            ("1.11.1-SNAPSHOT", "1.10.0-SNAPSHOT"),
        ]
        braille_arguments = {
            "source": os.path.basename(html_file),
            "braille-standard": "(dots:6)(grade:0)",
            "line-spacing": line_spacing,
            "duplex": duplex,
        }

        # for custom Statped options using NLBs PIP (remove `and False` or replace with `or True` to test)
        if metadata["library"].lower() == "statped" and False:
            # see: https://github.com/nlbdev/pipeline/blob/nlb/nlb/book-to-pef/src/main/resources/xml/html-to-pef.xpl#L146-L167
            #
            # (1) 'http://www.nlb.no/pipeline/modules/braille/pre-processing.xsl',
            # (2) 'http://www.daisy.org/pipeline/modules/braille/xml-to-pef/generate-toc.xsl',
            # (3) if ($default-table-class = '') then resolve-uri('add-table-classes.xsl') else (),
            # (4) if ($insert-boilerplate = 'true') then 'http://www.nlb.no/pipeline/modules/braille/insert-boilerplate.xsl' else (),
            # (5) if ($apply-default-stylesheet = 'true') then 'http://www.nlb.no/pipeline/modules/braille/default.scss' else (),
            # (6) if ($stylesheet) then tokenize($stylesheet,',') else ()),' ')"/>

            braille_arguments["insert-boilerplate"] = "false"  # disable (4)
            braille_arguments["apply-default-stylesheet"] = "false"  # disable (5)

            # (1-3) will still be included. Specifying (6) let's us include replacements for (4) and (5)
            braille_arguments["stylesheet"] = ",".join([
                "http://www.nlb.no/pipeline/modules/braille/insert-boilerplate.xsl",
                "https://raw.githubusercontent.com/StatpedEPUB/nlb-scss/master/src/scss/braille.scss"
            ])

        # for custom Statped options using DAISYs PIP (remove `and False` or replace with `or True` to test)
        if metadata["library"].lower() == "statped" and False:
            # use DAISYs version of PIP instead
            script_id = "html-to-pef"
            pipeline_and_script_version = [
                ("1.14.2", "4.1.0"),
            ]

            braille_arguments = {
                "html": os.path.basename(html_file),
                "transform": "(translator:liblouis)(formatter:dotify)(lang:no)(dots:6)(grade:0)",
                "stylesheet": " ".join([
                    # 1. better volume breaking, and also removes title page and print toc, moves the colophon and copyright page to the end of the book
                    # "https://raw.githubusercontent.com/nlbdev/pipeline/nlb/nlb/book-to-pef/src/main/resources/xml/pre-processing.xsl",

                    # 2. DAISY: TOC generation
                    # "https://raw.githubusercontent.com/daisy/pipeline/master/modules/braille/xml-to-pef/src/main/resources/xml/xslt/generate-toc.xsl",

                    # 3. NLB: Add table classes based on the dimensions of the table, for better handling of tables
                    # "https://raw.githubusercontent.com/nlbdev/pipeline/nlb/nlb/book-to-pef/src/main/resources/xml/add-table-classes.xsl",

                    # 4. NLB: Generate a new title page and about page in the frontmatter
                    # "https://raw.githubusercontent.com/nlbdev/pipeline/nlb/nlb/book-to-pef/src/main/resources/xml/insert-boilerplate.xsl",

                    # 5. Statped-specific SCSS
                    "https://raw.githubusercontent.com/StatpedEPUB/nlb-scss/master/src/scss/braille.scss",
                ]),
                "line-spacing": line_spacing,
                "duplex": duplex,
            }

        pef_tempdir_object = tempfile.TemporaryDirectory()

        self.utils.report.info("Konverterer fra HTML til PEF...")
        found_pipeline_version = None
        found_script_version = None
        with DaisyPipelineJob(self,
                              script_id,
                              braille_arguments,
                              pipeline_and_script_version=pipeline_and_script_version,
                              context=html_context
                              ) as dp2_job:
            found_pipeline_version = dp2_job.found_pipeline_version
            found_script_version = dp2_job.found_script_version

            # get conversion report
            if os.path.isdir(os.path.join(dp2_job.dir_output, "preview-output-dir")):
                Filesystem.copy(self.utils.report,
                                os.path.join(dp2_job.dir_output, "preview-output-dir"),
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

            Filesystem.copy(self.utils.report, dp2_pef_dir, pef_tempdir_object.name)

            self.utils.report.info("Boken ble konvertert.")

        self.utils.report.info("Kopierer metadata fra HTML til PEF...")
        try:
            pef_file = None
            for root, dirs, files in os.walk(pef_tempdir_object.name):
                for f in files:
                    if f.endswith(".pef"):
                        pef_file = os.path.join(root, f)
            if not pef_file or not os.path.isfile(pef_file):
                self.utils.report.error(self.book["name"] + ": Klarte ikke å finne en PEF-fil.")
            else:
                additional_metadata = []
                additional_metadata.append(("daisy-pipeline-engine-version", "nlbprod", "http://www.nlb.no/production", None, found_pipeline_version))
                additional_metadata.append(("daisy-pipeline-script-id", "nlbprod", "http://www.nlb.no/production", None, script_id))
                additional_metadata.append(("daisy-pipeline-script-version", "nlbprod", "http://www.nlb.no/production", None, found_script_version))
                for argument in braille_arguments:
                    if argument in ["source", "html"]:
                        continue  # skip HTML file path
                    values = braille_arguments[argument]
                    values = values if isinstance(values, list) else [values]
                    for value in values:
                        additional_metadata.append(("daisy-pipeline-argument", "nlbprod", "http://www.nlb.no/production", argument, value))

                transfer_metadata_from_html_to_pef(html_file, pef_file, additional_metadata)

        except Exception:
            self.utils.report.warning(traceback.format_exc(), preformatted=True)
            self.utils.report.error("An error occured while trying to insert metadata about the conversion")

        self.utils.report.info("Kopierer til PEF-arkiv.")
        archived_path, stored = self.utils.filesystem.storeBook(pef_tempdir_object.name, identifier)
        self.utils.report.attachment(None, archived_path, "DEBUG")

        self.utils.report.title = self.title + ": " + identifier + " ble konvertert 👍😄" + bookTitle
        return True


if __name__ == "__main__":
    NlbpubToPef().run()
