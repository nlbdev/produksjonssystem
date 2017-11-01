# -*- coding: utf-8 -*-

import os
import shutil
import subprocess

class Filesystem():
    """Operations on files and directories"""
    
    book = None
    report = None
    
    def __init__(self, book, report):
        self.book = book
        self.report = report
    
    def copy(self, source, destination):
        """Copy the `source` file or directory to the `destination`"""
        try:
            shutil.copytree(source, destination)
        except OSError as e:
            if e.errno == errno.ENOTDIR:
                shutil.copy(source, destination)
            else:
                raise
    
    def storeBook(self, archive_dir, source, book_id, move=False):
        """Store `book_id` from `source` into `archive_dir`"""
        self.report.info("Storing " + book_id + " in " + archive_dir + "...")
        assert book_id
        assert book_id.strip()
        assert book_id != "."
        assert not ".." in book_id
        assert not "/" in book_id
        target = os.path.join(archive_dir, book_id)
        if os.path.exists(target):
            self.report.warn(book_id + " finnes i " + archive_dir + " fra før; eksisterende kopi blir slettet")
            shutil.rmtree(target)
        if move:
            shutil.move(source, target)
        else:
            self.copy(source, target)
    
    def deleteSource(self):
        if os.path.isdir(self.book["source"]):
            shutil.rmtree(self.book["source"])
        elif os.path.isfile(self.book["source"]):
            os.remove(self.book["source"])
    
    def run(self, args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False, cwd=None, timeout=600, check=True):
        """Convenience method for subprocess.run, with our own defaults"""
        if not cwd:
            cwd = self.book["base"]
        
        self.report.debug("running: "+(" ".join(args) if isinstance(args, list) else args))
        
        completedProcess = None
        try:
            completedProcess = subprocess.run(args, stdout=stdout, stderr=stderr, shell=shell, cwd=cwd, timeout=timeout, check=check)
            
            self.report.debug("---- stdout: ----")
            self.report.debug(completedProcess.stdout.decode("utf-8").strip())
            self.report.debug("-----------------")
            self.report.debug("---- stderr: ----")
            self.report.debug(completedProcess.stderr.decode("utf-8").strip())
            self.report.debug("-----------------")
            
        except subprocess.CalledProcessError as e:
            self.report.debug("---- stdout: ----")
            self.report.debug(e.stdout.decode("utf-8").strip())
            self.report.debug("-----------------")
            self.report.debug("---- stderr: ----")
            self.report.debug(e.stderr.decode("utf-8").strip())
            self.report.debug("-----------------")
            raise
        
        return completedProcess
        