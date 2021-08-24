#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
from pathlib import Path

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.mathml_to_text import Mathml_to_text, Mathml_validator
from core.utils.metadata import Metadata
from core.utils.relaxng import Relaxng
from core.utils.schematron import Schematron
from core.utils.xslt import Xslt
from nlbpub_to_narration_epub import NlbpubToNarrationEpub
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubToTtsDtbook(Pipeline):
    uid = "nlbpub-to-tts-dtbook"
    title = "NLBPUB til DTBook for talesyntese"
    labels = ["Lydbok", "Statped"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 300

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
        epub = Epub(self.utils.report, self.book["source"])
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
        Filesystem.copy(self.utils.report, os.path.dirname(html_file), temp_resultdir)
        temp_result = os.path.join(temp_resultdir, identifier + ".xml")

        self.utils.report.info("sletter EPUB-spesifikke filer")
        for root, dirs, files in os.walk(temp_resultdir):
            for file in files:
                if Path(file).suffix.lower() in [".xhtml", ".html", ".smil", ".mp3", ".wav", ".opf"]:
                    os.remove(os.path.join(root, file))
        shutil.copy(html_file, temp_result)

        temp_xslt_output_obj = tempfile.NamedTemporaryFile()
        temp_xslt_output = temp_xslt_output_obj.name

        # MATHML to stem
        self.utils.report.info("Erstatter evt. MathML i boka...")
        mathml_validation = Mathml_validator(self, source=temp_result)
        if not mathml_validation.success:
            return False

        mathML_result = Mathml_to_text(self, source=temp_result, target=temp_result)

        if not mathML_result.success:
            return False

        self.utils.report.info("Fikser Webarch-oppmerking")
        self.utils.report.debug("webarch-fixup.xsl")
        self.utils.report.debug("    source = " + temp_result)
        self.utils.report.debug("    target = " + temp_xslt_output)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToNarrationEpub.uid, "webarch-fixup.xsl"),
                    source=temp_result,
                    target=temp_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_xslt_output, temp_result)

        self.utils.report.info("Setter inn lydbokavtalen...")
        self.utils.report.debug("bokinfo-tts-dtbook.xsl")
        self.utils.report.debug("    source = " + temp_result)
        self.utils.report.debug("    target = " + temp_xslt_output)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "bokinfo-tts-dtbook.xsl"),
                    source=temp_result,
                    target=temp_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_xslt_output, temp_result)

        creative_work_metadata = None
        timeout = 0

        while creative_work_metadata is None and timeout < 5:

            timeout = timeout + 1
            creative_work_metadata = Metadata.get_creative_work_from_api(identifier, editions_metadata="all", use_cache_if_possible=True, creative_work_metadata="all")
            if creative_work_metadata is not None:
                if creative_work_metadata["magazine"] is True:
                    self.utils.report.info("Fjerner sidetall fordi det er et tidsskrift...")
                    self.utils.report.debug("remove-pagenum.xsl")
                    self.utils.report.debug("    source = " + temp_result)
                    self.utils.report.debug("    target = " + temp_xslt_output)
                    xslt = Xslt(self,
                                stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "remove-pagenum.xsl"),
                                source=temp_result,
                                target=temp_xslt_output)
                    if not xslt.success:
                        return False
                    shutil.copy(temp_xslt_output, temp_result)
                break

        if creative_work_metadata is None:
            self.utils.report.warning("Klarte ikke finne et åndsverk tilknyttet denne utgaven. Konverterer likevel.")

        library = epub.meta("schema:library")
        library = library.upper() if library else library
        logo = os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "{}_logo.png".format(library))

        if os.path.isfile(logo):
           # epub_dir = os.path.join(temp_resultdir, "EPUB")
            image_dir = os.path.join(temp_resultdir, "images")
            if not os.path.isdir(image_dir):
                os.mkdir(image_dir)
            shutil.copy(logo, image_dir)

        self.utils.report.info("Konverterer fra XHTML5 til DTBook...")
        self.utils.report.debug("html-to-dtbook.xsl")
        self.utils.report.debug("    source = " + temp_result)
        self.utils.report.debug("    target = " + temp_xslt_output)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "html-to-dtbook.xsl"),
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
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "dtbook-cleanup.xsl"),
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
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "optimaliser-komplekst-innhold.xsl"),
                    source=temp_result,
                    target=temp_xslt_output)
        if not xslt.success:
            return False
        shutil.copy(temp_xslt_output, temp_result)

        self.utils.report.info("Validerer DTBook...")
        # NOTE: This RelaxNG schema assumes that we're using DTBook 2005-3 and MathML 3.0
        dtbook_relax = Relaxng(self,
                               relaxng=os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "dtbook-schema/rng/dtbook-2005-3.mathml-3.integration.rng"),
                               source=temp_result)
        dtbook_sch = Schematron(self,
                                schematron=os.path.join(Xslt.xslt_dir, NlbpubToTtsDtbook.uid, "dtbook-schema/sch/dtbook.mathml.sch"),
                                source=temp_result)
        if not dtbook_relax.success:
            self.utils.report.error("Validering av DTBook feilet (RelaxNG)")
        if not dtbook_sch.success:
            self.utils.report.error("Validering av DTBook feilet (Schematron)")
        if not dtbook_relax.success or not dtbook_sch.success:
            tempfile_stored = os.path.join(self.utils.report.reportDir(), os.path.basename(temp_result))
            shutil.copy(temp_result, tempfile_stored)
            self.utils.report.info(f"Validering av DTBook feilet, lagrer temp fil for feilsøking: {tempfile_stored}")
            self.utils.report.attachment(None, tempfile_stored, "DEBUG")
            return False

        self.utils.report.info("Boken ble konvertert. Kopierer til DTBook-arkiv.")
        archived_path, stored = self.utils.filesystem.storeBook(temp_resultdir, identifier)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        return True


if __name__ == "__main__":
    NlbpubToTtsDtbook().run()
