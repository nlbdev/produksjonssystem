# -*- coding: utf-8 -*-

import os
import pathlib
import traceback
import zipfile

import xml.etree.ElementTree as etree

class Epub():
    """Methods for working with EPUB files/filesets"""
    
    _i18n = {
        "Problem reading EPUB file. Did someone modify or delete it maybe?": "En feil oppstod ved lesing av EPUB-filen. Kanskje noen endret eller slettet den?"
    }
    
    pipeline = None
    
    def __init__(self, pipeline):
        self.pipeline = pipeline
    
    def zip(self, directory, file):
        """Zip the contents of `dir`, with mediatype file first, as `file`"""
        # def function epub(): rm -f $@; zip -q0X $@ mimetype; zip -qXr9D $@ *
        assert directory, "zip: directory must be specified: "+str(directory)
        assert os.path.isdir(directory), "zip: directory must exist and be a directory: "+directory
        assert file, "zip: file must be specified: "+str(file)
        dirpath = pathlib.Path(directory)
        filepath = pathlib.Path(file)
        with zipfile.ZipFile(file, 'w') as archive:
            mimetype = dirpath / 'mimetype'
            if not os.path.isfile(str(mimetype)):
                with open(str(mimetype), "w") as f:
                    self.pipeline.utils.report.debug("creating mimetype file")
                    f.write("application/epub+zip")
            self.pipeline.utils.report.debug("zipping: mimetype")
            archive.write(str(mimetype), 'mimetype', compress_type=zipfile.ZIP_STORED)
            for f in dirpath.rglob('*.*'):
                self.pipeline.utils.report.debug("zipping: "+str(f.relative_to(dirpath)))
                archive.write(str(f), str(f.relative_to(dirpath)), compress_type=zipfile.ZIP_DEFLATED)
    
    def unzip(self, file, directory):
        """Unzip the contents of `file`, as `dir`"""
        assert file, "unzip: file must be specified: "+str(file)
        assert os.path.isfile(file), "unzip: file must exist and be a file: "+file
        assert directory, "unzip: directory must be specified: "+str(directory)
        assert os.path.isdir(directory), "unzip: directory must exist and be a directory: "+directory
        with zipfile.ZipFile(file, "r") as zip_ref:
            try:
                zip_ref.extractall(directory)
            except EOFError as e:
                self.pipeline.utils.report.error(Epub._i18n["Problem reading EPUB file. Did someone modify or delete it maybe?"])
                self.pipeline.utils.report.debug(traceback.format_exc())
                raise e
    
    def opf_path(self, book_dir):
        assert os.path.isdir(book_dir), "Epub.meta(book_dir, property): book_dir must be a directory (" + str(book_dir) + ")"
        container = etree.parse(os.path.join(book_dir, "META-INF/container.xml")).getroot()
        rootfiles = container.findall('{urn:oasis:names:tc:opendocument:xmlns:container}rootfiles')[0]
        rootfile = rootfiles.findall('{urn:oasis:names:tc:opendocument:xmlns:container}rootfile')[0]
        opf = rootfile.attrib["full-path"]
        return opf
    
    def meta(self, book_dir, name, default=None):
        """Read OPF metadata"""
        assert os.path.isdir(book_dir), "Epub.meta(book_dir, name): book_dir must be a directory (" + str(book_dir) + ")"
        opf_path = self.opf_path(book_dir)
        opf = etree.parse(os.path.join(book_dir, opf_path)).getroot()
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
