#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import shutil
import subprocess
import sys
import tempfile
import traceback

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.daisy_pipeline import DaisyPipelineJob
from core.utils.epub import Epub
from core.utils.filesystem import Filesystem
from core.utils.mathml_to_text import Mathml_validator
from core.utils.xslt import Xslt

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class IncomingNordic(Pipeline):
    uid = "incoming-nordic"
    title = "Validering av Nordisk EPUB 3"
    labels = ["EPUB", "Statped"]
    publication_format = None
    expected_processing_time = 1400

    ace_cli = None

    @staticmethod
    def init_environment():
        if "ACE_CLI" in Pipeline.environment:
            IncomingNordic.ace_cli = Pipeline.environment["ACE_CLI"]
        elif os.path.exists("/usr/bin/ace"):
            IncomingNordic.ace_cli = "/usr/bin/ace"
        else:
            IncomingNordic.ace_cli = "ace"

    def __init__(self, *args, **kwargs):
        IncomingNordic.init_environment()
        super().__init__(*args, **kwargs)

    def on_book_deleted(self):
        self.utils.report.should_email = False
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: "+self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: "+self.book['name'])
        return self.on_book()

    def on_book(self):
        epub = Epub(self.utils.report, self.book["source"])
        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass
        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return

        self.utils.report.info("Lager en kopi av EPUBen med tomme bildefiler")
        temp_noimages_epubdir_obj = tempfile.TemporaryDirectory()
        temp_noimages_epubdir = temp_noimages_epubdir_obj.name
        Filesystem.copy(self.utils.report, epub.asDir(), temp_noimages_epubdir)
        if os.path.isdir(os.path.join(temp_noimages_epubdir, "EPUB", "images")):
            temp_xml_obj = tempfile.NamedTemporaryFile()
            temp_xml = temp_xml_obj.name
            opf_image_references = []
            html_image_references = {}
            for root, dirs, files in os.walk(os.path.join(temp_noimages_epubdir, "EPUB")):
                for file in files:
                    if file.endswith(".opf"):
                        opf_file = os.path.join(root, file)
                        self.utils.report.info("Fjerner alle bildereferanser fra OPFen, og erstatter med en referanse til dummy.jpg...")
                        opf_xml_document = ElementTree.parse(opf_file)
                        opf_xml = opf_xml_document.getroot()
                        image_items = opf_xml.xpath("//*[local-name()='item' and starts-with(@media-type, 'image/')]")
                        replaced = False
                        for image_item in image_items:
                            if image_item.attrib["href"] not in opf_image_references:
                                opf_image_references.append(image_item.attrib["href"])

                            if image_item.get("href") == "images/cover.jpg":
                                pass  # don't change the reference to cover.jpg

                            elif not replaced:
                                image_item.attrib["href"] = "images/dummy.jpg"
                                replaced = True

                            else:
                                image_item.getparent().remove(image_item)

                        opf_xml_document.write(opf_file, method='XML', xml_declaration=True, encoding='UTF-8', pretty_print=False)

                    if file.endswith(".xhtml"):
                        html_file = os.path.join(root, file)

                        html_xml_document = ElementTree.parse(html_file)
                        html_xml = html_xml_document.getroot()
                        image_references = html_xml.xpath("//@href | //@src | //@altimg")
                        for reference in image_references:
                            path = reference.split("#")[0]
                            if path.startswith("images/"):
                                if path not in html_image_references:
                                    html_image_references[path] = []
                                html_image_references[path].append(file)

                        self.utils.report.info("Erstatter alle bildereferanser med images/dummy.jpg...")
                        self.utils.report.debug("dummy-jpg.xsl")
                        self.utils.report.debug("    source = " + html_file)
                        self.utils.report.debug("    target = " + temp_xml)
                        xslt = Xslt(self,
                                    stylesheet=os.path.join(Xslt.xslt_dir, IncomingNordic.uid, "dummy-jpg.xsl"),
                                    source=html_file,
                                    target=temp_xml)
                        if not xslt.success:
                            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                            return False
                        shutil.copy(temp_xml, html_file)

            # validate for the presence of image files here, since epubcheck won't be able to do it anymore after we change the EPUB
            image_files_present = []
            for root, dirs, files in os.walk(os.path.join(temp_noimages_epubdir, "EPUB", "images")):
                for file in files:
                    fullpath = os.path.join(root, file)
                    relpath = os.path.relpath(fullpath, os.path.join(temp_noimages_epubdir, "EPUB"))
                    image_files_present.append(relpath)
            image_error = False
            for file in image_files_present:
                if file not in opf_image_references:
                    self.utils.report.error("Bildefilen er ikke deklarert i OPFen: " + file)
                    image_error = True
            for file in opf_image_references:
                if file not in image_files_present:
                    self.utils.report.error("Bildefilen er deklarert i OPFen, men finnes ikke: " + file)
                    image_error = True
            for file in html_image_references:
                if file not in opf_image_references:
                    self.utils.report.error("Bildefilen er deklarert i HTMLen, men finnes ikke: " + file
                                            + " (deklarert i: " + ", ".join(html_image_references[file]) + ")")
                    image_error = True
            if image_error:
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return False

            for root, dirs, files in os.walk(os.path.join(temp_noimages_epubdir, "EPUB", "images")):
                for file in files:
                    if file == "cover.jpg":
                        continue  # don't delete the cover file
                    fullpath = os.path.join(root, file)
                    os.remove(fullpath)
            shutil.copy(os.path.join(Xslt.xslt_dir, IncomingNordic.uid, "reference-files", "demobilde.jpg"),
                        os.path.join(temp_noimages_epubdir, "EPUB", "images", "dummy.jpg"))

        temp_noimages_epub = Epub(self.utils.report, temp_noimages_epubdir)

        self.utils.report.info("Validerer EPUB med epubcheck og nordiske retningslinjer...")
        epub_noimages_file = temp_noimages_epub.asFile()
        with DaisyPipelineJob(self,
                              "nordic-epub3-validate",
                              {"epub": os.path.basename(epub_noimages_file)},
                              priority="high",
                              pipeline_and_script_version=[
                                ("1.13.6", "1.4.6"),
                                ("1.13.4", "1.4.5"),
                                ("1.12.1", "1.4.2"),
                                ("1.11.1-SNAPSHOT", "1.3.0"),
                              ],
                              context={
                                os.path.basename(epub_noimages_file): epub_noimages_file
                              }) as dp2_job:

            # get validation report
            report_file = os.path.join(dp2_job.dir_output, "html-report/report.xhtml")
            if os.path.isfile(report_file):
                with open(report_file, 'r') as result_report:
                    self.utils.report.attachment(result_report.readlines(),
                                                 os.path.join(self.utils.report.reportDir(), "report.html"),
                                                 "SUCCESS" if dp2_job.status == "SUCCESS" else "ERROR")

            if dp2_job.status != "SUCCESS":
                self.utils.report.error("Klarte ikke å validere boken")
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return

        self.utils.report.debug("Making a copy of the EPUB to work on…")
        epub_fixed, epub_fixed_obj = epub.copy()
        epub_unzipped = epub_fixed.asDir()
        nav_path = os.path.join(epub_unzipped, epub_fixed.nav_path())
        mathML_validation_result = True
        mathml_error_count = 0
        mathml_errors_not_shown = 0
        mathml_report_errors_max = 10
        for root, dirs, files in os.walk(epub_unzipped):
            for f in files:
                file = os.path.join(root, f)
                if not file.endswith(".xhtml") or file is nav_path:
                    continue
                self.utils.report.info("Checking MathML in " + file)
                mathml_validation = Mathml_validator(self, source=file, report_errors_max=mathml_report_errors_max)
                if not mathml_validation.success:
                    mathml_error_count += mathml_validation.error_count
                    mathml_errors_not_shown += max((mathml_validation.error_count - mathml_report_errors_max), 0)
                    if mathml_error_count > mathml_report_errors_max:
                        mathml_report_errors_max = 0  # don't put any more errors for the other HTML documents in the main report
                    mathML_validation_result = False
        if mathml_errors_not_shown > 0:
            self.utils.report.error("{} additional MathML errors not shown in the main report. Check the log for details.".format(mathml_errors_not_shown))
        if mathML_validation_result is False:
            return False

        self.utils.report.debug("Making sure that the EPUB has the correct file and directory permissions…")
        epub_fixed.fix_permissions()

        try:
            self.utils.report.info("Genererer ACE-rapport...")
            ace_dir = os.path.join(self.utils.report.reportDir(), "accessibility-report")
            process = self.utils.filesystem.run([IncomingNordic.ace_cli, "-o", ace_dir, epub_fixed.asFile()])
            if process.returncode == 0:
                self.utils.report.info("ACE-rapporten ble generert.")
            else:
                self.utils.report.warn("En feil oppstod ved produksjon av ACE-rapporten for " + epub.identifier())
                self.utils.report.debug(traceback.format_stack())

            # attach report
            ace_status = None
            with open(os.path.join(ace_dir, "report.json")) as json_report:
                ace_status = json.load(json_report)["earl:result"]["earl:outcome"]
            if ace_status == "pass":
                ace_status = "SUCCESS"
            else:
                ace_status = "WARN"
            self.utils.report.attachment(None, os.path.join(ace_dir, "report.html"), ace_status)

        except subprocess.TimeoutExpired:
            self.utils.report.warn("Det tok for lang tid å lage ACE-rapporten for " + epub.identifier() + ", og prosessen ble derfor stoppet.")

        except Exception:
            self.utils.report.warn("En feil oppstod ved produksjon av ACE-rapporten for " + epub.identifier())
            self.utils.report.debug(traceback.format_exc(), preformatted=True)

        self.utils.report.info("Boken er valid. Kopierer til EPUB master-arkiv.")

        archived_path, stored = self.utils.filesystem.storeBook(epub_fixed.asDir(), epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " er valid 👍😄" + epubTitle
        self.utils.filesystem.deleteSource()
        return True


if __name__ == "__main__":
    IncomingNordic().run()
