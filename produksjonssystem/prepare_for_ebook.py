#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import shutil
import sys
import tempfile
import time

import requests
from lxml import etree as ElementTree

from core.config import Config
from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.epubcheck import Epubcheck
from core.utils.xslt import Xslt
from core.utils.mathml_to_text import Mathml_to_text, Mathml_validator
from core.utils.filesystem import Filesystem


if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class PrepareForEbook(Pipeline):
    uid = "prepare-for-ebook"
    title = "Klargjør for e-bok"
    labels = ["e-bok", "Statped"]
    publication_format = "XHTML"
    expected_processing_time = 260

    css_tempfile_obj = None
    css_tempfile_statped_obj = None

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB slettet: " + self.book['name']
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

        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        Filesystem.copy(self.utils.report, self.book["source"], temp_epubdir)
        temp_epub = Epub(self.utils.report, temp_epubdir)

        # ---------- gjør tilpasninger i HTML-fila med XSLT ----------

        opf_path = temp_epub.opf_path()
        if not opf_path:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne OPF-fila i EPUBen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False
        opf_path = os.path.join(temp_epubdir, opf_path)
        opf_xml = ElementTree.parse(opf_path).getroot()

        html_file = opf_xml.xpath("/*/*[local-name()='manifest']/*[@id = /*/*[local-name()='spine']/*[1]/@idref]/@href")
        html_file = html_file[0] if html_file else None
        if not html_file:
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila i OPFen.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False
        html_dir = os.path.dirname(opf_path)
        html_file = os.path.join(html_dir, html_file)
        if not os.path.isfile(html_file):
            self.utils.report.error(self.book["name"] + ": Klarte ikke å finne HTML-fila.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎" + epubTitle
            return False

        temp_xml_obj = tempfile.NamedTemporaryFile()
        temp_xml = temp_xml_obj.name

        # MATHML to stem
        self.utils.report.info("Erstatter evt. MathML i boka...")
        mathml_validation = Mathml_validator(self, source=html_file)
        if not mathml_validation.success:
            self.utils.report.error("NLBPUB contains MathML errors, aborting...")
            return False

        mathML_result = Mathml_to_text(self, source=html_file, target=html_file)

        if not mathML_result.success:
            return False

        self.utils.report.info("Lager skjulte overskrifter der det er nødvendig")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "create-hidden-headlines.xsl"),
                    source=html_file,
                    target=temp_xml,
                    parameters={
                        "cover-headlines": "from-type",
                        "frontmatter-headlines": "from-type",
                        "bodymatter-headlines": "from-text",
                        "backmatter-headlines": "from-type"
                    })
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_xml, html_file)

        self.utils.report.info("Tilpasser innhold for e-bok...")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "prepare-for-ebook.xsl"),
                    source=html_file,
                    target=temp_xml)
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_xml, html_file)

        # Use library-specific logo and stylesheet if available

        library = temp_epub.meta("schema:library")
        library = library.upper() if library else library
        logo = os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "{}_logo.png".format(library))

        if os.path.isfile(logo) and library not in ["NLB", "Tibi"]:
            shutil.copy(logo, os.path.join(html_dir, os.path.basename(logo)))

        PrepareForEbook.update_css()

        stylesheet = PrepareForEbook.css_tempfile_obj.name
        if library is not None and library.lower() == "statped":
            stylesheet = PrepareForEbook.css_tempfile_statped_obj.name
        shutil.copy(stylesheet, os.path.join(html_dir, "ebok.css"))

        if os.path.isfile(logo) and library not in ["NLB", "Tibi"]:
            self.utils.report.info("Legger til logoen i OPF-manifestet")
            xslt = Xslt(self,
                        stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "add-to-opf-manifest.xsl"),
                        source=opf_path,
                        target=temp_xml,
                        parameters={
                            "href": os.path.basename(logo),
                            "media-type": "image/png"
                        })
            if not xslt.success:
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return False
            shutil.copy(temp_xml, opf_path)

        self.utils.report.info("Legger til CSS-fila i OPF-manifestet")
        xslt = Xslt(self,
                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "add-to-opf-manifest.xsl"),
                    source=opf_path,
                    target=temp_xml,
                    parameters={
                        "href": "ebok.css",
                        "media-type": "text/css"
                    })
        if not xslt.success:
            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
            return False
        shutil.copy(temp_xml, opf_path)

        # NEW: Restore original content images that were replaced with dummy.jpg
        self.utils.report.info("Gjenoppretter originale innholdsbilder...")
        self._restore_content_images(temp_epub, opf_path, html_file)

        # add cover if missing

        opf_xml = ElementTree.parse(opf_path).getroot()
        cover_id = opf_xml.xpath("/*/*[local-name()='manifest']/*[contains(concat(' ', @properties, ' '), ' cover-image ')]/@id")  # from properties
        if not cover_id:
            cover_id = opf_xml.xpath("/*/*[local-name()='manifest']/*[@name='cover']/@content")  # from metadata
        if not cover_id:
            cover_id = opf_xml.xpath("/*/*[local-name()='manifest']/*[starts-with(@media-type, 'image/') and contains(@href, 'cover')]/@id")  # from filename
        cover_id = cover_id[0] if cover_id else None

        if not cover_id:
            # cover not found in the book, let's try NLBs API

            # NOTE: identifier at this point is the e-book identifier
            edition_url = "{}/editions/{}?creative-work-metadata=none&edition-metadata=all".format(Config.get("nlb_api_url"), epub.identifier())

            response = requests.get(edition_url)
            self.utils.report.debug("looking for cover image in: {}".format(edition_url))
            if response.status_code == 200:
                response_json = response.json()
                if "data" not in response_json:
                    self.utils.report.debug("response as JSON:")
                    self.utils.report.debug(str(response_json))
                    raise Exception("No 'data' in response: {}".format(edition_url))
                data = response_json["data"]
                cover_url = data["coverUrlLarge"]
                if cover_url is not None and cover_url.startswith("http"):
                    response = requests.get(cover_url)
                    if response.status_code == 200:
                        _, extension = os.path.splitext(cover_url)
                        target_href = "cover" + extension
                        target_dir = os.path.dirname(opf_path)
                        with open(os.path.join(target_dir, target_href), "wb") as target_file:
                            target_file.write(response.content)

                        self.utils.report.info("Legger til bildet av bokomslaget i OPF-manifestet")
                        media_type = None
                        if extension.lower() in [".png"]:  # check for png, just in case. Should always be jpg though.
                            media_type = "image/png"
                        else:
                            media_type = "image/jpeg"
                        xslt = Xslt(self,
                                    stylesheet=os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "add-to-opf-manifest.xsl"),
                                    source=opf_path,
                                    target=temp_xml,
                                    parameters={
                                        "href": target_href,
                                        "media-type": media_type
                                    })
                        if not xslt.success:
                            self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                            return False
                        shutil.copy(temp_xml, opf_path)

                        opf_xml = ElementTree.parse(opf_path).getroot()
                        cover_id = opf_xml.xpath("/*/*[local-name()='manifest']/*[@href = '{}']/@id".format(target_href))  # from filename
                        cover_id = cover_id[0] if cover_id else None

        if cover_id is None or len(cover_id) == 0:
            self.utils.report.warn("Klarte ikke å finne bilde av bokomslaget for {}".format(epub.identifier()))

        self.utils.report.info("Legger til properties i OPF etter behov")
        temp_epub.update_opf_properties()

        # validate with epubcheck
        if Epubcheck.isavailable():
            epubcheck = Epubcheck(self, opf_path)
            if not epubcheck.success:
                tempfile_stored_opf = os.path.join(self.utils.report.reportDir(), os.path.basename(opf_path))
                shutil.copy(opf_path, tempfile_stored_opf)
                tempfile_stored = os.path.join(self.utils.report.reportDir(), os.path.basename(html_file))
                shutil.copy(html_file, tempfile_stored)
                self.utils.report.info(f"Validering av EPUB feilet, lagrer temp fil for feilsøking: {tempfile_stored}")
                self.utils.report.attachment(None, tempfile_stored, "DEBUG")
                self.utils.report.title = self.title + ": " + epub.identifier() + " feilet 😭👎" + epubTitle
                return
        else:
            self.utils.report.warn("Epubcheck er ikke tilgjengelig, EPUB blir ikke validert!")

        # ---------- lagre filsett ----------

        self.utils.report.info("Boken ble konvertert. Kopierer til HTML-arkiv.")

        archived_path, stored = self.utils.filesystem.storeBook(temp_epubdir, epub.identifier())
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble konvertert 👍😄" + epubTitle
        return True

    def _restore_content_images(self, epub, opf_path, html_file):
        """Restore original content images that were replaced with dummy.jpg during DAISY pipeline processing"""
        
        # Get the original EPUB to find what images were originally referenced
        original_epub = Epub(self.utils.report, self.book["source"])
        original_opf_path = original_epub.opf_path()
        if not original_opf_path:
            return
        
        original_opf_path = os.path.join(self.book["source"], original_opf_path)
        original_opf_xml = ElementTree.parse(original_opf_path).getroot()
        
        # Find all image items in the original OPF
        original_image_items = original_opf_xml.xpath("//*[local-name()='item' and starts-with(@media-type, 'image/')]")
        
        # Get current OPF
        opf_xml = ElementTree.parse(opf_path).getroot()
        manifest = opf_xml.find(".//{http://www.idpf.org/2007/opf}manifest")
        
        # Check which images are currently missing (replaced with dummy.jpg)
        current_image_items = opf_xml.xpath("//*[local-name()='item' and starts-with(@media-type, 'image/')]")
        current_image_hrefs = [item.get("href") for item in current_image_items]
        
        # Find images that need to be restored
        for original_item in original_image_items:
            original_href = original_item.get("href")
            
            # Skip cover.jpg (handled separately) and dummy.jpg
            if original_href in ["images/cover.jpg", "images/dummy.jpg"]:
                continue
                
            # Check if this image is referenced in the HTML content
            if self._is_image_referenced_in_html(html_file, original_href):
                # Check if the image file still exists
                image_path = os.path.join(os.path.dirname(opf_path), original_href)
                if os.path.exists(image_path) and original_href not in current_image_hrefs:
                    # Add the image back to the manifest
                    self.utils.report.info(f"Gjenoppretter bilde: {original_href}")
                    
                    # Generate unique ID
                    existing_ids = [item.get("id") for item in manifest.findall(".//{http://www.idpf.org/2007/opf}item")]
                    item_id = f"restored_img_{len(existing_ids) + 1}"
                    while item_id in existing_ids:
                        item_id = f"restored_img_{len(existing_ids) + 1}"
                    
                    # Create new item element
                    new_item = ElementTree.SubElement(manifest, "{http://www.idpf.org/2007/opf}item")
                    new_item.set("id", item_id)
                    new_item.set("href", original_href)
                    new_item.set("media-type", original_item.get("media-type"))
        
        # Write updated OPF
        opf_xml.write(opf_path, encoding="utf-8", xml_declaration=True, pretty_print=True)

    def _is_image_referenced_in_html(self, html_file, image_href):
        """Check if an image is referenced in the HTML content"""
        try:
            html_xml = ElementTree.parse(html_file).getroot()
            
            # Check for img src attributes
            img_srcs = html_xml.xpath("//@src")
            for src in img_srcs:
                if src == image_href or src == image_href.replace("images/", ""):
                    return True
            
            # Check for other image references
            hrefs = html_xml.xpath("//@href")
            for href in hrefs:
                if href == image_href:
                    return True
                    
            return False
        except Exception:
            return False

    @staticmethod
    def update_css():
        if PrepareForEbook.css_tempfile_obj is None:
            PrepareForEbook.css_tempfile_obj = tempfile.NamedTemporaryFile()
        if PrepareForEbook.css_tempfile_statped_obj is None:
            PrepareForEbook.css_tempfile_statped_obj = tempfile.NamedTemporaryFile()

        css_tempfile = PrepareForEbook.css_tempfile_obj.name
        css_tempfile_statped = PrepareForEbook.css_tempfile_statped_obj.name

        stat = os.stat(css_tempfile)
        st_size = stat.st_size
        st_mtime = round(stat.st_mtime)

        if st_size == 0 or time.time() - st_mtime > 3600 * 3:
            if st_size == 0:
                default_path = os.path.join(Xslt.xslt_dir, PrepareForEbook.uid, "epub.css")
                shutil.copy(default_path, css_tempfile)

            latest_url_statped = "https://raw.githubusercontent.com/StatpedEPUB/nlb-scss/master/dist/css/statped.min.css"

            latest_url = "https://github.com/nlbdev/nlb-scss/releases/download/2025-01-29/epub.min.css"

            response = requests.get(latest_url)
            response_statped = requests.get(latest_url_statped)
            if response.status_code == 200:
                with open(css_tempfile, "wb") as target_file:
                    target_file.write(response.content)

            if response_statped.status_code == 200:
                with open(css_tempfile_statped, "wb") as target_file_statped:
                    target_file_statped.write(response_statped.content)


if __name__ == "__main__":
    PrepareForEbook().run()
