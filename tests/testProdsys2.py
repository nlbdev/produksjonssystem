#!/usr/bin/env python
import os
from shutil import copyfile
from shutil import rmtree
import time
import sys

#This script tests if epub files goes through produksjonssystem successfully
try:(rmtree('/tmp/book-archive/distribusjonsformater/DTBook/561195'))
except: pass
try:(rmtree('/tmp/book-archive/distribusjonsformater/DTBook-til-talesyntese/561195'))
except: pass
try:(os.remove('/tmp/book-archive/distribusjonsformater/EPUB-til-innlesing/409795.epub'))
except: pass
try:(rmtree('/tmp/book-archive/distribusjonsformater/HTML/561195'))
except: pass
try:(rmtree('/tmp/book-archive/distribusjonsformater/PEF/fullskrift/118395'))
except: pass

#copyfile ('/home/espso/Downloads/epub-test/561195.epub','/tmp/book-archive/innkommende/561195.epub')

file_path = os.path.join(os.path.dirname(__file__),"561195.epub")
copyfile (file_path,'/tmp/book-archive/innkommende/561195.epub')

success = 1;
t=350;

print("Starting test of NLB production system. Verifyes distribution formats for 561195.epub in {0} seconds".format(t))

time.sleep(t)
#Check if folder is  empty
if  os.path.exists('/tmp/book-archive/distribusjonsformater/DTBook/561195'):print("DTBook is verified")
else:
    print("DTBook does not exist")
    success=0

if  os.path.exists('/tmp/book-archive/distribusjonsformater/DTBook-til-talesyntese/561195'):print("DTBook til talesyntese  is verified")
else:
    print("DTBook til talesyntese does not exist")
    success=0

if  os.path.exists('/tmp/book-archive/distribusjonsformater/EPUB-til-innlesing/409795.epub'):print("Epub til innlesing  is verified")
else:
    print("Epub til innlesing does not exist")
    success=0

if  os.path.exists('/tmp/book-archive/distribusjonsformater/HTML/561195'):print("HTML  is verified")
else:
    print("HTML does not exist")
    success=0

if  os.path.exists('/tmp/book-archive/distribusjonsformater/PEF/fullskrift/118395'):print("PEF fullskrift  is verified")
else:
    print("PEF fullskrift does not exist")
    success=0

if (success):
    print("The test was completed in less than {0} seconds".format(t))
    sys.exit(0)
else :
    print ("The test was not completed in {0} seconds".format(t))
    sys.exit(1)
