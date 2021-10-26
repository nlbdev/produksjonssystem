#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
import traceback

from lxml import etree as ElementTree

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.xslt import Xslt
from prepare_for_ebook import PrepareForEbook
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubToNarrationEpub(Pipeline):
    uid = "nlbpub-to-narration-epub"
    title = "NLBPUB til innlesingsklar EPUB"
    labels = ["Lydbok", "Statped"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 590

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
        epub = Epub(self.utils.report, self.book["source"])

        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass

        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        # ---------- lag en kopi av EPUBen ----------

        narration_epubdir_obj = tempfile.TemporaryDirectory()
        narration_epubdir = narration_epubdir_obj.name
        Filesystem.copy(self.utils.report, self.book["source"], narration_epubdir)
        nlbpub = Epub(self.utils.report, narration_epubdir)

        # ---------- gjør tilpasninger i HTML-fila med XSLT ----------

        opf_path = nlbpub.opf_path()
        if not opf_path:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne OPF-fila i EPUBen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False
        opf_path = os.path.join(narration_epubdir, opf_path)

        xml = ElementTree.parse(opf_path).getroot()
        html_file = xml.xpath("/*/*[local-name()='manifest']/*[@id = /*/*[local-name()='spine']/*[1]/@idref]/@href")
        html_file = html_file[0] if html_file else None
        if not html_file:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila i OPFen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        html_file = os.path.join(os.path.dirname(opf_path), html_file)
        if not os.path.isfile(html_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        temp_html_obj = tempfile.NamedTemporaryFile()
        temp_html = temp_html_obj.name

        self.utils.report.info("Fjerner elementer som ikke skal være med i lydboka...")
        self.utils.report.debug("ta-vekk-innhold.xsl")
        self.utils.report.debug("    source = " + html_file)
        self.utils.report.debug("    target = " + temp_html)
        xslt = Xslt(self,
                    stylesheet=os.path.join(NlbpubToNarrationEpub.xslt_dir, NlbpubToNarrationEpub.uid, "ta-vekk-innhold.xsl"),
                    source=html_file,
                    target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_html, html_file)

        self.utils.report.info("Fikser Webarch-oppmerking")
        self.utils.report.debug("webarch-fixup.xsl")
        self.utils.report.debug("    source = " + html_file)
        self.utils.report.debug("    target = " + temp_html)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToNarrationEpub.uid, "webarch-fixup.xsl"),
                    source=html_file,
                    target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_html, html_file)

        self.utils.report.info("Fikser dikt-oppmerking")
        self.utils.report.debug("unwrap-poem-chapters.xsl")
        self.utils.report.debug("    source = " + html_file)
        self.utils.report.debug("    target = " + temp_html)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, NlbpubToNarrationEpub.uid, "unwrap-poem-chapters.xsl"),
                    source=html_file,
                    target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_html, html_file)

        self.utils.report.info("Lager usynlige overskrifter der det trengs...")
        self.utils.report.debug("create-hidden-headlines.xsl")
        self.utils.report.debug("    source = " + html_file)
        self.utils.report.debug("    target = " + temp_html)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "create-hidden-headlines.xsl"),
                    source=html_file,
                    target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_html, html_file)

        self.utils.report.info("Tilpasser innhold for innlesing...")
        self.utils.report.debug("prepare-for-narration.xsl")
        self.utils.report.debug("    source = " + html_file)
        self.utils.report.debug("    target = " + temp_html)
        xslt = Xslt(self,
                    stylesheet=os.path.join(NlbpubToNarrationEpub.xslt_dir, NlbpubToNarrationEpub.uid, "prepare-for-narration.xsl"),
                    source=html_file,
                    target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_html, html_file)

        self.utils.report.info("Lager synkroniseringspunkter...")
        self.utils.report.debug("lag-synkroniseringspunkter.xsl")
        self.utils.report.debug("    source = " + html_file)
        self.utils.report.debug("    target = " + temp_html)
        xslt = Xslt(self,
                    stylesheet=os.path.join(NlbpubToNarrationEpub.xslt_dir, NlbpubToNarrationEpub.uid, "lag-synkroniseringspunkter.xsl"),
                    source=html_file,
                    target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_html, html_file)

        self.utils.report.info("Gjør HTMLen litt penere...")
        self.utils.report.debug("pretty-print.xsl")
        self.utils.report.debug("    source = " + html_file)
        self.utils.report.debug("    target = " + temp_html)
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, Epub.uid, "pretty-print.xsl"),
                    source=html_file,
                    target=temp_html)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_html, html_file)

        # ---------- erstatt metadata i OPF med metadata fra HTML ----------

        temp_opf_obj = tempfile.NamedTemporaryFile()
        temp_opf = temp_opf_obj.name

        xslt = Epub.html_to_opf(self, opf_path, temp_opf)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False

        shutil.copy(temp_opf, opf_path)

        # ---------- hent nytt filnavn fra OPF (det endrer seg basert på boknummer) ----------
        try:
            xml = ElementTree.parse(opf_path).getroot()
            new_html_file = xml.xpath("/*/*[local-name()='manifest']/*[@id = /*/*[local-name()='spine']/*[1]/@idref]/@href")
            new_html_file = os.path.join(os.path.dirname(opf_path), new_html_file[0]) if new_html_file else None
        except Exception:
            self.utils.report.info(traceback.format_exc(), preformatted=True)
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila i OPFen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        if html_file != new_html_file:
            shutil.copy(html_file, new_html_file)
            os.remove(html_file)
            html_file = new_html_file

        # ---------- lag nav.xhtml på nytt ----------

        nav_path = nlbpub.nav_path()
        if not nav_path:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne navigasjonsfila i OPFen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False
        nav_path = os.path.join(narration_epubdir, nav_path)

        xslt = Epub.html_to_nav(self, html_file, nav_path)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False

        # ---------- legg til logo ----------
        library = nlbpub.meta("schema:library")
        library = library.upper() if library else library
        logo = os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "{}_logo.png".format(library))

        if os.path.isfile(logo) and library == "STATPED":
            shutil.copy(logo, os.path.join(os.path.dirname(html_file), os.path.basename(logo)))

        # ---------- save EPUB ----------

        self.utils.report.info("Boken ble konvertert. Kopierer til innlesingsklart EPUB-arkiv.")

        archived_path, stored = self.utils.filesystem.storeBook(nlbpub.asFile(), nlbpub.identifier(), file_extension="epub", move=True)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True


if __name__ == "__main__":
    NlbpubToNarrationEpub().run()
