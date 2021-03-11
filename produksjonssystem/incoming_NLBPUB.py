#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import tempfile

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.relaxng import Relaxng
from core.utils.schematron import Schematron
from core.utils.xslt import Xslt
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class IncomingNLBPUB(Pipeline):
    uid = "incoming-NLBPUB"
    gid = "incoming-NLBPUB"
    title = "Mottakskontroll NLBPUB"
    group_title = "Mottakskontroll NLBPUB"
    labels = ["EPUB"]
    publication_format = None
    expected_processing_time = 300
    warning = False
    should_email_default = True
    should_message_slack = True

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

        self.utils.report.should_email = self.should_email_default
        self.utils.report.should_message_slack = self.should_message_slack
        self.utils.report.info("Lager kopi av EPUB...")
        nordic_epubdir_obj = tempfile.TemporaryDirectory()
        nordic_epubdir = nordic_epubdir_obj.name
        Filesystem.copy(self.pipeline.utils.report, epub.asDir(), nordic_epubdir)
        nordic_epub = Epub(self.utils.report, nordic_epubdir)

        html_file = os.path.join(nordic_epubdir, "EPUB", nordic_epub.identifier() + ".xhtml")
        nav_file = os.path.join(nordic_epubdir, "EPUB", "nav" + ".xhtml")
        package_file = os.path.join(nordic_epubdir, "EPUB", "package" + ".opf")
        nlbpub_files = [html_file, nav_file, package_file]

        for file in nlbpub_files:
            if not os.path.isfile(file):
                self.utils.report.error(file + " Not found. This is not a valid NLBPUB")

        self.utils.report.info("Validerer NLBPUB")
        schematron_files = ["nordic2015-1.sch", "nordic2015-1.nav-references.sch", "nordic2015-1.opf.sch"]
        rng_files = "nordic-html5.rng"
        html_sch = Schematron(self, schematron=os.path.join(Xslt.xslt_dir, "incoming-NLBPUB", schematron_files[0]), source=html_file)
        nav_sch = Schematron(self, schematron=os.path.join(Xslt.xslt_dir, "incoming-NLBPUB", schematron_files[1]), source=nav_file)
        opf_sch = Schematron(self, schematron=os.path.join(Xslt.xslt_dir, "incoming-NLBPUB", schematron_files[2]), source=package_file)
        warning_sch = Schematron(self,
                                 schematron=os.path.join(Xslt.xslt_dir, "incoming-NLBPUB", "nlbpub-check-need-for-manual-intervention.sch"),
                                 source=html_file)
        schematron_list = [html_sch, nav_sch, opf_sch]
        html_relax = Relaxng(self, relaxng=os.path.join(Xslt.xslt_dir, "incoming-NLBPUB", rng_files), source=html_file)

        for i in range(0, len(schematron_list)):
            if not schematron_list[i].success:
                self.utils.report.error("Validering av NLBPUB feilet etter schematron: " + schematron_files[i])
                return False
        if not html_relax.success:
            self.utils.report.error("Validering av NLBPUB feilet etter RELAXNG: " + rng_files)
            return False

        self.utils.report.info("Boken er valid.")

        if not self.skip_warning:

            #warning_sch = Schematron(self, schematron=os.path.join(Xslt.xslt_dir, "incoming-NLBPUB", "nlbpub-check-need-for-manual-intervention.sch"), source=html_file)

            if warning_sch.success is False:
                if self.uid == "NLBPUB-incoming-warning":
                    archived_path, stored = self.utils.filesystem.storeBook(nordic_epubdir, epub.identifier())
                    self.utils.report.attachment(None, archived_path, "DEBUG")
                    self.utils.report.title = self.title + ": " + epub.identifier() + " er valid, men må sjekkes manuelt 👍😄" + epubTitle
                    self.utils.report.should_email = True
                    self.utils.report.should_message_slack = True
                    return True
                else:
                    self.utils.report.should_email = False
                    self.utils.report.should_message_slack = False
                    self.utils.report.title = self.title + ": " + epub.identifier() + " er valid, men må sjekkes manuelt 👍😄" + epubTitle
                    return True
            else:
                if self.uid == "NLBPUB-incoming-validator":
                    archived_path, stored = self.utils.filesystem.storeBook(nordic_epubdir, epub.identifier())
                    self.utils.report.attachment(None, archived_path, "DEBUG")
                    self.utils.report.title = self.title + ": " + epub.identifier() + " er valid 👍😄" + epubTitle
                    self.utils.filesystem.deleteSource()
                    return True
                else:
                    self.utils.report.info(epub.identifier() + " er valid og har ingen advarsler.")
                    return True

        archived_path, stored = self.utils.filesystem.storeBook(nordic_epubdir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " er valid 👍😄" + epubTitle
        return True


class NLBPUB_validator(IncomingNLBPUB):
    uid = "NLBPUB-validator-final"
    gid = "NLBPUB-validator-final"
    title = "NLBPUB validator"
    labels = ["EPUB"]
    publication_format = "None"
    skip_warning = True
    expected_processing_time = 300
    should_email_default = True
    should_message_slack = True


class NLBPUB_incoming_validator(IncomingNLBPUB):
    uid = "NLBPUB-incoming-validator"
    title = "Mottakskontroll NLBPUB validering"
    labels = ["EPUB"]
    publication_format = "None"
    skip_warning = False
    expected_processing_time = 40
    should_email_default = True
    should_message_slack = True


class NLBPUB_incoming_warning(IncomingNLBPUB):
    uid = "NLBPUB-incoming-warning"
    title = "Mottakskontroll NLBPUB advarsel"
    labels = ["EPUB"]
    publication_format = "None"
    skip_warning = False
    expected_processing_time = 41
    should_email_default = False
    should_message_slack = False
