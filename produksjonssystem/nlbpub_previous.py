#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import filecmp
import os
import sys
import tempfile
import time
import traceback
from os import walk

import yaml

from core.pipeline import Pipeline
from core.utils.epub import Epub
from core.utils.filesystem import Filesystem

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class NlbpubPrevious(Pipeline):
    uid = "nlbpub-previous-versions"
    title = "NLBPUB tidligere versjoner"
    labels = ["EPUB", "Statped"]
    publication_format = None
    expected_processing_time = 520

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
        epub = Epub(self.utils.report, self.book["source"])

        epubTitle = ""
        try:
            epubTitle = " (" + epub.meta("dc:title") + ") "
        except Exception:
            pass

        # sjekk at dette er en EPUB
        if not epub.isepub():
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        if not epub.identifier() or not epub.identifier().isnumeric():
            self.utils.report.error(self.book["name"] + ": Klarte ikke å bestemme boknummer basert på dc:identifier.")
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎"
            return False

        self.utils.report.info("Lager en kopi av EPUBen")
        temp_epubdir_obj = tempfile.TemporaryDirectory()
        temp_epubdir = temp_epubdir_obj.name
        Filesystem.copy(self.utils.report, self.book["source"], temp_epubdir)

        if not os.path.exists(os.path.join(self.dir_out, epub.identifier())):
            os.makedirs(os.path.join(self.dir_out, epub.identifier()))

        time_created = time.strftime("%Y-%m-%dT%H:%M:%S")
        dictfiles = {}
        changelog = "changelog.txt"
        deleted = "deleted.yml"
        files = "files.yml"
        extra_files = [changelog, deleted, files, "restore_files.py"]
        changes_made = False
        new_epub = False

        # Overview of deleted files and changelog history
        deleted_path = os.path.join(self.dir_out, epub.identifier(), deleted)
        changelog_path = os.path.join(self.dir_out, epub.identifier(), changelog)

        deleted_doc = {}
        if os.path.isfile(deleted_path):
            with open(deleted_path, 'r') as f:
                deleted_doc = yaml.load(f, Loader=yaml.FullLoader) or {}

        # Dictfiles contains the most recent version of each file, saved to files.yml
        for (path, subdir_list, file_list) in walk(os.path.join(self.dir_out, epub.identifier())):
            for file_name in file_list:
                if file_name in extra_files:
                    continue
                file_path = os.path.join(path, file_name)
                relative_path = file_path.replace(os.path.join(self.dir_out, epub.identifier()), "")
                relative_path = relative_path.strip("/")
                short_path = self.short_path_by_one(relative_path)
                new_dict = {short_path: relative_path}

                if short_path not in dictfiles:
                    dictfiles.update(new_dict)
                elif dictfiles[short_path] < relative_path:
                    dictfiles.update(new_dict)

        new_file_list = []
        changelog_string = ""
        file_added_again = False
        # Changelog.txt contains the history of changes to this nlbpub with timestamps
        for temp_path, temp_subdir_list, temp_file_list in walk(temp_epubdir):
            for temp_file in temp_file_list:
                full_temp_file_path = os.path.join(temp_path, temp_file)
                temp_file = full_temp_file_path.replace(temp_epubdir, "")
                temp_file = temp_file.strip("/")
                new_file_list.append(temp_file)

                if temp_file in dictfiles and filecmp.cmp(full_temp_file_path, os.path.join(self.dir_out, epub.identifier(), dictfiles[temp_file])):
                    os.remove(full_temp_file_path)

                elif temp_file in dictfiles and not filecmp.cmp(full_temp_file_path, os.path.join(self.dir_out, epub.identifier(), dictfiles[temp_file])):
                    changes_made = True
                    new_location = {temp_file: os.path.join(time_created, temp_file)}
                    dictfiles.update(new_location)
                    self.utils.report.info("Fil endret: " + temp_file)
                    changelog_string += ("\n{}:     Fil endret: {}".format(time_created, temp_file))

                elif temp_file not in dictfiles:
                    if dictfiles == {}:
                        new_epub = True
                    changes_made = True
                    new_file = {temp_file: os.path.join(time_created, temp_file)}
                    dictfiles.update(new_file)
                    if not new_epub:
                        self.utils.report.info("Fil lagt til: " + temp_file)
                        changelog_string += ("\n{}:     Fil lagt til: {}".format(time_created, temp_file))

                if temp_file in deleted_doc:
                    changes_made = True
                    file_added_again = True
                    deleted_doc.pop(temp_file, None)
                    self.utils.report.info("Fil lagt til på nytt: " + temp_file)
                    changelog_string += ("\n{}:     Fil lagt til på nytt: {}".format(time_created, temp_file))

        dirs = next(walk(temp_epubdir))[1]
        for dir in dirs:
            self.del_empty_dirs(temp_epubdir, dir)

        if file_added_again:
            with open(deleted_path, 'w') as deleted_file:
                for key in deleted_doc:
                    deleted_file.write("\n'{}': '{}'".format(key.replace("'", "''"), time_created.replace("'", "''")))

        # Deleted file history saved to deleted files.yml
        with open(deleted_path, self.append_write(deleted_path)) as deleted_file:
            for key in dictfiles:
                if key not in new_file_list and key not in deleted_doc and key not in extra_files:
                    changes_made = True
                    self.utils.report.info("Fil slettet: " + key)
                    changelog_string += ("\n{}:     Fil slettet: {}".format(time_created, key))
                    deleted_file.write("\n'{}': '{}'".format(key.replace("'", "''"), time_created.replace("'", "''")))

        # Changelog saved to changelog.txt
        with open(changelog_path, self.append_write(changelog_path)) as changelog_file:
            changelog_file.write(changelog_string)

        deleted_doc = {}
        if os.path.isfile(deleted_path):
            with open(deleted_path, 'r') as f:
                deleted_doc = yaml.load(f, Loader=yaml.FullLoader) or {}

        for del_file in deleted_doc:
            try:
                del dictfiles[del_file]
            except Exception:
                self.utils.report.debug(traceback.format_exc(), preformatted=True)

        with open(os.path.join(temp_epubdir, files), 'w') as files_doc:
            for file in dictfiles:
                files_doc.write("\n'{}': '{}'".format(file.replace("'", "''"), dictfiles[file].replace("'", "''")))

        # Save copy of different files in NLBPUB master. Different versions of files under NLBPUB-tidligere/xxxxxxx/time
        # To restore a certain version copy files from the each folder up to the wanted version to a new folder

        archived_path, stored = self.utils.filesystem.storeBook(temp_epubdir, epub.identifier(), subdir=time_created)
        self.utils.report.attachment(None, archived_path, "DEBUG")
        if changes_made:
            if new_epub:
                self.utils.report.info("Endringer oppdaget for: " + epub.identifier() + ", ny epub ble kopiert til NLBpub tidligere versjoner.")
                self.utils.report.title = self.title + ": " + epub.identifier() + " 👍😄" + epubTitle + " , ny epub ble kopiert"
            else:
                self.utils.report.info("Endringer oppdaget for: " + epub.identifier() + ", endrede filer ble kopiert til NLBpub tidligere versjoner.")
                self.utils.report.title = self.title + ": " + epub.identifier() + " 👍😄" + epubTitle + " , endring registrert"
        else:
            self.utils.report.info("Ingen endringer oppdaget for " + epub.identifier())
            self.utils.report.title = self.title + ": " + epub.identifier() + " 👍😄" + epubTitle + " ,  ingen endring registrert"
            self.utils.report.should_email = False
        return True

    def del_empty_dirs(self, path, dir):
        dir_path = os.path.join(path, dir)
        if len(os.listdir(dir_path)) == 0:
            try:
                os.rmdir(dir_path)
            except Exception:
                pass
            return
        subdirs = next(walk(dir_path))[1]
        if subdirs:
            for subdir in subdirs:
                self.del_empty_dirs(dir_path, subdir)
            if len(os.listdir(dir_path)) == 0:
                try:
                    os.rmdir(dir_path)
                except Exception:
                    pass

    def append_write(self, path):
        if os.path.exists(path):
            return 'a'  # append if already exists
        else:
            return 'w'  # make a new file if not

    def short_path_by_one(self, path):
        file_loc = path.split('/')
        short_path = ""
        for sub in file_loc:
            if sub != file_loc[0]:
                short_path = os.path.join(short_path, sub)
        short_path = short_path.strip("/")
        return short_path


if __name__ == "__main__":
    NlbpubPrevious().run()
