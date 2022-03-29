#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import shutil
import sys
import tempfile

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from core.utils.filesystem import Filesystem
from core.utils.api import Api

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubToTex(Pipeline):
    uid = "nlbpub-to-latex"
    title = "NLBPUB til LaTeX"
    labels = ["e-bok","Statped"]
    publication_format = "TeX"
    expected_processing_time = 550

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB master slettet: " + self.book['name']

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")
        epub = Epub(self.utils.report, self.book["source"])

        # ---------- convert to XHTML ----------
        # create a temporary directory for the XHTML
        xhtml_dir = tempfile.mkdtemp()
        xhtml_dir = os.path.join(xhtml_dir, "xhtml")

        # grab the XHTML from the EPUB
        xhtml_files = epub.extract_xhtml_files()

        # copy the XHTML files to the temporary directory
        for xhtml_file in xhtml_files:
            shutil.copy(xhtml_file, xhtml_dir)

        # send the XHTML files API
        xhtml_files = Filesystem.list_files(xhtml_dir)
        for xhtml_file in xhtml_files:
            xhtml_file_name = os.path.basename(xhtml_file)
            xhtml_file_content = Filesystem.read_file(xhtml_file)
            # request xhtml_file_content to be sent to the API and get back a LaTeX file
            response = Api.get("/systems/latex/html", str(xhtml_file_content), { "content-type": "text/html", "content-length": str(len(xhtml_file_content)), "Accept": "text/plain" })

            # write the LaTeX file to a temporary directory
            latex_file = os.path.join(tempfile.mkdtemp(), xhtml_file_name+".tex")
            Filesystem.write_file(latex_file, response.text)

            # copy the LaTeX file to the book directory
            latex_file_name = os.path.basename(latex_file)
            latex_file_destination = os.path.join(self.book["destination"], latex_file_name)
            shutil.copy(latex_file, latex_file_destination)

            # delete the XHTML file
            Filesystem.delete_file(xhtml_file)

        # ---------- cleanup ----------
        # delete the temporary directories
        Filesystem.delete_directory(xhtml_dir)


        return True


if __name__ == "__main__":
    NlbpubToTex().run()
