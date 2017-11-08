# -*- coding: utf-8 -*-

import os
import zipfile
import pathlib

class Epub():
    """Methods for working with EPUB files/filesets"""
    
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
            zip_ref.extractall(directory)
    
    def meta(self, file, property, default=None):
        """Read OPF metadata"""
        # file: either .epub or .opf
        self.pipeline.utils.report.warn("TODO: Epub.meta(file, property, default=None)")
