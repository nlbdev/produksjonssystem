#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import filecmp
import os
import shutil
import sys
import tempfile
import time

from core.pipeline import Pipeline
from core.utils.epub import Epub

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubPrevious(Pipeline):
    uid = "nlbpub-previous-versions"
    title = "NLBPUB tidligere versjoner"
    labels = ["EPUB"]
    publication_format = None
    expected_processing_time = 10

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " EPUB master slettet: " + self.book['name']
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")
        epub = Epub(self, self.book["source"])

        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass

        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        if not epub.identifier():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        self.utils.report.info("Lager en kopi av EPUBen")
        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_epubdir)

        if not os.path.exists(os.path.join(self.dir_out, epub.identifier())):
            os.makedirs(os.path.join(self.dir_out, epub.identifier()))

        dirlist = os.listdir(os.path.join(self.dir_out, epub.identifier()))

        identical_dir_exists = False

        # If an identical dir exists, delete contents of tempdir to prevent several of the same version being saved
        for dir in dirlist:
            if self.dirs_equal(os.path.join(self.dir_out, epub.identifier(), dir), temp_epubdir):
                identical_dir_exists = True
                for file in os.listdir(temp_epubdir):
                    file_path = os.path.join(temp_epubdir, file)
                    print(file_path)
                    if os.path.isfile(file_path):
                        os.remove(file_path)
                    if os.path.isdir(file_path):
                        shutil.rmtree(file_path)
                break

        time_created = time.strftime("%Y-%m-%dT%H:%M:%S")

        # Save copy of new NLBPUB master. Different versions under NLBPUB-tidligere/xxxxxxx/time
        if not identical_dir_exists:
            self.utils.report.info("Ny backup ble laget. Kopierer til NLBPUB-previous-arkiv.")
        else:
            self.utils.report.info("Identisk versjon ble funnet. Lagrer en tom mappe")

        archived_path = self.utils.filesystem.storeBook(temp_epubdir, epub.identifier(), subdir=time_created)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(epub.identifier() + " ble lagt til i NLBPUB-previous-arkivet.")
        self.utils.report.title = self.title + ": " + epub.identifier() + " ble kopiert 👍😄" + epubTitle
        return True

    def dirs_equal(self, dir1, dir2):
        """
        Compare two directories recursively. Files in each directory are
        assumed to be equal if their names and contents are equal.

        @param dir1: First directory path
        @param dir2: Second directory path

        @return: True if the directory trees are the same and
            there were no errors while accessing the directories or files,
            False otherwise.
       """

        dirs_cmp = filecmp.dircmp(dir1, dir2)
        if len(dirs_cmp.left_only) > 0 or len(dirs_cmp.right_only) > 0 or len(dirs_cmp.funny_files) > 0:
            return False
        (_, mismatch, errors) = filecmp.cmpfiles(dir1, dir2, dirs_cmp.common_files, shallow=False)
        if len(mismatch) > 0 or len(errors) > 0:
            return False
        for common_dir in dirs_cmp.common_dirs:
            new_dir1 = os.path.join(dir1, common_dir)
            new_dir2 = os.path.join(dir2, common_dir)
            if not self.dirs_equal(new_dir1, new_dir2):
                return False
        return True


if __name__ == "__main__":
    NlbpubPrevious().run()
