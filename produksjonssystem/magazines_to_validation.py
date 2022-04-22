#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import logging
import os
import sys
import threading
import time

from core.pipeline import Pipeline

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class MagazinesToValidation(Pipeline):
    uid = "magazines-to-validation"
    title = "Nyhetsbrev punkt"
    labels = ["Punktskrift"]
    uid = "magazines-to-validation"
    title = "Tidsskrift til validering"
    labels = ["Lydbok"]
    publication_format = "DAISY 2.02"
    expected_processing_time = 5

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self._triggerMagazinesThread = threading.Thread(target=self._trigger_magazines_thread, name="Magazines thread")
        self._triggerMagazinesThread.setDaemon(True)
        self._triggerMagazinesThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching for magazines")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        if self._triggerMagazinesThread and self._triggerMagazinesThread != threading.current_thread():
            self._triggerMagazinesThread.join()

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def _trigger_magazines_thread(self):
        last_check = 0

        self.watchdog_bark()
        while self.shouldRun:
            time.sleep(5)
            self.watchdog_bark()

            if not self.dirsAvailable():
                continue

            max_update_interval = 60
            weekday = datetime.datetime.today().strftime('%A')
            clock = datetime.datetime.today().strftime('%H%M')
            if time.time() - last_check < max_update_interval:
                continue
            if not ((weekday == "Monday" or weekday == "Wednesday" or weekday == "Friday") and clock == "1000"):
                continue

            last_check = time.time()
            checked_magazines = []
            magazines = os.listdir(self.dir_in)
            magazines.sort
            for magazine in magazines:
                identifier = magazine[:6]
                if len(magazine) != 12 or identifier in checked_magazines:
                    continue
                logging.info(f"Examining {identifier}...")
                magazines_with_identifier = []
                for mag in magazines:
                    if mag.startswith(identifier):
                        magazines_with_identifier.append(mag)
                checked_magazines.append(identifier)
                logging.info(magazines_with_identifier)
                earliest_magazine = magazines_with_identifier[0]
                earliest_magazine_year = earliest_magazine[8:12]
                earliest_magazine_number = earliest_magazine[6:8]
                for magazine_with_identifier in magazines_with_identifier:
                    edition_number = magazine_with_identifier[6:8]
                    year = magazine_with_identifier[8:12]
                    if year < earliest_magazine_year or year == earliest_magazine_year and edition_number < earliest_magazine_number:
                        print(magazine_with_identifier)
                        earliest_magazine = magazine_with_identifier
                        earliest_magazine_number = edition_number
                        earliest_magazine_year = year
                logging.info(f"{earliest_magazine} vil bli overført til validering")
                self.trigger(earliest_magazine, auto=True)


    def on_book_deleted(self):
        self.utils.report.should_email = False
        return True

    def on_book_modified(self):
        return self.on_book()

    def on_book_created(self):
        self.utils.report.should_email = False
        return True

    def on_book(self):
        print(self.get_main_event(self.book))
        if self.get_main_event(self.book) != "autotriggered":
            return True
        archived_path, stored = self.utils.filesystem.storeBook(self.book["source"], self.book["name"])
        self.utils.report.attachment(None, archived_path, "DEBUG")
        self.utils.report.info(self.book["name"] + " er overført til validering")
        self.utils.report.title = self.title + ": " + self.book["name"] + " er overført til validering 👍😄"
        self.utils.filesystem.deleteSource()
        self.utils.report.info("Sletter utgave i inn mappen")
        return True


if __name__ == "__main__":
    MagazinesToValidation().run()
