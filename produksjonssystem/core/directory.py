#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import logging
import os
import pickle
import tempfile
import threading
import time
import traceback
from collections import OrderedDict
from pathlib import Path
from threading import RLock, Thread

from core.config import Config
from core.utils.filesystem import Filesystem
from core.utils.report import Report


class Directory():
    """
    Base class for monitoring directories.

    TODO: this does not handle "parentdirs"
    """

    # instance variables
    threads = None
    _bookMonitorThread = None
    _md5 = None
    _md5_lock = None
    dir_id = None
    dir_id_is_generated = None
    dir_path = None
    shouldRun = None
    book_event_handlers = None
    status_text = None
    starting = None
    inactivity_timeout = None
    cache_file = None
    last_availability_check_time = None
    suggested_for_rescan = None

    # static variables
    _static_lock = RLock()  # lock for changing the static variables

    dirs = {}

    dirs_ranked = []  # calculated in run.py
    dirs_flat = {}  # calculated in run.py

    def __init__(self, dir_path, inactivity_timeout=10):
        self.dir_id, self.dir_id_is_generated = Directory.get_id(dir_path)
        self.dir_path = os.path.normpath(dir_path)
        self.shouldRun = True
        self.book_event_handlers = []
        self.status_text = "0 / ?"
        self.starting = True
        self.inactivity_timeout = inactivity_timeout
        self.last_availability_check_time = 0
        self.suggested_for_rescan = []

        self._md5_lock = RLock()
        with self._md5_lock:
            self._md5 = {}

        self.threads = []

        self._bookMonitorThread = Thread(target=self._monitor_book_events_thread, name="event in {}".format(self.dir_id))
        self._bookMonitorThread.setDaemon(True)
        self._bookMonitorThread.start()
        self.threads.append(self._bookMonitorThread)

    @staticmethod
    def get_id(dir_path):
        dir_path = os.path.normpath(dir_path)
        with Directory._static_lock:
            for dir_id in Directory.dirs_flat:
                if os.path.normpath(Directory.dirs_flat[dir_id]) == dir_path:
                    return dir_id, False

            # dir not found, let's generate an id and add it to dirs_ranked and dirs_flat
            for i in range(0, len(Directory.dirs_flat) + 1):
                dir_id = "dir_{}".format(i)
                if dir_id not in Directory.dirs_flat:
                    break  # found a unused dir_id

            # add path to Directory.dirs_flat
            Directory.dirs_flat[dir_id] = dir_path

            # add path to Directory.dirs_ranked
            if "unknown" not in Directory.dirs_ranked:
                Directory.dirs_ranked.append({
                    "id": "unknown",
                    "name": "Ukjent",
                    "dirs": OrderedDict()
                })
            rank_position = 0
            for i in range(0, len(Directory.dirs_ranked)):
                if Directory.dirs_ranked[rank_position]["id"] == "unkown":
                    rank_position = i
                    break
            Directory.dirs_ranked[rank_position]["dirs"][dir_id] = dir_path

            return dir_id, True

    @staticmethod
    def get(dir_path):
        dir_path = os.path.normpath(dir_path)
        with Directory._static_lock:
            return Directory.dirs.get(dir_path, None)

    @staticmethod
    def start_watching(dir_path, inactivity_timeout=None):
        dir_path = os.path.normpath(dir_path)
        with Directory._static_lock:
            if dir_path not in Directory.dirs:
                Directory.dirs[dir_path] = Directory(dir_path)

            elif inactivity_timeout is not None:
                # The inactivity_timeout is normally defined when creating the directory
                # as an input directory. In case the directory is already created as an
                # output directory (i.e. without a inactivity_timeout), and we now
                # try to instantiate it as an input directory (i.e. with a inactivity_timeout),
                # then we update the inactivity_timeout
                Directory.dirs[dir_path].set_inactivity_timeout(inactivity_timeout)

            if inactivity_timeout:
                Directory.dirs[dir_path].inactivity_timeout = inactivity_timeout

            return Directory.dirs[dir_path]

    @staticmethod
    def stop(dir_path):
        dir_path = os.path.normpath(dir_path)
        dir = None

        with Directory._static_lock:
            if dir_path in Directory.dirs:
                dir = Directory.dirs[dir_path]

        if dir is not None:
            dir.shouldRun = False

            is_alive = True
            while is_alive:
                is_alive = False
                for thread in dir.threads:
                    if thread and thread != threading.current_thread() and thread.is_alive():
                        is_alive = True
                        logging.info("Directory thread is still running: {}".format(thread.name))
                        thread.join(timeout=60)

            with Directory._static_lock:
                if dir_path in Directory.dirs:
                    del Directory.dirs[dir_path]

    def set_inactivity_timeout(self, inactivity_timeout):
        self.inactivity_timeout = inactivity_timeout

    def initialize_checksums(self):
        with self._md5_lock:
            return self._initialize_checksums()

    def _initialize_checksums(self):
        cache_dir = Config.get("cache_dir", None)
        if not cache_dir:
            cache_dir = os.getenv("CACHE_DIR", os.path.join(tempfile.gettempdir(), "prodsys-cache"))
            if not os.path.isdir(cache_dir):
                os.makedirs(cache_dir, exist_ok=True)
            Config.set("cache_dir", cache_dir)

        self.cache_file = None
        if not self.dir_id_is_generated:
            self.cache_file = os.path.join(cache_dir, "dir.{}.md5.pickle".format(self.dir_id))
            if os.path.isfile(self.cache_file):
                try:
                    with open(self.cache_file, 'rb') as f:
                        self._md5 = pickle.load(f)
                except Exception as e:
                    logging.exception("Cache file found, but could not parse it", e)
            else:
                logging.debug("Can't find cache file")

        if self._md5:
            logging.debug("Loaded directory status from cache file, doing a partial rescan")

        else:
            logging.debug("Directory status not cached, doing a full rescan")
            self._md5 = {}

        dir_list = Filesystem.list_book_dir(self.dir_path)
        self.status_text = "Looking for created/deleted"

        for book in list(self._md5.keys()):  # list(….keys()) to avoid "RuntimeError: dictionary changed size during iteration"
            if not self.shouldRun:
                self._md5 = {}
                return  # break loop if we're shutting down the system
            if book not in dir_list:
                logging.debug("{} is in cache but not in directory: deleting from cache".format(book))
                del self._md5[book]

        md5_count = 0
        self.status_text = "0 / {}".format(len(dir_list))
        for book in dir_list:
            if not self.shouldRun:
                self._md5 = {}
                return  # break loop if we're shutting down the system
            if book not in self._md5:
                logging.debug("{} is in directory but not in cache: adding to cache".format(book))
                self._update_md5(book)
            md5_count += 1
            self.status_text = "{} / {}".format(md5_count, len(dir_list))
            if md5_count == 1 or md5_count % 100 == 0:
                logging.info(self.status_text)
            if md5_count % 10 == 0:
                self.store_checksums(while_starting=True)  # if for some reason the system crashes, we don't have to start all over again

        self.store_checksums(while_starting=True)
        self.starting = False
        self.status_text = None
        return

    def store_checksums(self, while_starting=False):
        if not while_starting and self.is_starting():
            # Cache is not complete yet. Cache will not be saved
            return

        with self._md5_lock:
            return self._store_checksums()

    def _store_checksums(self):
        if not self.cache_file:
            # No cache file defined. Cannot cache directory checksums
            return

        if not os.path.exists(os.path.dirname(self.cache_file)):
            os.makedirs(os.path.dirname(self.cache_file))

        if len(self._md5) == 0:
            # No checksums in cache. Cache will not be saved
            return

        with open(self.cache_file, 'wb') as f:
            pickle.dump(self._md5, f, -1)

    def is_starting(self):
        return self.starting

    def is_available(self):
        if self.last_availability_check_time >= time.time() - 10:
            if not self.last_availability_check_time:
                logging.debug("Directory is not available (cached result)" + (": {}".format(self.dir_path) if self.dir_path else ""))
            return self.last_availability_check_result

        self.last_availability_check_time = time.time()

        if self.dir_path is None:
            self.last_availability_check_result = True
            return self.last_availability_check_result

        self.last_availability_check_result = False

        is_mount = Filesystem.ismount(self.dir_path)
        contains_books = False
        if is_mount:
            for entry in os.scandir(self.dir_path):
                contains_books = True
                break
        mount_is_mounted = not is_mount or contains_books

        self.last_availability_check_result = os.path.isdir(self.dir_path) and mount_is_mounted

        if not self.last_availability_check_result:
            logging.warning("Directory is not available: " + str(self.dir_path))
            logging.debug(str(self.dir_path) + " is " + ("" if os.path.isdir(self.dir_path) else "not ") + " a directory.")
            logging.debug(str(self.dir_path) + " is " + ("" if is_mount else "not ") + " a mounted filesystem.")
            logging.debug(str(self.dir_path) + " does " + ("" if contains_books else "not ") + " contain books.")

        return self.last_availability_check_result

    def get_status_text(self):
        return self.status_text

    def add_book_event_handler(self, fn):
        if fn not in self.book_event_handlers:
            self.book_event_handlers.append(fn)

    def notify_book_event_handlers(self, name, event_type):
        for fn in self.book_event_handlers:
            fn(name, event_type)

    def suggest_rescan(self, name):
        with self._md5_lock:
            self.suggested_for_rescan.append(name)

    def _update_md5(self, name):
        assert self.dir_path is not None, "Cannot get MD5 checksum for {} when there is no input directory".format(name)

        path = os.path.join(self.dir_path, name)

        assert "/" not in name

        with self._md5_lock:
            shallow_md5, _ = Filesystem.path_md5(path=path, shallow=True, expect=self._md5[name]["shallow"] if name in self._md5 else None)
            deep_md5, modified = Filesystem.path_md5(path=path, shallow=False, expect=self._md5[name]["deep"] if name in self._md5 else None)
            modified = max(modified if modified else 0, self._md5[name]["modified"] if name in self._md5 else 0)
            self._md5[name] = {
                "shallow": shallow_md5,
                "shallow_checked": int(time.time()),
                "deep": deep_md5,
                "deep_checked": int(time.time()),
                "modified": modified,
            }

    def _monitor_book_events_thread(self):
        self.initialize_checksums()

        while self.shouldRun:
            try:
                # books that are recently changed (check often in case of new file changes)
                with self._md5_lock:
                    recently_changed = sorted([book for book in self._md5 if time.time() - self._md5[book]["modified"] < self.inactivity_timeout],
                                              key=lambda rc: self._md5[rc]["modified"])
                    if recently_changed:
                        for book in recently_changed:
                            deep_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_path, book), shallow=False)
                            self._md5[book]["deep_checked"] = int(time.time())
                            if deep_md5 != self._md5[book]["deep"]:
                                self._md5[book]["modified"] = int(time.time())
                                self._update_md5(book)
                                logging.debug("book modified (and was recently modified, might be in the middle of a copy operation): {}".format(book))
                                self.notify_book_event_handlers(book, "modified")

                        time.sleep(0.1)  # a small nap
                        continue

                time.sleep(1)  # unless anything has recently changed, give the system time to breathe between each iteration

                if not self.is_available():
                    time.sleep(5)
                    continue

                dirlist = Filesystem.list_book_dir(self.dir_path)
                sorted_dirlist = []
                should_deepscan = []

                # books that have explicitly been requested for rescan should be rescanned first
                if self.suggested_for_rescan:
                    for book_id in self.suggested_for_rescan:
                        book_path = os.path.join(self.dir_path, book_id)

                        if os.path.exists(book_path):
                            sorted_dirlist.append(book_id)
                            should_deepscan.append(book_id)

                        else:
                            # if book is a file, then it can have a file extension
                            for dirname in dirlist:
                                if Path(dirname).stem == book_id:
                                    sorted_dirlist.append(dirname)
                                    should_deepscan.append(dirname)
                                    break

                    # empty list after having put the suggestions at the front of the queue
                    self.suggested_for_rescan = []

                    # add the remaining books to the list
                    for dirname in dirlist:
                        if dirname not in sorted_dirlist:
                            sorted_dirlist.append(dirname)
                    if len(dirlist) != len(sorted_dirlist):
                        logging.warning("len(dirlist) != len(sorted_dirlist)")
                        logging.warning("dirlist: {}".format(dirlist))
                        logging.warning("sorted_dirlist: {}".format(sorted_dirlist))
                    dirlist = sorted_dirlist

                # do a shallow check of files and folders (i.e. don't check file sizes, modification times etc. in subdirectories)
                for book in dirlist:
                    if not self.shouldRun:
                        break  # break loop if we're shutting down the system (iterating books may take some time)

                    with self._md5_lock:
                        if not os.path.exists(os.path.join(self.dir_path, book)):
                            # iterating over all books can take a lot of time,
                            # and the book may have been deleted by the time we get to it.
                            self.notify_book_event_handlers(book, "deleted")
                            logging.debug("book deleted: {}".format(book))
                            del self._md5[book]
                            continue

                        if book not in self._md5:
                            self._update_md5(book)
                            self.notify_book_event_handlers(book, "created")
                            logging.debug("book created: {}".format(book))
                            continue

                        shallow_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_path, book),
                                                             shallow=True,
                                                             expect=self._md5[book]["shallow"] if book in self._md5 else None)
                        if shallow_md5 != self._md5[book]["shallow"]:
                            self._update_md5(book)
                            self.notify_book_event_handlers(book, "modified")
                            logging.debug("book modified (top-level dir/file modified): {}".format(book))
                            continue

                with self._md5_lock:
                    deleted = [book for book in self._md5 if book not in dirlist]
                    for book in deleted:
                        self.notify_book_event_handlers(book, "deleted")
                        logging.debug("book deleted: {}".format(book))
                        del self._md5[book]
                    if deleted:
                        continue

                self.store_checksums()  # regularly store updated version of checksums

                # do a deep check (size/time etc. of files in subdirectories) of up to 10 books that haven't been checked in a while
                with self._md5_lock:
                    long_time_since_checked = sorted([{"name": book, "md5": self._md5[book]} for book in self._md5
                                                      if time.time() - self._md5[book]["modified"] > self.inactivity_timeout],
                                                     key=lambda book: book["md5"]["deep_checked"])
                    long_time_since_checked = [b["name"] for b in long_time_since_checked]
                    for book in should_deepscan + long_time_since_checked[:10]:
                        if not self.shouldRun:
                            break  # break loop if we're shutting down the system

                        deep_md5, _ = Filesystem.path_md5(path=os.path.join(self.dir_path, book),
                                                          shallow=False,
                                                          expect=self._md5[book]["deep"] if book in self._md5 else None)
                        if book not in self._md5:
                            self._update_md5(book)
                        else:
                            self._md5[book]["deep_checked"] = int(time.time())
                            if deep_md5 != self._md5[book]["deep"]:
                                self._md5[book]["modified"] = int(time.time())
                                self._update_md5(book)
                                self.notify_book_event_handlers(book, "modified")
                                logging.debug("book modified: {}".format(book))

                self.store_checksums()  # regularly store updated version of checksums

            except Exception:
                logging.exception("En feil oppstod ved overvåking av {}".format(self.dir_path))
                try:
                    Report.emailPlainText("En feil oppstod ved overvåking av {}".format(self.dir_path),
                                          traceback.format_exc(),
                                          recipients=[])
                except Exception:
                    logging.exception("Could not e-mail exception")
