import os

import logging
from datetime import datetime, timezone
from dateutil.relativedelta import relativedelta
from flask import Response, jsonify, request, send_from_directory

import core.server

from core.config import Config
from core.pipeline import Pipeline


@core.server.route(core.server.root_path + '/editions/<edition_id>/logs/', require_auth=None)
def logs(edition_id):
    core.server.expected_args(request, [])

    reports, status = getReports(edition_id)

    return jsonify(reports), status


@core.server.route(core.server.root_path + '/editions/<edition_id>/reports/', require_auth=None)
def reports(edition_id):
    return logs(edition_id)  # return the same list for HTML reports and plain text logs


@core.server.route(core.server.root_path + '/editions/<edition_id>/logs/<job_id>', require_auth=None)
def log(edition_id, job_id):
    core.server.expected_args(request, [])

    return getLog(edition_id, job_id)


@core.server.route(core.server.root_path + '/editions/<edition_id>/reports/<job_id>', require_auth=None)
def report(edition_id, job_id):
    core.server.expected_args(request, [])

    return getReport(edition_id, job_id)


def getReports(edition_id):
    reports_dir = Config.get("reports_dir")

    if not reports_dir:
        return "reports_dir was not found", 500

    result = []
    current_month = datetime.now(timezone.utc)

    logging.debug(f"Finding reports for last 3 months for the edition {edition_id}…")
    for i in range(0, 3):
        month = (current_month - relativedelta(months=i)).strftime("%Y-%m")

        path_reports = os.path.join(reports_dir, "logs", month, edition_id)
        if not os.path.exists(path_reports):
            continue
        dirs = os.listdir(path_reports)
        for dir in dirs:
            dir_split = dir.split("-")
            pipeline_id = "-".join(dir_split[5:])
            pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == pipeline_id]
            pipeline = pipeline[0] if pipeline else None
            if pipeline is None:
                continue
            result.append({
                "edition_id": edition_id,
                "pipeline_id": pipeline_id,
                "job_id": dir,
                "title": pipeline.title,
                "labels": pipeline.labels,
                "format": pipeline.publication_format
                })

    if not result:
        return "No report for edition: " + edition_id, 404

    return result, 200


def getLog(edition_id, job_id):
    path_report, status = get_report_path(edition_id, job_id, "log.txt")
    if not status == 200:
        return path_report, status

    reports_dir = Config.get("reports_dir")
    path_report_relative = os.path.relpath(path_report, reports_dir)
    return send_from_directory(reports_dir, path_report_relative)


def getReport(edition_id, job_id):
    path_report, status = get_report_path(edition_id, job_id, "email.html")
    if not status == 200:
        return path_report, status

    reports_dir = Config.get("reports_dir")
    path_report_relative = os.path.relpath(path_report, reports_dir)
    return send_from_directory(reports_dir, path_report_relative)


def get_report_path(edition_id, job_id, file):
    reports_dir = Config.get("reports_dir")

    if not reports_dir:
        return "reports_dir was not found", 500    # Return last report

    path_report = None

    if job_id == "last":
        # Return last report
        current_month = datetime.now(timezone.utc)
        path_report = None
        path_report_mtime = None
        for i in range(0, 3):
            month = (current_month - relativedelta(months=i)).strftime("%Y-%m")
            path_reports = os.path.join(reports_dir, "logs", month, edition_id)
            for dir in os.listdir(path_reports):
                this_path = os.path.join(path_reports, dir)
                mtime = os.path.getmtime(this_path)
                if path_report_mtime is None or mtime > path_report_mtime:
                    path_report = this_path
                    path_report_mtime = mtime
            if path_report is not None:
                break
        if path_report is None:
            return f"No report was found for the edition {edition_id}", 404

    else:
        # Return specific report
        current_month = datetime.now(timezone.utc)
        for i in range(0, 3):
            month = (current_month - relativedelta(months=i)).strftime("%Y-%m")
            path_report = os.path.join(reports_dir, "logs", month, edition_id, job_id)
            if os.path.isdir(path_report):
                break  # found
            else:
                path_report = None  # not found, set to None
        if path_report is None:
            return f"The report {job_id} for the edition {edition_id} was not found", 404

    path_report = os.path.join(path_report, file)
    if job_id is None:
        job_id = os.path.basename(path_report)
    if not os.path.isfile(path_report):
        return f"The report {job_id} for the edition {edition_id} does not have a file named {file}", 404

    return path_report, 200
