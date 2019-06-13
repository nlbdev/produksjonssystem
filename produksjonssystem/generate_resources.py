#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import datetime
import os
import logging
import subprocess
import sys
import tempfile
import time
import threading
import traceback
import urllib.request
import xml.etree.ElementTree as ET

from core.pipeline import Pipeline
from lxml import etree as ElementTree

if sys.version_info[0] != 3 or sys.version_info[1] < 5:
    print("# This script requires Python version 3.5+")
    sys.exit(1)


class GenerateResources(Pipeline):
    uid = "generate-resources"
    title = "Generere ressurser på DODP"
    labels = ["Lydbok"]
    publication_format = "daisy202"
    expected_processing_time = 50
    dp1_home = ""
    validator_script = ""

    def start(self, *args, **kwargs):
        super().start(*args, **kwargs)
        self._triggerResourceThread = threading.Thread(target=self._trigger_resource_thread, name="Resource thread")
        self._triggerResourceThread.setDaemon(True)
        self._triggerResourceThread.start()

        logging.info("Pipeline \"" + str(self.title) + "\" started watching for newsletters")

    def stop(self, *args, **kwargs):
        super().stop(*args, **kwargs)

        if self._triggerResourceThread and self._triggerResourceThread != threading.current_thread():
            self._triggerResourceThread.join()

        logging.info("Pipeline \"" + str(self.title) + "\" stopped")

    def _trigger_resource_thread(self):
        """
        Trigger books in folder but not in DOD database
        """
        last_check = 0
        while self._dirsAvailable and self._shouldRun:
            time.sleep(5)
            max_update_interval = 60 * 60 * 24

            if time.time() - last_check < max_update_interval:
                continue

            last_check = time.time()

            configs = ['url_database_list', 'url_regenerate_resources', 'test_user', 'url_issue_content']
            no_config = False
            for key in configs:
                if key in self.config:
                    continue
                else:
                    logging.info("Finner ikke nødvendig config: " + key)
                    no_config = True

            if no_config is True:
                logging.info("Finner ikke nødvendig config...")
                continue
            list_books_dod = []
            dod_data = str(urllib.request.urlopen(self.config['url_database_list'][0]).read(), "utf-8")
            for book in dod_data.split(","):
                if book.isdigit():
                    list_books_dod.append(book)
            if len(list_books_dod) < 2:
                continue
            for folder in Pipeline.list_book_dir(self.dir_in):
                if folder.isdigit():
                    if folder not in list_books_dod:
                        logging.info("Trigger ressursgenerering for " + folder)
                        self.trigger(folder)

    def on_book_deleted(self):
        self.utils.report.should_email = False
        self.utils.report.should_message_slack = False
        self.utils.report.info("Slettet lydbok i mappa: " + self.book['name'])
        self.utils.report.title = "Lydbok slettet: " + self.book['name']
        return True

    def on_book_modified(self):
        self.utils.report.info("Endret lydbok i mappa: "+self.book['name'])
        if (self.get_main_event(self.book) == 'autotriggered'):
            return self.on_book()
        else:
            self.utils.report.should_email = False
            self.utils.report.should_message_slack = False
            return True

    def on_book_created(self):
        self.utils.report.should_email = False
        self.utils.report.should_message_slack = False
        self.utils.report.info("Ny lydbok i mappa: "+self.book['name'])

    def on_book(self):
        """
        Validates books using pipeline1 validator then if valid tries to generate resources on DOD
        """
        if self.dp1_home is "" or self.validator_script is "":
            if self.init_environment():
                self.utils.report.info("Pipeline1 ble funnet")
            else:
                self.utils.report.error("Pipeline1 ble ikke funnet. Avbryter..")
                return False

        self.utils.report.attachment(None, os.path.join(self.book['source']), "DEBUG")
        temp_absdir_obj = tempfile.TemporaryDirectory()
        temp_absdir = temp_absdir_obj.name
        self.utils.filesystem.copy(self.book["source"], temp_absdir)

        url_generate_resources = ""
        url_generate_resources = self.config["url_regenerate_resources"][0]
        url_issue_content = self.config["url_issue_content"][0]

        if url_generate_resources is "":
            self.utils.report.info("No url set to regenerate_resources")
            return False
        user = self.config['test_user'][0]
        audio_identifier = ""
        audio_title = ""

        if not os.path.isfile(os.path.join(temp_absdir, "ncc.html")):
            self.utils.report.title = self.title + ": " + self.book["name"] + " feilet 😭👎. Er dette en daisy 2.02 lydbok med en ncc.html fil?"
            return False
        try:
            nccdoc = ElementTree.parse(os.path.join(temp_absdir, "ncc.html")).getroot()
            audio_title = " (" + nccdoc.xpath("string(//*[@name='dc:title']/@content)") + ") "
            audio_identifier = nccdoc.xpath("string(//*[@name='dc:identifier']/@content)")
        except Exception:
            self.utils.report.info("Klarte ikke lese ncc fila. Sjekk loggen for detaljer.")
            self.utils.report.debug(traceback.format_exc(), preformatted=True)
            audio_identifier = self.book['name']
        status = self.validate_book(os.path.join(temp_absdir, "ncc.html"))
        if status == "ERROR" or status is False:
            self.utils.report.error("Pipeline validator: Boka er ikke valid. Se rapport.")
            return False
        self.utils.report.info("Pipeline validator: Boka er valid")
        self.utils.report.info("Låner ut bok {} for {}".format(audio_identifier, user))
        urllib.request.urlopen(os.path.join(url_issue_content, user, audio_identifier))

        for i in range(3):
            self.utils.report.info("Prøver å generere ressurser for: {}".format(audio_identifier))
            if self.generate_resources(url_generate_resources, user, audio_identifier):
                self.utils.report.success("Systemet har generert ressurser på DODP")
                self.utils.report.title = "{}: {} er klar for utlån 👍😄 {}".format(self.title, audio_identifier, audio_title)
                return True
            time.sleep(4)

        self.utils.report.error("{}: {} systemet feilet med å generere ressurser, sjekk om boka er valid.".format(self.title, audio_identifier))

    def generate_resources(self, url, user, book):
        try:
            issued_data = urllib.request.urlopen(os.path.join(url, book, user))
            issued_xml = ET.parse(issued_data)
            root = issued_xml.getroot()
            if ("Failed") in root.text:
                return False
            else:
                return True
        except Exception:
            self.utils.report.error("Server feil. Klarte ikke parse xml.")
            return False

    def validate_book(self, path_ncc):

        if self.dp1_home is "":
            self.utils.report.error("Pipeline1 ble ikke funnet. Avslutter..")
            return False
        input = "--input=" + path_ncc
        report = os.path.join(self.utils.report.reportDir(), "report.xml")
        report_command = "--validatorOutputXMLReport=" + report

        try:
            self.utils.report.info("Kjører Daisy 2.02 validator i Pipeline1...")
            process = self.utils.filesystem.run([self.dp1_home, self.validator_script, input, report_command], stdout_level='DEBUG')
            if process.returncode != 0:
                self.utils.report.debug(traceback.format_stack())

            status = "DEBUG"
            error_message = []
            for line in self.utils.report._messages["message"]:
                if "[ERROR" in line["text"]:
                    status = "ERROR"
                    error_message.append(line["text"])
            if status == "ERROR":
                for line_error in error_message:
                    self.utils.report.error(line_error)
            self.utils.report.attachment(None, os.path.join(self.utils.report.reportDir(), "report.xml"), status)
            self.utils.report.info("Daisy 2.02 validator ble ferdig.")
            return status

        except subprocess.TimeoutExpired:
            self.utils.report.error("Det tok for lang tid å kjøre Daisy 2.02 validator og den ble derfor stoppet.")
            self.utils.report.title = self.title
            return False

    def init_environment(self):
        if os.environ.get("PIPELINE1_HOME"):
            self.dp1_home = os.environ.get("PIPELINE1_HOME")
        else:
            self.dp1_home = "/opt/pipeline1/pipeline.sh"
        self.validator_script = os.path.join(os.path.dirname(self.dp1_home),
                                             "scripts", "verify", "Daisy202DTBValidator.taskScript")
        if os.path.isfile(self.validator_script):
            return True
        else:
            return False


if __name__ == "__main__":
    GenerateResources().run()
