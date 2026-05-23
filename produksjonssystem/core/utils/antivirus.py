#!/bin/python3

import logging
import os
from pprint import pformat

import requests

antivirus_url = None
antivirus_enabled = True

def scan_file(file_path, report=logging):
    global antivirus_url, antivirus_enabled
    if antivirus_url is None:
        antivirus_url = os.getenv("ANTIVIRUS_URL")
        antivirus_enabled = os.getenv("ANTIVIRUS_ENABLED", "true").lower() == "true"
    if not antivirus_enabled:
        report.warning("Antivirus is disabled")
        return True
    report.info(f"Scanning file {file_path} for viruses")
    files = {'FILES': open(file_path, 'rb')}
    response = requests.post(antivirus_url, files=files)
    report.debug(f"HTTP {response.status_code}")
    body = None
    success = False
    if response.ok:
        body = response.json()
        report.debug(pformat(body))
        is_infected = True in [result["is_infected"] for result in body["data"]["result"]]
        if is_infected:
            report.error("A virus was found! Please contact the system administrator immediately!")
        elif not body["success"]:
            report.error("Antivirus check failed, but no files were reported as infected")
        else:
            report.info("No virus was found")
            success = True
    else:
        report.error("Could not scan for viruses")
        report.error(response.text)
    return success
