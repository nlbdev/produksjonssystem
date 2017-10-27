# -*- coding: utf-8 -*-

class Epub():
    """Methods for working with EPUB files/filesets"""
    
    book = None
    report = None
    
    def __init__(self, book, report):
        self.book = book
        self.report = report
    
    def zip(directory, file):
        """Zip the contents of `dir`, with mediatype file first, as `file`"""
        # def function epub(): rm -f $@; zip -q0X $@ mimetype; zip -qXr9D $@ *
        print("TODO: Epub.zip(dir,file)")
    
    def unzip(file, directory):
        """Unzip the contents of `file`, as `dir`"""
        print("TODO: Epub.unzip(file,dir)")
    
    def meta(file, property, default=None):
        """Read OPF metadata"""
        # file: either .epub or .opf
        print("TODO: Epub.meta(file, property, default=None)")
