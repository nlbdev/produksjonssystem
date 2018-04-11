#!/usr/bin/env python

#
# Run this script from the top-level project directory as follows:
# python3 -m unittest tests.testProdsys.py
#

import os
from shutil import copyfile
from shutil import rmtree
import time
import sys
import threading
import tempfile

# import produksjonssystem from relative directory
prodsys_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "produksjonssystem"))
sys.path.insert(0, prodsys_path)
from produksjonssystem import run

# Configure system
environment = {
    "BOOK_ARCHIVE_DIR": tempfile.mkdtemp(prefix="prodsys-", suffix="-archive"),
    "TRIGGER_DIR": tempfile.mkdtemp(prefix="prodsys-", suffix="-triggerdir"),
    "REPORTS_DIR": "/tmp/prodsys-rapporter", # always the same, so that it's easier to view the dashboard(s)
    "DEBUG": "false",
    "ORIGINAL_ISBN_CSV": os.path.join(os.path.dirname(__file__), "original-isbn.csv"),
    "PIPELINE2_HOME": os.getenv("PIPELINE2_HOME", os.path.join(os.path.expanduser("~"), "Desktop/daisy-pipeline")),
    "STOP_AFTER_FIRST_JOB": "true"
}

print("")
print("Dashboard: file://" + os.path.join(environment["REPORTS_DIR"], "dashboard.html"))
print("Book archive: file://" + os.path.join(environment["BOOK_ARCHIVE_DIR"]))
print("")

BookID="558237"
newBookID="356837"
epubInnL_ID="406837"

distPath=os.path.join(environment["BOOK_ARCHIVE_DIR"],'distribusjonsformater')
DTBook_path=os.path.join(distPath,'DTBook',BookID)
epubInnL_path=os.path.join(distPath,'EPUB-til-innlesing',epubInnL_ID+'.epub')
DTBookToTts_path=os.path.join(distPath,'DTBook-til-talesyntese',BookID)
HTML_path=os.path.join(distPath,'HTML',newBookID)
PEF_path=os.path.join(distPath,'PEF/fullskrift',BookID)
DOCX_path=os.path.join(distPath,'DOCX',newBookID)


#This script tests if epub files goes through produksjonssystem successfully
try:(rmtree(DTBook_path))
except: pass
try:(rmtree(DTBookToTts_path))
except: pass
try:(os.remove(epubInnL_path))
except: pass
try:(rmtree(HTML_path))
except: pass
try:(rmtree(PEF_path))
except: pass
try:(rmtree(DOCX_path))
except: pass

prodsys = run.Produksjonssystem(environment=environment)
prodsys_thread = threading.Thread(target=prodsys.run)
prodsys_thread.setDaemon(True)
prodsys_thread.start()
if not prodsys.wait_until_running():
    print("Timed out when starting system")
    sys.exit(1)

file_path = os.path.join(os.path.dirname(__file__),BookID+".epub")
copyfile (file_path,os.path.join(environment["BOOK_ARCHIVE_DIR"], 'innkommende',BookID+".epub"))

success = 1;
t=500;

print("Starting test of NLB production system. Verifyes distribution formats for " +BookID+".epub in {0} seconds \n".format(t))

prodsys_thread.join(timeout=t)
if prodsys_thread.is_alive():
    print("The tests timed out")

#Check if folder is not empty
if  os.path.exists(DTBook_path):print("DTBook  is verified")
else:
    print("DTBook does not exist")
    success=0

if  os.path.exists(DTBookToTts_path):print("DTBook til talesyntese  is verified")
else:
    print("DTBook til talesyntese does not exist")
    success=0

if  os.path.exists(epubInnL_path):print("Epub til innlesing  is verified")
else:
    print("Epub til innlesing does not exist")
    success=0

if  os.path.exists(HTML_path):print("HTML  is verified")
else:
    print("HTML does not exist")
    success=0

if  os.path.exists(DOCX_path):print("DOCX  is verified")
else:
    print("DOCX does not exist")
    success=0

if  os.path.exists(PEF_path):print("PEF fullskrift  is verified")
else:
    print("PEF fullskrift does not exist")
    success=0

if (success):
    print("The test was completed in less than {0} seconds".format(t))
    sys.exit(0)
else :
    print ("\nThe test was not completed in {0} seconds".format(t))
    sys.exit(1)
