# -*- coding: utf-8 -*-

import hashlib
import logging
import os
import re
import requests
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
    hosts = {}  # hosts cache

    shutil_ignore_patterns = shutil.ignore_patterns(  # supports globs: shutil.ignore_patterns('*.pyc', 'tmp*')
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
                            stat = None

                            # try handling FileNotFoundError: [Errno 2] No such file or directory
                            stat_retries = 3
                            while stat_retries > 0:
                                try:
                                    stat_retries -= 1
                                    stat = os.stat(filePath)
                                except FileNotFoundError as e:
                                    if stat_retries >= 0:
                                        logging.warning("Filen eller mappen ble ikke funnet ({}). Prøver igjen…".format(f))
                                        # time.sleep(1)
                                    else:
                                        raise e

                            if stat is not None:
                                attributes.extend([filePath, round(stat.st_mtime), stat.st_size, stat.st_mode])
                            else:
                                attributes.extend([filePath, 0, 0, 0])
                            modified = max(modified, stat.st_mtime if stat is not None else 0)
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

    @staticmethod
    def copytree(report, src, dst):
        assert os.path.isdir(src)

        # check if ancestor directory should be ignored
        src_parts = os.path.abspath(src).split("/")
        for i in range(1, len(src_parts)):
            ignore = Filesystem.shutil_ignore_patterns("/" + "/".join(src_parts[1:i]), [src_parts[i]])
            if ignore:
                return dst

        # use shutil.copytree if the target does not exist yet (no need to merge copy)
        if not os.path.exists(dst):
            try:
                return shutil.copytree(src, dst, ignore=Filesystem.shutil_ignore_patterns)
            except shutil.Error:
                short_src = os.path.sep.join(src.split(os.path.sep)[:3]) + os.path.sep + "…"
                short_dst = os.path.sep.join(dst.split(os.path.sep)[:3]) + os.path.sep + "…"
                raise Exception("An error occured while copying from {} to {}".format(short_src, short_dst))

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
                        try:
                            shutil.copytree(src_subpath, dst_subpath, ignore=Filesystem.shutil_ignore_patterns)
                        except shutil.Error:
                            short_src = os.path.sep.join(src.split(os.path.sep)[:3]) + os.path.sep + "…"
                            short_dst = os.path.sep.join(dst.split(os.path.sep)[:3]) + os.path.sep + "…"
                            raise Exception("An error occured while copying from {} to {}".format(short_src, short_dst))

                    else:
                        Filesystem.copytree(report, src_subpath, dst_subpath)
                else:
                    # Report files that have changed but where the target could not be overwritten
                    if os.path.exists(dst_subpath):
                        src_md5 = Filesystem.path_md5(src_subpath, shallow=False)
                        dst_md5 = Filesystem.path_md5(dst_subpath, shallow=False)
                        if src_md5 != dst_md5:
                            report.error("Klarte ikke å erstatte filen med nyere versjon: " + dst_subpath)
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
                report.error(message)

        return dst

    @staticmethod
    def copy(report, source, destination):
        """Copy the `source` file or directory to the `destination`"""
        assert source, "Filesystem.copy(): source must be specified"
        assert destination, "Filesystem.copy(): destination must be specified"
        assert os.path.isdir(source) or os.path.isfile(source), "Filesystem.copy(): source must be either a file or a directory: " + str(source)
        report.debug("Copying from '" + source + "' to '" + destination + "'")

        if os.path.isdir(source):
            files_source = os.listdir(source)
        else:
            files_source = [source]

        if os.path.isdir(source):
            try:
                if os.path.exists(destination):
                    if os.listdir(destination):
                        report.info("{} finnes i {} fra før. Eksisterende kopi blir slettet.".format(
                            os.path.basename(destination),
                            os.path.dirname(destination))
                        )
                    shutil.rmtree(destination, ignore_errors=True)
                Filesystem.copytree(report, source, destination)
            except shutil.Error as errors:
                warnings = []
                for arg in errors.args[0]:
                    src, dst, e = arg
                    if e.startswith("[Errno 95]") and "/gvfs/" in dst:
                        warnings.append("WARN: Unable to set permissions on manually mounted samba shares")
                    else:
                        warnings.append(None)
                warnings = list(set(warnings))  # distinct warnings
                for warning in warnings:
                    if warning is not None:
                        report.warn(warning)
                if None in warnings:
                    raise
        else:
            shutil.copy(source, destination)

        if len(files_source) >= 2:
            files_dir_out = os.listdir(destination)
            for file in files_source:
                if file not in files_dir_out:
                    report.warn("WARNING: Det ser ut som det mangler noen filer som ble kopiert av Filesystem.copy(): " + str(file))

        elif os.path.isfile(source) and not os.path.isfile(destination):
            report.warn("WARNING: Det ser ut som det mangler noen filer som ble kopiert av Filesystem.copy(): " + str(source))

    def storeBook(self, source, book_id, overwrite=True, move=False, parentdir=None, dir_out=None, file_extension=None, subdir=None, fix_permissions=True):
        """Store `book_id` from `source` into `pipeline.dir_out`"""
        assert book_id
        assert book_id.strip()
        assert book_id != "."
        assert ".." not in book_id
        assert "/" not in book_id
        assert not parentdir or ".." not in parentdir
        assert not parentdir or "/" not in parentdir

        if os.path.isdir(source):
            files_source = os.listdir(source)
        else:
            files_source = [source]

        if not dir_out:
            assert self.pipeline.dir_out is not None, (
                "When storing a book from a pipeline with no output directory, " +
                "the output directory to store the book in must be explicitly defined."
            )
            dir_out = self.pipeline.dir_out
        dir_nicename = "/".join(dir_out.split("/")[-2:])
        if parentdir:
            dir_out = os.path.join(dir_out, parentdir)
            dir_nicename = os.path.join(dir_nicename, parentdir)
        self.pipeline.utils.report.info("Lagrer {} i {}...".format(book_id, dir_out))
        target = os.path.join(dir_out, book_id)
        if subdir:
            target = target + "/" + subdir
        if os.path.isfile(source) and file_extension:
            target += "." + str(file_extension)
        if os.path.exists(target):
            if overwrite is True:
                self.pipeline.utils.report.info("{} finnes i {} fra før. Eksisterende kopi blir slettet.".format(book_id, dir_nicename))
                try:
                    if os.path.isdir(target):
                        shutil.rmtree(target)
                    else:
                        os.remove(target)
                except (OSError, NotADirectoryError):
                    self.pipeline.utils.report.error(
                        "En feil oppstod ved sletting av mappen {}. Kanskje noen har en fil eller mappe åpen på datamaskinen sin?".format(target)
                    )
                    self.pipeline.utils.report.debug(traceback.format_exc(), preformatted=True)
                    raise
            else:
                self.pipeline.utils.report.warn("{} finnes fra før i {} og skal ikke overskrives.".format(book_id, dir_nicename))
                return target, False
        if move:
            shutil.move(source, target)
        else:
            Filesystem.copy(self.pipeline.utils.report, source, target)

        Filesystem.touch(target)

        if fix_permissions:
            Filesystem.fix_permissions(target)

        self.pipeline.utils.report.info("{} ble lagt til i {}.".format(book_id, dir_nicename))

        if self.pipeline and self.pipeline.dir_out_obj:
            self.pipeline.dir_out_obj.suggest_rescan(book_id)

        if len(files_source) >= 2:
            files_dir_out = os.listdir(target)
            for file in files_source:
                if file not in files_dir_out:
                    self.pipeline.utils.report.warn("WARNING: Det ser ut som det mangler noen filer som ble kopiert av filesystem.storeBook().")
                    break
        elif os.path.isfile(source) and not os.path.isfile(target):
            self.pipeline.utils.report.warn("WARNING: Det ser ut som det mangler noen filer som ble kopiert av filesystem.storeBook().")

        return target, True

    def deleteSource(self):
        if os.path.isdir(self.pipeline.book["source"]):
            shutil.rmtree(self.pipeline.book["source"])
        elif os.path.isfile(self.pipeline.book["source"]):
            os.remove(self.pipeline.book["source"])

    def fix_permissions(target):
        # ensure that permissions are correct
        if os.path.isfile(target):
            os.chmod(target, 0o664)
        else:
            os.chmod(target, 0o777)
            for root, dirs, files in os.walk(target):
                for d in dirs:
                    os.chmod(os.path.join(root, d), 0o777)
                for f in files:
                    os.chmod(os.path.join(root, f), 0o664)

    @staticmethod
    def insert_css(path, library, format):

        latest_url = "https://raw.githubusercontent.com/nlbdev/nlb-scss/master/dist/css/ncc.min.css"
        if library == "Statped":
            latest_url = "https://raw.githubusercontent.com/StatpedEPUB/nlb-scss/master/dist/css/statped.min.css"
        elif format == "epub":
            latest_url = "https://raw.githubusercontent.com/nlbdev/nlb-scss/master/dist/css/epub.css"
        elif format == "daisy202":
            latest_url = "https://raw.githubusercontent.com/nlbdev/nlb-scss/master/dist/css/html.min.css"
        elif format == "daisy202-ncc":
            latest_url = "https://raw.githubusercontent.com/nlbdev/nlb-scss/master/dist/css/ncc.min.css"

        response = requests.get(latest_url)
        if response.status_code == 200:
            with open(path, "wb") as target_file:
                target_file.write(response.content)

    def run(self, *args, cwd=None, **kwargs):
        if not cwd:
            assert self.pipeline.dir_in is not None, (
                "Filesystem.run: for pipelines with no input directory, " +
                "the current working directory needs to be explicitly set."
            )
            cwd = self.pipeline.dir_in

        return Filesystem.run_static(*args, cwd, self.pipeline.utils.report, **kwargs)

    @staticmethod
    def run_static(args,
                   cwd,
                   report=None,
                   stdout=subprocess.PIPE,
                   stderr=subprocess.PIPE,
                   shell=False,
                   timeout=600,
                   check=True,
                   stdout_level="DEBUG",
                   stderr_level="DEBUG"):
        """Convenience method for subprocess.run, with our own defaults"""

        (report if report else logging).debug("Kjører: "+(" ".join(args) if isinstance(args, list) else args))

        completedProcess = None
        try:
            completedProcess = subprocess.run(args, stdout=stdout, stderr=stderr, shell=shell, cwd=cwd, timeout=timeout, check=check)

        except subprocess.CalledProcessError as e:
            if report:
                report.error(traceback.format_exc(), preformatted=True)
            else:
                logging.error("exception occured", exc_info=True)
            completedProcess = e

        (report if report else logging).debug("---- stdout: ----")
        if report:
            report.add_message(stdout_level, completedProcess.stdout.decode("utf-8").strip(), add_empty_line_between=True)
        else:
            logging.info(completedProcess.stdout.decode("utf-8"))
        (report if report else logging).debug("-----------------")
        (report if report else logging).debug("---- stderr: ----")
        if report:
            report.add_message(stderr_level, completedProcess.stderr.decode("utf-8").strip(), add_empty_line_between=True)
        else:
            logging.info(completedProcess.stderr.decode("utf-8"))
        (report if report else logging).debug("-----------------")

        return completedProcess

    @staticmethod
    def zip(report, directory, file):
        """Zip the contents of `dir`"""
        assert directory, "zip: directory must be specified: "+str(directory)
        assert os.path.isdir(directory), "zip: directory must exist and be a directory: "+directory
        assert file, "zip: file must be specified: "+str(file)
        dirpath = Path(directory)
        with zipfile.ZipFile(file, 'w') as archive:
            for f in dirpath.rglob('*'):
                relative = str(f.relative_to(dirpath))
                report.debug("zipping: " + relative)
                archive.write(str(f), relative, compress_type=zipfile.ZIP_DEFLATED)

    @staticmethod
    def unzip(report, archive, target):
        """Unzip the contents of `archive`, as `dir`"""
        assert archive, "unzip: archive must be specified: "+str(archive)
        assert os.path.exists(archive), "unzip: archive must exist: "+archive
        assert target, "unzip: target must be specified: "+str(target)
        assert os.path.isdir(target) or not os.path.exists(target), "unzip: if target exists, it must be a directory: "+target

        if not os.path.exists(target):
            os.makedirs(target)

        if os.path.isdir(archive):
            Filesystem.copy(report, archive, target)

        else:
            with zipfile.ZipFile(archive, "r") as zip_ref:
                try:
                    zip_ref.extractall(target)
                except EOFError as e:
                    report.error("En feil oppstod ved lesing av ZIP-filen. Kanskje noen endret eller slettet den?")
                    report.debug(traceback.format_exc(), preformatted=True)
                    raise e

            Filesystem.fix_permissions(target)

    @staticmethod
    def ismount(path):
        return True if Filesystem.getdevice(path) else False

    @staticmethod
    def getdevice(path):
        path = os.path.normpath(path)

        with open('/proc/mounts', 'r') as f:
            for line in f.readlines():
                line = line.split()
                if line[1] == path:
                    # line[1] = "/mount/point"

                    if line[2] == "nfs":
                        # line[0] = a.b.c:/path/subpath
                        return "nfs://{}".format(line[0])

                    elif line[0].startswith("/") and line[1] == path:
                        # line[0] = "//x.x.x.x/sharename/optionalsubpath"
                        return re.sub("^//", "smb://", line[0])

        x_dir = os.getenv("XDG_RUNTIME_DIR")
        if x_dir and os.path.isdir(os.path.join(x_dir, "gvfs")):
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

        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        localhost = s.getsockname()[0]
        s.close()

        if smb is None:
            smb = "smb://" + localhost + path

        elif not re.match(r"^(smb|nfs):/+[^/]+/.*", smb):
            smb = "smb://{}/{}".format(localhost, smb)

        smb = re.sub(r"^((smb|nfs):/+[^/]+).*", r"\1", smb) + urllib.request.pathname2url(re.sub(r"^(smb|nfs):/+[^/]+/*(/.*)$", r"\2", smb))

        file = re.sub("^{}/".format(localhost), r"", re.sub(r"^(smb|nfs):", r"file:", smb))
        unc = re.sub("/", r"\\", re.sub(r"^(smb|nfs):", r"", smb))
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

    @staticmethod
    def list_book_dir(dir, subdirs=None):
        if subdirs:
            combined = []
            for p in subdirs:
                subdir = subdirs[p]
                subdirpath = os.path.join(dir, subdir)
                for filename in Filesystem.list_book_dir(subdirpath):
                    combined.append(os.path.join(subdir, filename))
            return combined

        dirlist = os.listdir(dir)

        if threading.current_thread().getName().endswith("event in nlbpub") and dir.endswith("master/NLBPUB/"):  # debugging strange bug
            logging.debug(dir)
            logging.debug("Filesystem.list_book_dir: '{}' in dirlist == {}".format("558282402019", "558282402019" in dirlist))

        filtered = []
        for dirname in dirlist:
            if Filesystem.should_ignore(os.path.join(dir, dirname)):
                # debugging strange bug
                if "master/NLBPUB" in dir and threading.current_thread().getName().endswith("event in nlbpub") and "558282402019" in dirname:
                    logging.debug("Filesystem.list_book_dir: '{}' is filtered out as a common system file".format(dirname))
                # Filter out common system files
                continue
            if len(dirname) == 0 or (dirname[0] not in "0123456789" and not dirname.startswith("TEST")):
                # debugging strange bug
                if "master/NLBPUB" in dir and threading.current_thread().getName().endswith("event in nlbpub") and "558282402019" in dirname:
                    logging.debug("Filesystem.list_book_dir: '{}' is filtered out because it doesn't start with a number".format(dirname))
                # Book identifiers must start with a number
                continue

            filtered.append(dirname)

        if threading.current_thread().getName().endswith("event in nlbpub") and dir.endswith("master/NLBPUB/"):  # debugging strange bug
            logging.debug("Filesystem.list_book_dir: '{}' in filtered == {}".format("558282402019", "558282402019" in filtered))
        return filtered

    @staticmethod
    def book_path_in_dir(dir, identifiers, subdirs=None):
        # check "pipeline parent directories" (i.e. subdirectories)
        if isinstance(subdirs, dict) and len(subdirs) >= 1:
            for key in subdirs:
                for name in Filesystem.list_book_dir(os.path.join(dir, subdirs[key])):
                    if Path(name).stem in identifiers:
                        return os.path.join(dir, subdirs[key], name)

        # check the directory itself
        else:
            for name in Filesystem.list_book_dir(dir):
                if Path(name).stem in identifiers:
                    return os.path.join(dir, name)

        # not found
        return None
