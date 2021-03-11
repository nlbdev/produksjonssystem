#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

from core.pipeline import Pipeline
from core.utils.metadata import Metadata

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class CheckPef(Pipeline):
    uid = "check-pef"
    title = "Kontroll av punktskrift"
    labels = ["Punktskrift", "Statped"]
    publication_format = "Braille"
    expected_processing_time = 30

    def on_book_deleted(self):
        self.utils.report.info("Slettet bok i mappa: " + self.book['name'])
        self.utils.report.title = self.title + " PEF-kilde slettet: " + self.book['name']
        self.utils.report.should_email = False
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book_created(self):
        self.utils.report.info("Ny bok i mappa: " + self.book['name'])
        return self.on_book()

    def on_book(self):
        self.utils.report.attachment(None, self.book["source"], "DEBUG")

        metadata = Metadata.get_metadata_from_book(self.utils.report, self.book["source"])
        needs_manual_approval = True
        if "nlb:needs-manual-approval" in metadata and metadata["nlb:needs-manual-approval"] == "false":
            needs_manual_approval = False

        if needs_manual_approval:
            self.utils.report.title = self.title + ": {} trenger manuell gjennomgang{}".format(
                metadata["identifier"], "" if "title" not in metadata else " (" + metadata["title"] + ")")

        else:
            self.utils.report.title = self.title + ": {} ble automatisk godkjent 👍😄{}".format(
                metadata["identifier"], "" if "title" not in metadata else " (" + metadata["title"] + ")")

            self.utils.report.info("Boken ble automatisk godkjent.")

            archived_path, stored = self.utils.filesystem.storeBook(self.book["source"], metadata["identifier"])
            self.utils.report.attachment(None, archived_path, "DEBUG")

        return True


if __name__ == "__main__":
    CheckPef().run()
