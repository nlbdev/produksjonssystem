#!/usr/bin/env python

#
# Run this script from the top-level project directory as follows:
# python3 -m unittest tests.testProdsys.py
#

import os
from shutil import copyfile
from shutil import rmtree
import sys
import threading
import logging

# import produksjonssystem from relative directory
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
prodsys_path = os.path.join(project_root, "produksjonssystem")
sys.path.insert(0, prodsys_path)
from produksjonssystem import run

# send log to test.log
fileHandler = logging.FileHandler("{0}/{1}.log".format(project_root, "test"))
logFormatter = logging.Formatter("%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s")
fileHandler.setFormatter(logFormatter)
logging.getLogger().addHandler(fileHandler)

# store results in test-results.txt
test_results_file = os.path.join(project_root, "test-results.txt")
if os.path.exists(test_results_file):
    os.remove(test_results_file)


def result(name, status):
    text = "{}: {}".format("SUCCESS" if status else "FAILED ", name)
    print(text)
    with open(test_results_file, 'a') as f:
        f.write(text + "\n")


# Configure system
target_path = os.path.join(prodsys_path, "target")
if os.path.exists(target_path):
    rmtree(target_path)
environment = {
    "BOOK_ARCHIVE_DIRS": " ".join([
        "master={}/prodsys-archive".format(target_path),
        "share={}/prodsys-daisy202".format(target_path),
        "distribution={}/prodsys-distribution".format(target_path)
    ]),  # space separated => spaces not allowed in paths
    "TRIGGER_DIR": "{}/prodsys-trigger".format(target_path),
    "REPORTS_DIR": "/tmp/prodsys-rapporter".format(target_path),  # always the same, so that it's easier to view the dashboard(s)
    "DEBUG": "false",
    "ORIGINAL_ISBN_CSV": os.path.join(os.path.dirname(__file__), "original-isbn.csv"),
    "CONFIG_FILE": os.path.join(os.path.dirname(__file__), "produksjonssystem.yaml"),
    "PIPELINE2_HOME": os.getenv("PIPELINE2_HOME", os.path.join(os.path.expanduser("~"), "Desktop/daisy-pipeline")),
    "STOP_AFTER_FIRST_JOB": "true"
}

book_archive_dirs = {}
for d in environment["BOOK_ARCHIVE_DIRS"].split(" "):
    assert "=" in d
    book_archive_dirs[d.split("=")[0]] = d.split("=")[1]

# print statements only goes to stdout, not to log file
print("")
print("Dashboard: file://" + os.path.join(environment["REPORTS_DIR"], "dashboard.html"))
for d in book_archive_dirs:
    print("Book archive \"{}\": file://{}".format(d, book_archive_dirs[d]))
print("")

BookID = "558237"
newBookID = "356837"
epubInnL_ID = "406837"

distPath = os.path.join(book_archive_dirs["master"], 'distribusjonsformater')
DTBook_path = os.path.join(distPath, 'DTBook', BookID)
epubInnL_path = os.path.join(distPath, 'EPUB-til-innlesing', epubInnL_ID+'.epub')
DTBookToTts_path = os.path.join(distPath, 'DTBook-til-talesyntese', BookID)
HTML_path = os.path.join(distPath, 'HTML', newBookID)
PEF_path = os.path.join(distPath, 'PEF/fullskrift', BookID)
DOCX_path = os.path.join(distPath, 'DOCX', newBookID)

threading.current_thread().setName("test thread")
prodsys = run.Produksjonssystem(environment=environment)
prodsys_thread = threading.Thread(target=prodsys.run, name="produksjonssystem")
prodsys_thread.setDaemon(True)
prodsys_thread.start()
if not prodsys.wait_until_running():
    logging.error("Timed out when starting system")
    sys.exit(1)

file_path = os.path.join(os.path.dirname(__file__), BookID + ".epub")
copyfile(file_path, os.path.join(book_archive_dirs["master"], 'innkommende', BookID + ".epub"))

success = 1
t = 500

logging.info("Starting test of NLB production system. Verifies distribution formats for " + BookID + ".epub in {0} seconds \n".format(t))

prodsys_thread.join(timeout=10)
if prodsys_thread.is_alive():
    logging.error("The tests timed out ({} seconds)".format(t))

if os.path.exists(DTBookToTts_path):
    result("DTBook til talesyntese  is verified", True)
else:
    result("DTBook til talesyntese does not exist", False)
    success = 0

if os.path.exists(epubInnL_path):
    result("Epub til innlesing  is verified", True)
else:
    result("Epub til innlesing does not exist", False)
    success = 0

if os.path.exists(HTML_path):
    result("HTML  is verified", True)
else:
    result("HTML does not exist", False)
    success = 0

if os.path.exists(DOCX_path):
    result("DOCX  is verified", True)
else:
    result("DOCX does not exist", False)
    success = 0

if os.path.exists(PEF_path):
    result("PEF fullskrift  is verified", True)
else:
    result("PEF fullskrift does not exist", False)
    success = 0

if (success):
    logging.info("Tests succeeded")
    sys.exit(0)
else:
    logging.error("Tests failed")
    sys.exit(1)
