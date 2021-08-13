import os

from datetime import datetime, timezone
from dateutil.relativedelta import relativedelta
from flask import Response, jsonify, request

import core.server

from core.config import Config
from core.pipeline import Pipeline


@core.server.route(core.server.root_path + '/editions/<edition_id>/reports/', require_auth=None)
def reports(edition_id):
    core.server.expected_args(request, [])

    return getReports(edition_id)


def getReports(edition_id):
    path = Config.get("reports_dir")

    if not path:
        return None, 404

    result = []
    current_month = datetime.now(timezone.utc)

    # Finding reports for last 3 months
    for i in range(0, 3):
        month = (current_month - relativedelta(months=i)).strftime("%Y-%m")

        path_reports = os.path.join(path, "logs", month, edition_id)
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
    if result == []:
        return jsonify("No results found for edition: " + edition_id)
    return jsonify(result)


@core.server.route(core.server.root_path + '/editions/<edition_id>/reports/<job_id>', require_auth=None)
def report(edition_id, job_id):
    core.server.expected_args(request, [])

    return getReport(edition_id, job_id)


def getReport(edition_id, job_id):
    path = Config.get("reports_dir")

    if not path:
        return Response(None, status=404)

    # Return last report
    if not job_id[0].isnumeric():
        month = datetime.now(timezone.utc).strftime("%Y-%m")
        report_path = os.path.join(path, "logs", month, edition_id)
        files_edition = os.listdir(report_path)
        report = None
        for file in files_edition:
            if job_id in file:
                if report is None:
                    report = os.path.join(report_path, file)

                elif os.path.getmtime(os.path.join(report_path, file)) > os.path.getmtime(report):
                    report = os.path.join(report_path, file)
        if report is None:
            return Response("No report for edition: " + edition_id, status=404)
        path_report = os.path.join(report, "log.txt")

    # Return specific report
    else:
        id_split = job_id.split("-")
        month = id_split[0] + "-" + id_split[1]
        path_report = os.path.join(path, "logs", month, edition_id, job_id, "log.txt")
        if not os.path.exists(path_report):
            return Response("No report for edition: " + edition_id, status=404)
        result = []
    with open(path_report, 'r') as report:
        result = report.read().splitlines()
    return jsonify(result)
