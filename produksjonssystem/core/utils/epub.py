# -*- coding: utf-8 -*-

import os
import pathlib
import zipfile
import tempfile
import traceback

from lxml import etree as ElementTree

class Epub():
    """Methods for working with EPUB files/filesets"""
    
    _i18n = {
        "does not exist": "eksisterer ikke",
        "cannot validate EPUB": "kan ikke validere EPUB",
        "the file does not end with \".epub\" or \".zip\"": "filen slutter ikke med \".epub\" eller \".zip\""
    }
    
    pipeline = None
    book_path = None
    _temp_obj = None
    book_identifier = None
    
    def __init__(self, pipeline, book_path):
        assert os.path.exists(book_path)
        self.pipeline = pipeline
        self.book_path = book_path
    
    def asFile(self):
        """Return the epub as a zip file and with file extension "epub"."""
        
        # file
        if os.path.isfile(self.book_path):
            return self.book_path
        
        # directory
        else:
            if not self._temp_obj:
                self._temp_obj = tempfile.TemporaryDirectory()
            
            book_id = self.meta("dc:identifier")
            file = os.path.join(self._temp_obj.name, book_id + ".epub")
            
            dirpath = pathlib.Path(self.book_path)
            filepath = pathlib.Path(file)
            with zipfile.ZipFile(file, 'w') as archive:
                mimetype = dirpath / 'mimetype'
                if not os.path.isfile(str(mimetype)):
                    with open(str(mimetype), "w") as f:
                        self.pipeline.utils.report.debug("creating mimetype file")
                        f.write("application/epub+zip")
                self.pipeline.utils.report.debug("zipping: mimetype")
                archive.write(str(mimetype), 'mimetype', compress_type=zipfile.ZIP_STORED)
                for f in dirpath.rglob('*'):
                    relative = str(f.relative_to(dirpath))
                    if relative == "mimetype":
                        continue
                    self.pipeline.utils.report.debug("zipping: " + relative)
                    archive.write(str(f), relative, compress_type=zipfile.ZIP_DEFLATED)
            
            return file
        
    def asDir(self):
        # file
        if os.path.isfile(self.book_path):
            if not self._temp_obj:
                self._temp_obj = tempfile.TemporaryDirectory()
            
            self.pipeline.utils.filesystem.unzip(self.book_path, self._temp_obj.name)
            return self._temp_obj.name
        
        # directory
        else:
            return self.book_path
    
    def isepub(self):
        # EPUBen må inneholde en "EPUB/package.opf"-fil (en ekstra sjekk for å være sikker på at dette er et EPUB-filsett)
        if os.path.isdir(self.book_path) and not os.path.isfile(os.path.join(self.book_path, "EPUB/package.opf")):
            self.pipeline.utils.report.error(os.path.basename(self.book_path) + ": EPUB/package.opf " + Epub._i18n["does not exist"] + "; " + Epub._i18n["cannot validate EPUB"] + ".")
            return False
        
        elif os.path.isfile(self.book_path):
            with zipfile.ZipFile(self.book_path, 'r') as archive:
                if not "mimetype" in [item.filename for item in archive.filelist]:
                    self.pipeline.utils.warn("No 'mimetype' file in ZIP; this is not an EPUB: " + self.book_path)
                    return False
                
                mimetype = archive.read("mimetype").decode("utf-8")
                if not mimetype.startswith("application/epub+zip"):
                    self.pipeline.utils.warn("The 'mimetype' file does not start with the text 'application/epub+zip'; this is not an EPUB: " + self.book_path)
                    return False
                
                if not "META-INF/container.xml" in [item.filename for item in archive.filelist]:
                    self.pipeline.utils.warn("No 'META-INF/container.xml' file in ZIP; this is not an EPUB: " + self.book_path)
                    return False
                
        
        return True
    
    def opf_path(self):
        container = None
        
        if os.path.isdir(self.book_path):
            container = ElementTree.parse(os.path.join(self.book_path, "META-INF/container.xml")).getroot()
            
        else:
            with zipfile.ZipFile(self.book_path, 'r') as archive:
                container = archive.read("META-INF/container.xml")
                container = ElementTree.XML(container)
        
        rootfiles = container.findall('{urn:oasis:names:tc:opendocument:xmlns:container}rootfiles')[0]
        rootfile = rootfiles.findall('{urn:oasis:names:tc:opendocument:xmlns:container}rootfile')[0]
        opf = rootfile.attrib["full-path"]
        return opf
    
    def identifier(self, default=None):
        if not self.book_identifier:
            self.book_identifier = self.meta("dc:identifier")
        return self.book_identifier
    
    def meta(self, name, default=None):
        """Read OPF metadata"""
        opf = None
        opf_path = self.opf_path()
        
        if os.path.isdir(self.book_path):
            opf = ElementTree.parse(os.path.join(self.book_path, opf_path)).getroot()
            
        else:
            with zipfile.ZipFile(self.book_path, 'r') as archive:
                opf = archive.read(opf_path)
                opf = ElementTree.XML(opf)
        
        metadata = opf.findall('{http://www.idpf.org/2007/opf}metadata')[0]
        meta = metadata.getchildren()
        for m in meta:
            if "refines" in m.attrib:
                continue
            n = m.attrib["property"] if "property" in m.attrib else m.attrib["name"] if "name" in m.attrib else m.tag
            n = n.replace("{http://purl.org/dc/elements/1.1/}", "dc:")
            if n == name:
                return m.attrib["content"] if "content" in m.attrib else m.text
        return None
    
    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        Epub._i18n[english_text] = translated_text
