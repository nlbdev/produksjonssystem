#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import filecmp
import os
import sys
import tempfile
import time
from os import walk

import yaml
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

        time_created = time.strftime("%Y-%m-%dT%H:%M:%S")

        if not os.path.exists(os.path.join(self.dir_out, epub.identifier())):
            os.makedirs(os.path.join(self.dir_out, epub.identifier()))

        dictfiles = {}
        changelog = "changelog.txt"
        deleted = "deleted.yml"
        changes_made = False

        # Dictfiles contains the most recent version of each file, can save this in a yaml file, like newest_files.yml
        for (path, subdir_list, file_list) in walk(os.path.join(self.dir_out, epub.identifier())):
            for file_name in file_list:
                if file_name == changelog:
                    break
                file_path = os.path.join(self.dir_out, epub.identifier(), path, file_name)
                new_dict = {file_name: file_path}
                if file_name not in dictfiles:
                    dictfiles.update(new_dict)
                elif dictfiles[file_name] < file_path:
                    dictfiles.update(new_dict)

        changelog_path = os.path.join(self.dir_out, epub.identifier(), changelog)
        if os.path.exists(changelog_path):
            append_write = 'a'  # append if already exists
        else:
            append_write = 'w'  # make a new file if not
        changelog_file = open(changelog_path, append_write)
        new_file_list = []

        # Changelog.txt contains the history of changes to this nlbpub with timestamps
        for temp_path, temp_subdir_list, temp_file_list in walk(temp_epubdir):
            for temp_file in temp_file_list:
                new_file_list.append(temp_file)
                temp_file_path = os.path.join(temp_epubdir, temp_path, temp_file)

                if temp_file in dictfiles and filecmp.cmp(temp_file_path, dictfiles[temp_file]):
                    os.remove(temp_file_path)
                    # Remove empty folders
                    if len(os.listdir(temp_path)) == 0:
                        os.rmdir(temp_path)

                elif temp_file in dictfiles and not filecmp.cmp(temp_file_path, dictfiles[temp_file]):
                    changes_made = True
                    self.utils.report.info("Fil endret: " + temp_file)
                    changelog_file.write("\n{}:     Fil endret: {}".format(time_created, temp_file))
        folders = list(os.walk(temp_epubdir))[1:]

        # Remove the rest of the empty dirs
        for folder in folders:
            if not folder[2]:
                os.rmdir(folder[0])

        # Overview of deleted files, yaml file with delete history is located at deleted_path
        deleted_path = os.path.join(self.dir_out, epub.identifier(), deleted)
        if os.path.exists(deleted_path):
            deleted_append_write = 'a'  # append if already exists
        else:
            deleted_append_write = 'w'  # make a new file if not
        deleted_file = open(deleted_path, deleted_append_write)

        with open(deleted_path, 'r') as f:
            deleted_doc = yaml.load(f) or {}

        # Deleted file history
        for key in dictfiles:
                if key not in new_file_list and key not in deleted_doc:
                    changes_made = True
                    self.utils.report.info("Fil slettet: " + key)
                    changelog_file.write("\n{}:     Fil slettet: {}".format(time_created, key))
                    deleted_file.write("\n{}: {}".format(key, dictfiles[key]))
        changelog_file.close()

        # Save copy of different files in NLBPUB master. Different versions of files under NLBPUB-tidligere/xxxxxxx/time
        # To restore a certain version copy files from the each folder up to the wanted version to a new folder

        archived_path = self.utils.filesystem.storeBook(temp_epubdir, epub.identifier(), subdir=time_created)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        if changes_made:
            self.utils.report.info("Endringer oppdaget for: " + epub.identifier() + ", endrede filer ble kopiert til NLBpub tidligere versjoner.")
            self.utils.report.title = self.title + ": " + epub.identifier() + " 👍😄" + epubTitle
        else:
            self.utils.report.info("Ingen endringer oppdaget for " + epub.identifier())
            self.utils.report.should_email = False
        return True


if __name__ == "__main__":
    NlbpubPrevious().run()
