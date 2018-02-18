# -*- coding: utf-8 -*-

import os
import re
import shutil
import socket
import hashlib
import logging
import zipfile
import tempfile
import threading
import traceback
import subprocess
import urllib.request

from pathlib import Path

class Filesystem():
    """Operations on files and directories"""
    
    pipeline = None
    
    _i18n = {
        "Storing": "Lagrer",
        "in": "i",
        "exists in": "finnes i",
        "already; existing copy will be deleted": "fra før; eksisterende kopi blir slettet",
        "Running": "Kjører",
        "Unable to replace file with newer version": "Klarte ikke å erstatte filen med nyere versjon",
        "Unable to remove": "Klarte ikke å fjerne",
        "directory": "mappe",
        "file": "fil",
        "that should no longer exist": "som ikke skal eksistere lenger",
        "Problem reading ZIP file. Did someone modify or delete it maybe?": "En feil oppstod ved lesing av ZIP-filen. Kanskje noen endret eller slettet den?",
        "An error occured while trying to delete the folder": "En feil oppstod ved sletting av mappen",
        "Maybe someone has a file or folder open on their computer?": "Kanskje noen har en fil eller mappe åpen på datamaskinen sin?"
    }
    
    shutil_ignore_patterns = shutil.ignore_patterns( # supports globs: shutil.ignore_patterns('*.pyc', 'tmp*')
        "Thumbs.db", "*.swp", "ehthumbs.db", "ehthumbs_vista.db", "*.stackdump", "Desktop.ini", "desktop.ini",
        "$RECYCLE.BIN/", "*~", ".fuse_hidden*", ".directory", ".Trash-*", ".nfs*", ".DS_Store", ".AppleDouble",
        ".LSOverride", "._*", ".DocumentRevisions-V100", ".fseventsd", ".Spotlight-V100", ".TemporaryItems",
        ".Trashes", ".VolumeIcon.icns", ".com.apple.timemachine.donotpresent", ".AppleDB", ".AppleDesktop",
        "Network Trash Folder", "Temporary Items", ".apdisk"
    )
    
    def __init__(self, pipeline):
        self.pipeline = pipeline
    
    @staticmethod
    def path_md5(path, shallow, expect=None):
        attributes = []

        # In addition to the path, we use these stat attributes:
        # st_mode: File mode: file type and file mode bits (permissions).
        # st_size: Size of the file in bytes, if it is a regular file or a symbolic link. The size of a symbolic link is the length of the pathname it contains, without a terminating null byte.
        # st_mtime: Time of most recent content modification expressed in seconds.
        
        if not os.path.exists(path):
            return "d41d8cd98f00b204e9800998ecf8427e", 0 if not shallow else None # MD5 of an empty string
        
        stat = os.stat(path)
        st_size = stat.st_size if os.path.isfile(path) else 0
        st_mtime = round(stat.st_mtime)
        attributes.extend([path, st_mtime, st_size, stat.st_mode])
        modified = stat.st_mtime

        if not shallow:
            try:
                for dirPath, subdirList, fileList in os.walk(path):
                    fileList.sort()
                    subdirList.sort()
                    for f in fileList:
                        filePath = os.path.join(dirPath, f)
                        stat = os.stat(filePath)
                        st_size = stat.st_size if os.path.isfile(path) else 0
                        st_mtime = round(stat.st_mtime)
                        attributes.extend([filePath, st_mtime, st_size, stat.st_mode])
                        modified = max(modified, stat.st_mtime)
                    for sd in subdirList:
                        subdirPath = os.path.join(dirPath, sd)
                        stat = os.stat(subdirPath)
                        st_size = stat.st_size if os.path.isfile(path) else 0
                        st_mtime = round(stat.st_mtime)
                        attributes.extend([subdirPath, st_mtime, st_size, stat.st_mode])
                        modified = max(modified, stat.st_mtime)
            except FileNotFoundError as e:
                logging.exception("[" + str(threading.get_ident()) + "] " + Filesystem._i18n["A file or folder could not be found. Did someone delete it maybe?"])
                raise e
        
        md5 = hashlib.md5(str(attributes).encode()).hexdigest()
        
        if expect and expect != md5:
            logging.debug("[" + str(threading.get_ident()) + "] MD5 changed for " + str(path) + ": " + str(attributes))
        
        return md5, modified
    
    def copytree(self, src, dst):
        assert os.path.isdir(src)
        
        if not os.path.exists(dst):
            return shutil.copytree(src, dst, ignore=Filesystem.shutil_ignore_patterns)
        
        src_list = os.listdir(src)
        dst_list = os.listdir(dst)
        src_list.sort()
        dst_list.sort()
        ignore = Filesystem.shutil_ignore_patterns(src, src_list)
        
        for item in src_list:
            src_subpath = os.path.join(src, item)
            dst_subpath = os.path.join(dst, item)
            if item not in ignore:
                if os.path.isdir(src_subpath):
                    if item not in dst_list:
                        shutil.copytree(src_subpath, dst_subpath, ignore=Filesystem.shutil_ignore_patterns)
                    else:
                        self.copytree(src_subpath, dst_subpath)
                else:
                    # Report files that have changed but where the target could not be overwritten
                    if os.path.exists(dst_subpath):
                        src_md5 = Filesystem.path_md5(src_subpath, shallow=False)
                        dst_md5 = Filesystem.path_md5(dst_subpath, shallow=False)
                        if src_md5 != dst_md5:
                            self.pipeline.utils.report.error(Filesystem._i18n["Unable to replace file with newer version"] + ": " + dst_subpath)
                    else:
                        shutil.copy(src_subpath, dst_subpath)
        
        # Report files and folders that could not be removed and were not supposed to be replaced
        for item in dst_list:
            dst_subpath = os.path.join(dst, item)
            if item not in src_list:
                message = Filesystem._i18n["Unable to remove"] + " "
                if os.path.isdir(dst_subpath):
                    message += Filesystem._i18n["directory"]
                else:
                    message += Filesystem._i18n["file"]
                message += " " + Filesystem._i18n["that should no longer exist"] + ": " + dst_subpath
                self.pipeline.utils.report.error(message)
        
        return dst
    
    def copy(self, source, destination):
        """Copy the `source` file or directory to the `destination`"""
        assert source, "Filesystem.copy(): source must be specified"
        assert destination, "Filesystem.copy(): destination must be specified"
        assert os.path.isdir(source) or os.path.isfile(source), "Filesystem.copy(): source must be either a file or a directory: " + str(source)
        self.pipeline.utils.report.debug("Copying from '" + source + "' to '" + destination + "'")
        if os.path.isdir(source):
            try:
                if os.path.exists(destination):
                    if os.listdir(destination):
                        self.pipeline.utils.report.info(os.path.basename(destination) + " " + self._i18n["exists in"] + " " + os.path.dirname(destination) + " " + self._i18n["already; existing copy will be deleted"])
                    shutil.rmtree(destination, ignore_errors=True)
                self.copytree(source, destination)
            except shutil.Error as errors:
                warnings = []
                for arg in errors.args[0]:
                    src, dst, e = arg
                    if e.startswith("[Errno 95]") and "/gvfs/" in dst:
                        warnings.append("WARN: Unable to set permissions on manually mounted samba shares")
                    else:
                        warnings.append(None)
                warnings = list(set(warnings)) # distinct warnings
                for warning in warnings:
                    if warning is not None:
                        self.pipeline.utils.report.warn(warning)
                if None in warnings:
                    raise
        else:
            shutil.copy(source, destination)
    
    def storeBook(self, source, book_id, move=False, subdir=None, dir_out=None, file_extension=None):
        """Store `book_id` from `source` into `pipeline.dir_out`"""
        self.pipeline.utils.report.info(self._i18n["Storing"] + " " + book_id + " " + self._i18n["in"] + " " + self.pipeline.dir_out + "...")
        assert book_id
        assert book_id.strip()
        assert book_id != "."
        assert not ".." in book_id
        assert not "/" in book_id
        assert not subdir or not ".." in subdir
        assert not subdir or not "/" in subdir
        if not dir_out:
            dir_out = self.pipeline.dir_out
        if subdir:
            dir_out = os.path.join(dir_out, subdir)
        target = os.path.join(dir_out, book_id)
        if os.path.isfile(source) and file_extension:
            target += "." + str(file_extension)
        if os.path.exists(target):
            self.pipeline.utils.report.info(book_id + " " + self._i18n["exists in"] + " " + dir_out + " " + self._i18n["already; existing copy will be deleted"])
            try:
                if os.path.isdir(target):
                    shutil.rmtree(target)
                else:
                    os.remove(target)
            except (OSError, NotADirectoryError):
                self.pipeline.utils.report.error(self._i18n["An error occured while trying to delete the file or folder"] + " " + dir_out + ". " + self._i18n["Maybe someone has a file or folder open on their computer?"])
                raise
        if move:
            shutil.move(source, target)
        else:
            self.copy(source, target)
        
        if os.path.isdir(target):
            # update modification time for directory
            f = tempfile.NamedTemporaryFile(suffix="-dirmodified", dir=target).name
            Path(f).touch()
            os.remove(f)
        
        return target
    
    def deleteSource(self):
        if os.path.isdir(self.pipeline.book["source"]):
            shutil.rmtree(self.pipeline.book["source"])
        elif os.path.isfile(self.pipeline.book["source"]):
            os.remove(self.pipeline.book["source"])
    
    def run(self, args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False, cwd=None, timeout=600, check=True, stdout_level="DEBUG", stderr_level="DEBUG"):
        """Convenience method for subprocess.run, with our own defaults"""
        if not cwd:
            cwd = self.pipeline.dir_in
        
        self.pipeline.utils.report.debug(self._i18n["Running"] + ": "+(" ".join(args) if isinstance(args, list) else args))
        
        completedProcess = None
        try:
            completedProcess = subprocess.run(args, stdout=stdout, stderr=stderr, shell=shell, cwd=cwd, timeout=timeout, check=check)
            
            self.pipeline.utils.report.debug("---- stdout: ----")
            self.pipeline.utils.report.add_message(stdout_level, completedProcess.stdout.decode("utf-8").strip())
            self.pipeline.utils.report.debug("-----------------")
            self.pipeline.utils.report.debug("---- stderr: ----")
            self.pipeline.utils.report.add_message(stderr_level, completedProcess.stderr.decode("utf-8").strip())
            self.pipeline.utils.report.debug("-----------------")
            
        except subprocess.CalledProcessError as e:
            self.pipeline.utils.report.debug("---- stdout: ----")
            self.pipeline.utils.report.add_message(stdout_level, e.stdout.decode("utf-8").strip())
            self.pipeline.utils.report.debug("-----------------")
            self.pipeline.utils.report.debug("---- stderr: ----")
            self.pipeline.utils.report.add_message(stderr_level, e.stderr.decode("utf-8").strip())
            self.pipeline.utils.report.debug("-----------------")
            raise
        
        return completedProcess
    
    def zip(self, directory, file):
        """Zip the contents of `dir`"""
        assert directory, "zip: directory must be specified: "+str(directory)
        assert os.path.isdir(directory), "zip: directory must exist and be a directory: "+directory
        assert file, "zip: file must be specified: "+str(file)
        dirpath = pathlib.Path(directory)
        filepath = pathlib.Path(file)
        with zipfile.ZipFile(file, 'w') as archive:
            for f in dirpath.rglob('*'):
                relative = str(f.relative_to(dirpath))
                self.pipeline.utils.report.debug("zipping: " + relative)
                archive.write(str(f), relative, compress_type=zipfile.ZIP_DEFLATED)
    
    def unzip(self, archive, target):
        """Unzip the contents of `archive`, as `dir`"""
        assert archive, "unzip: archive must be specified: "+str(archive)
        assert os.path.exists(archive), "unzip: archive must exist: "+archive
        assert target, "unzip: target must be specified: "+str(target)
        assert os.path.isdir(target) or not os.path.exists(target), "unzip: if target exists, it must be a directory: "+target
        
        if not os.path.exists(target):
            os.makedirs(target)
        
        if os.path.isdir(archive):
            self.copy(archive, target)
            
        else:
            with zipfile.ZipFile(archive, "r") as zip_ref:
                try:
                    zip_ref.extractall(target)
                except EOFError as e:
                    self.pipeline.utils.report.error(Epub._i18n["Problem reading ZIP file. Did someone modify or delete it maybe?"])
                    self.pipeline.utils.report.debug(traceback.format_exc())
                    raise e
            
            # ensure that permissions are correct
            os.chmod(target, 0o777)
            for root, dirs, files in os.walk(target):
                for d in dirs:
                    os.chmod(os.path.join(root, d), 0o777)
                for f in files:
                    os.chmod(os.path.join(root, f), 0o666)
    
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
            for mount in [os.path.join(x_dir, "gvfs", m) for m in os.listdir(os.path.join(x_dir, "gvfs"))]:
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
        
        smb = re.sub("^(smb:/+[^/]+).*", "\\1", smb) + urllib.request.pathname2url(re.sub("^smb:/+[^/]+/*(/.*)$", "\\1", smb))
        
        file = re.sub("^smb:", "file:", smb)
        unc = re.sub("/", r"\\", re.sub("^smb:", "", smb))
        return smb, file, unc
    
    # in case you want to override something
    @staticmethod
    def translate(english_text, translated_text):
        Filesystem._i18n[english_text] = translated_text
    