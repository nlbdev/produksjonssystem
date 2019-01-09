# -*- coding: utf-8 -*-

import hashlib
import logging
import os
import re
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import traceback
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path


class Filesystem():
    """Operations on files and directories"""

    pipeline = None
    last_reported_md5 = None  # avoid reporting change for same book multiple times
    hosts = {} # hosts cache

    shutil_ignore_patterns = shutil.ignore_patterns( # supports globs: shutil.ignore_patterns('*.pyc', 'tmp*')
        "Thumbs.db", "*.swp", "ehthumbs.db", "ehthumbs_vista.db", "*.stackdump", "Desktop.ini", "desktop.ini",
        "$RECYCLE.BIN", "*~", ".fuse_hidden*", ".directory", ".Trash-*", ".nfs*", ".DS_Store", ".AppleDouble",
        ".LSOverride", "._*", ".DocumentRevisions-V100", ".fseventsd", ".Spotlight-V100", ".TemporaryItems",
        ".Trashes", ".VolumeIcon.icns", ".com.apple.timemachine.donotpresent", ".AppleDB", ".AppleDesktop",
        "Network Trash Folder", "Temporary Items", ".apdisk", "Dolphin check log.txt", "*dirmodified", "dds-temp",
        "*.crdownload"
    )

    def __init__(self, pipeline):
        self.pipeline = pipeline

    @staticmethod
    def file_content_md5(path):
        if not os.path.isfile(path):
            return "d41d8cd98f00b204e9800998ecf8427e"  # MD5 of an empty string

        return hashlib.md5(open(path, 'rb').read()).hexdigest()

    @staticmethod
    def should_ignore(path):
        return bool(Filesystem.shutil_ignore_patterns(os.path.dirname(path), [os.path.basename(path)]))

    @staticmethod
    def path_md5(path, shallow, expect=None):
        attributes = []

        # In addition to the path, we use these stat attributes:
        # st_mode: File mode: file type and file mode bits (permissions).
        # st_size: Size of the file in bytes, if it is a regular file or a symbolic link.
        #          The size of a symbolic link is the length of the pathname it contains, without a terminating null byte.
        # st_mtime: Time of most recent content modification expressed in seconds.

        modified = 0
        if not os.path.exists(path):
            md5 = "d41d8cd98f00b204e9800998ecf8427e"  # MD5 of an empty string

        else:
            if os.path.isfile(path) and not Filesystem.should_ignore(path):
                stat = os.stat(path)
                st_size = stat.st_size if os.path.isfile(path) else 0
                st_mtime = round(stat.st_mtime)
                attributes.extend([path, st_mtime, st_size, stat.st_mode])
                modified = stat.st_mtime

            if not shallow or not modified:
                try:
                    for dirPath, subdirList, fileList in os.walk(path):
                        fileList.sort()
                        subdirList.sort()
                        ignore = Filesystem.shutil_ignore_patterns(dirPath, fileList + subdirList)
                        for s in reversed(range(len(subdirList))):
                            if subdirList[s] in ignore:
                                del subdirList[s]  # remove ignored folders in-place
                        for f in fileList:
                            if f in ignore:
                                continue  # skip ignored files
                            filePath = os.path.join(dirPath, f)
                            stat = os.stat(filePath)
                            st_size = stat.st_size if os.path.isfile(path) else 0
                            st_mtime = round(stat.st_mtime)
                            attributes.extend([filePath, st_mtime, st_size, stat.st_mode])
                            modified = max(modified, stat.st_mtime)
                            if shallow:
                                break
                except FileNotFoundError as e:
                    logging.exception("Filen eller mappen ble ikke funnet. Kanskje noen slettet den?")
                    raise e

            if attributes:
                md5 = hashlib.md5(str(attributes).encode()).hexdigest()
            else:
                md5 = "d41d8cd98f00b204e9800998ecf8427e"  # MD5 of an empty string

        if expect and expect != md5 and md5 != Filesystem.last_reported_md5:
            Filesystem.last_reported_md5 = md5
            text = "MD5 changed for " + str(path) + " (was: {}, is: {}): ".format(expect, md5)
            logging.info(text + str(attributes)[:1000] + ("…" if len(str(attributes)) > 1000 else ""))
            logging.debug(text + str(attributes))

        return md5, modified

    @staticmethod
    def touch(path):
        """ Touch a file, or the first file in a directory """
        try:
            if os.path.isfile(path):
                # Update the modification time for the file
                Path(path).touch()
                return

            elif os.path.isdir(path):
                # Update modification time for the directory itself
                Path(path).touch()

                # Update modification time for the directory itself (Mounted Samba filesystems)
                with tempfile.NamedTemporaryFile(suffix="-dirmodified", dir=path) as f_obj:
                    Path(f_obj.name).touch()

                # Update modification time for the first file in the directory
                for dirPath, subdirList, fileList in os.walk(path):
                    fileList.sort()
                    subdirList.sort()
                    ignore = Filesystem.shutil_ignore_patterns(dirPath, fileList + subdirList)
                    for s in reversed(range(len(subdirList))):
                        if subdirList[s] in ignore:
                            del subdirList[s]  # remove ignored folders in-place
                    for f in fileList:
                        if f in ignore:
                            continue  # skip ignored files
                        filePath = os.path.join(dirPath, f)
                        Path(filePath).touch()
                        return

            else:
                logging.warning("Path does not refer to a file or a directory: {}".format(path))

        except FileNotFoundError as e:
            logging.exception("Filen eller mappen ble ikke funnet. Kanskje noen slettet den?")
            raise e

    def copytree(self, src, dst):
        assert os.path.isdir(src)

        # check if ancestor directory should be ignored
        src_parts = os.path.abspath(src).split("/")
        for i in range(1, len(src_parts)):
            ignore = Filesystem.shutil_ignore_patterns("/" + "/".join(src_parts[1:i]), [src_parts[i]])
            if ignore:
                return dst

        # use shutil.copytree if the target does not exist yet (no need to merge copy)
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
                            self.pipeline.utils.report.error("Klarte ikke å erstatte filen med nyere versjon: " + dst_subpath)
                    else:
                        shutil.copy(src_subpath, dst_subpath)

        # Report files and folders that could not be removed and were not supposed to be replaced
        for item in dst_list:
            dst_subpath = os.path.join(dst, item)
            if item not in src_list:
                message = "Klarte ikke å fjerne "
                if os.path.isdir(dst_subpath):
                    message += "mappe"
                else:
                    message += "fil"
                message += " som ikke skal eksistere lenger: " + dst_subpath
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
                        self.pipeline.utils.report.info("{} finnes i {} fra før. Eksisterende kopi blir slettet.".format(os.path.basename(destination), os.path.dirname(destination)))
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

    def storeBook(self, source, book_id, overwrite = True, move=False, parentdir=None, dir_out=None, file_extension=None, subdir=None):
        """Store `book_id` from `source` into `pipeline.dir_out`"""
        assert book_id
        assert book_id.strip()
        assert book_id != "."
        assert not ".." in book_id
        assert not "/" in book_id
        assert not parentdir or not ".." in parentdir
        assert not parentdir or not "/" in parentdir
        if not dir_out:
            assert self.pipeline.dir_out is not None, (
                "When storing a book from a pipeline with no output directory, " +
                "the output directory to store the book in must be explicitly defined."
            )
            dir_out = self.pipeline.dir_out
        if parentdir:
            dir_out = os.path.join(dir_out, parentdir)
        self.pipeline.utils.report.info("Lagrer {} i {}...".format(book_id, dir_out))
        target = os.path.join(dir_out, book_id)
        if subdir:
            target = target + "/" + subdir
        if os.path.isfile(source) and file_extension:
            target += "." + str(file_extension)
        if os.path.exists(target):
            if overwrite == True:
                self.pipeline.utils.report.info("{} finnes i {} fra før. Eksisterende kopi blir slettet.".format(book_id, dir_out))
                try:
                    if os.path.isdir(target):
                        shutil.rmtree(target)
                    else:
                        os.remove(target)
                except (OSError, NotADirectoryError):
                    self.pipeline.utils.report.error("En feil oppstod ved sletting av mappen {}. Kanskje noen har en fil eller mappe åpen på datamaskinen sin?".format(dir_out))
                    self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                    raise
            else:
                self.pipeline.utils.report.info(book_id + " finnes fra før og skal ikke overskrives.")
                return target
        if move:
            shutil.move(source, target)
        else:
            self.copy(source, target)

        Filesystem.touch(target)

        return target

    def deleteSource(self):
        if os.path.isdir(self.pipeline.book["source"]):
            shutil.rmtree(self.pipeline.book["source"])
        elif os.path.isfile(self.pipeline.book["source"]):
            os.remove(self.pipeline.book["source"])

    def run(self, *args, cwd=None, **kwargs):
        if not cwd:
            assert self.pipeline.dir_in is not None, (
                "Filesystem.run: for pipelines with no input directory, " +
                "the current working directory needs to be explicitly set."
            )
            cwd = self.pipeline.dir_in

        return Filesystem.run_static(*args, cwd, self.pipeline.utils.report, **kwargs)

    @staticmethod
    def run_static(args, cwd, report, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False, timeout=600, check=True, stdout_level="DEBUG", stderr_level="DEBUG"):
        """Convenience method for subprocess.run, with our own defaults"""

        report.debug("Kjører: "+(" ".join(args) if isinstance(args, list) else args))

        completedProcess = None
        try:
            completedProcess = subprocess.run(args, stdout=stdout, stderr=stderr, shell=shell, cwd=cwd, timeout=timeout, check=check)

        except subprocess.CalledProcessError as e:
            report.error(traceback.format_exc(), preformatted=True)
            completedProcess = e

        report.debug("---- stdout: ----")
        report.add_message(stdout_level, completedProcess.stdout.decode("utf-8").strip(), add_empty_line_between=True)
        report.debug("-----------------")
        report.debug("---- stderr: ----")
        report.add_message(stderr_level, completedProcess.stderr.decode("utf-8").strip(), add_empty_line_between=True)
        report.debug("-----------------")

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
                    self.pipeline.utils.report.error("En feil oppstod ved lesing av ZIP-filen. Kanskje noen endret eller slettet den?")
                    self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
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

    @staticmethod
    def get_host_from_url(addr):
        if not Filesystem.hosts:
            Filesystem.hosts = {}
        if addr not in Filesystem.hosts:
            Filesystem.hosts[addr] = {
                "last_updated": 0,
                "host": None
            }
        if time.time() - Filesystem.hosts[addr]["last_updated"] > 3600:
            try:
                logging.info("Getting host from URL: {}".format(addr))
                host = urllib.parse.urlparse(addr)
                host = socket.gethostbyaddr(host.netloc.split(":")[0])
                logging.info("Host for URL is: {}".format(host[0]))
                Filesystem.hosts[addr]["host"] = host[0]
            except Exception:
                Filesystem.hosts[addr]["host"] = None
        return Filesystem.hosts[addr]["host"]

    @staticmethod
    def get_base_path(path, base_dirs):
        for d in base_dirs:
            relpath = os.path.relpath(path, base_dirs[d])
            if not relpath.startswith("../"):
                return base_dirs[d]
        return None
