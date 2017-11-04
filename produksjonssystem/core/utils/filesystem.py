# -*- coding: utf-8 -*-

import os
import shutil
import subprocess
import socket
import re

class Filesystem():
    """Operations on files and directories"""
    
    book = None
    report = None
    
    _i18n = {
        "Storing": "Lagrer",
        "in": "i",
        "exists in": "finnes i",
        "already; existing copy will be deleted": "fra før; eksisterende kopi blir slettet",
        "Running": "Kjører"
    }
    
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
        self.report.info(self._i18n["Storing"] + " " + book_id + " " + self._i18n["in"] + " " + archive_dir + "...")
        assert book_id
        assert book_id.strip()
        assert book_id != "."
        assert not ".." in book_id
        assert not "/" in book_id
        target = os.path.join(archive_dir, book_id)
        if os.path.exists(target):
            self.report.warn(book_id + " " + self._i18n["exists in"] + " " + archive_dir + " " + self._i18n["already; existing copy will be deleted"])
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
        
        self.report.debug(self._i18n["Running"] + ": "+(" ".join(args) if isinstance(args, list) else args))
        
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
    
    @staticmethod
    def ismount(path):
        return True if Filesystem.getdevice(path) else False
    
    @staticmethod
    def getdevice(path):
        path = os.path.normpath(path)
        
        with open('/proc/mounts','r') as f:
            for line in f.readlines():
                l = line.split()
                if l[0].startswith("/") and l[1] == path:
                    #l[0] = "//x.x.x.x/sharename/optionalsubpath"
                    #l[1] = "/mount/point"
                    return re.sub("^//", "smb://", l[0])
        
        x_dir = os.getenv("XDG_RUNTIME_DIR")
        if x_dir:
            for mount in [os.path.join(x_dir, m) for m in os.listdir(os.path.join(x_dir, "gvfs"))]:
                if mount == path:
                    # path == "$XDG_RUNTIME_DIR/gvfs/smb-share:server=x.x.x.x,share=sharename"
                    return re.sub(",share=", "/", re.sub("^smb-share:server=", "smb://", os.path.basename(path)))
        
        return None
    
    @staticmethod
    def networkpath(path):
        path = os.path.normpath(path)
        if path == ".":
            path = ""
        
        levels = path.split(os.path.sep)
        possible_mount_points = ["/".join(levels[:i+1]) for i in range(len(levels))][1:]
        possible_mount_points.reverse()
        
        smb = None
        for possible_mount_point in possible_mount_points:
            smb = Filesystem.getdevice(possible_mount_point)
            if smb:
                smb = smb + path[len(possible_mount_point):]
                break
        
        if not smb:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            localhost = s.getsockname()[0]
            s.close()
            smb = "smb://" + localhost + path
        
        file = re.sub("^smb:", "file:", smb)
        unc = re.sub("/", r"\\", re.sub("^smb:", "", smb))
        return smb, file, unc
    
    # in case you want to override something
    def translate(self, english_text, translated_text):
        self._i18n[english_text] = translated_text
    