#!/usr/bin/env python
import os
from shutil import copyfile
from shutil import rmtree
import time

#This script tests if epub files goes through produksjonssystem successfully

try:(rmtree('/tmp/book-archive/distribusjonsformater/DTBook/558285172017'))
except: pass
try:(rmtree('/tmp/book-archive/distribusjonsformater/DTBook-til-talesyntese/558285172017'))
except: pass
#try:(os.remove('/tmp/book-archive/distribusjonsformater/EPUB-til-innlesing/624594092018.epub'))
#except: pass
try:(rmtree('/tmp/book-archive/distribusjonsformater/HTML/558285172017'))
except: pass
try:(rmtree('/tmp/book-archive/distribusjonsformater/PEF/fullskrift/558285172017'))
except: pass

#Copy test epub to incoming
copyfile ('/home/espso/Downloads/epub-test/558285172017.epub','/tmp/book-archive/innkommende/558285172017.epub')

success = 1;
t=500;

print("Starting test of NLB production system. Verifyes distribution formats in {0} seconds".format(t))

time.sleep(t)
#Verifies distribution formats
if  os.path.exists('/tmp/book-archive/distribusjonsformater/DTBook/558285172017'):print("DTBook is verified")
else:
    print("DTBook does not exist")
    success=0

if  os.path.exists('/tmp/book-archive/distribusjonsformater/DTBook-til-talesyntese/558285172017'):print("DTBook til talesyntese is verified")
else:
    print("DTBook til talesyntese does not exist")
    success=0

#if  os.path.exists('/tmp/book-archive/distribusjonsformater/EPUB-til-innlesing/624594092018.epub'):print("Epub til innlesing exists")
#else:
#    print("Epub til innlesing does  exist")
#    success=0

if  os.path.exists('/tmp/book-archive/distribusjonsformater/HTML/558285172017'):print("HTML  is verified")
else:
    print("HTML does not exist")
    success=0

if  os.path.exists('/tmp/book-archive/distribusjonsformater/PEF/fullskrift/558285172017'):print("PEF fullskrift  is verified")
else:
    print("PEF fullskrift does not exist")
    success=0

if (success):print("The test was completed in less than {0} seconds".format(t))
else : print ("The test was not completed in {0} seconds".format(t))