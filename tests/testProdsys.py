#!/usr/bin/env python

#
# Run this script from the top-level project directory as follows:
# python3 -m unittest tests.testProdsys.py
#

import os
import re
from shutil import copyfile
from shutil import rmtree
import sys
import threading
import logging
import time

# import produksjonssystem from relative directory
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
prodsys_path = os.path.join(project_root, "produksjonssystem")
sys.path.insert(0, prodsys_path)
from produksjonssystem import run
from core.pipeline import DummyPipeline

# make target directory
target_path = os.path.join(project_root, "target")
if os.path.exists(target_path):
    rmtree(target_path)
os.makedirs(target_path)

# send log to test.log
logfile = "{0}/{1}.log".format(target_path, "test")
if os.path.exists(logfile):
    os.remove(logfile)
fileHandler = logging.FileHandler(logfile)
logFormatter = logging.Formatter("%(asctime)s %(levelname)-8s [%(threadName)-30s] %(message)s")
fileHandler.setFormatter(logFormatter)
logging.getLogger().addHandler(fileHandler)

# store results in test-results.txt
test_results_file = os.path.join(target_path, "test-results.txt")
if os.path.exists(test_results_file):
    os.remove(test_results_file)


def result(name, status):
    text = "{}: {}".format("SUCCESS" if status else "FAILED ", name)
    print(text)
    with open(test_results_file, 'a') as f:
        f.write(text + "\n")


# Configure system
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

threading.current_thread().setName("test thread")
print("Initializing the system...")
prodsys = run.Produksjonssystem(environment=environment)
prodsys_thread = threading.Thread(target=prodsys.run, name="produksjonssystem")
prodsys_thread.setDaemon(True)
print("Starting the system...")
prodsys_thread.start()
if prodsys.wait_until_running():
    print("The system is initialized and started.")
else:
    print("Timed out when starting system")
    sys.exit(1)

identifiers = ["558237", "115437", "221437", "356837", "406837"]
file_path = os.path.join(os.path.dirname(__file__), identifiers[0] + ".epub")
copyfile(file_path, os.path.join(prodsys.dirs["incoming"], os.path.basename(file_path)))

for pipeline in prodsys.pipelines:
    if pipeline[0].uid == "create-abstracts":
        print("abstracts pipeline are not connected to the rest of the system. see: https://github.com/nlbdev/produksjonssystem/issues/99")
        pipeline[0].stop(exit=True)

expect_dirs = {}
for pipeline in prodsys.pipelines:
    if (not pipeline[0].uid in ["update-metadata", "create-abstracts"]
       and not isinstance(pipeline[0], DummyPipeline)
       and pipeline[2]):
        expect_dirs[pipeline[0].uid] = {
            "title": pipeline[0].title,
            "dir": pipeline[0].dir_out,
            "status": None
        }

success = 1
t = 500

print("Starting test of NLB production system. Verifies distribution formats for " + os.path.basename(file_path) + " in {0} seconds \n".format(t))


def check_dirs(last_run=False):
    global expect_dirs
    global identifiers

    success = True
    for uid in expect_dirs:
        expect_dir = expect_dirs[uid]["dir"]
        if expect_dirs[uid]["status"] is not None:
            success = success and expect_dirs[uid]["status"]
            continue
        for identifier in identifiers:
            if os.path.isdir(os.path.join(expect_dir, identifier)):
                expect_dirs[uid]["status"] = True

            file = os.listdir(expect_dir)
            file = re.sub(r'\.[^.]*$', '', file[0]) if file else None
            if file and file == identifier:
                expect_dirs[uid]["status"] = True

            if expect_dirs[uid]["status"] is True:
                result(expect_dirs[uid]["title"], True)
                break

            elif last_run:
                result(expect_dirs[uid]["title"], False)
                success = False
                break


start_time = int(time.time())
while prodsys_thread.is_alive() and t > 0:
    t -= 1
    prodsys_thread.join(timeout=1)
    check_dirs()
end_time = int(time.time())

success = check_dirs(last_run=True)

if prodsys_thread.is_alive():
    print("The tests timed out after {} seconds".format(t))
else:
    print("The tests finished after {} seconds".format(end_time - start_time))

if (success):
    print("Tests succeeded")
    sys.exit(0)
else:
    print("Tests failed")
    sys.exit(1)
