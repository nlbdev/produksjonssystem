import os

import logging
from datetime import datetime, timezone
from dateutil.relativedelta import relativedelta
from flask import Response, jsonify, request, send_from_directory

import core.server

from core.config import Config
from core.pipeline import Pipeline
from core.utils.metadata import Metadata


# list of all jobs for this edition, optionally filtered by step and/or line, and by default including other editions associated with the same creative work
@core.server.route(core.server.root_path + '/editions/<edition_id>/jobs', require_auth=None)
def jobs(edition_id):
    core.server.expected_args(request, ["step-id", "line-id", "include-other-identifiers"])

    step_id = core.server.get_arg(request, "step-id", default="", type=str)
    line_id = core.server.get_arg(request, "line-id", default="", type=str)
    include_other_identifiers = core.server.get_arg(request, "include-other-identifiers", default="true", type=str)

    step_id = step_id if step_id else None
    line_id = line_id if line_id else None
    include_other_identifiers = include_other_identifiers == "true"

    jobs, status = getJobs(edition_id, step_id=step_id, line_id=line_id, include_other_identifiers=include_other_identifiers)

    if len(jobs) == 0:
        return (
            f"No jobs found for {edition_id} with parameters: "
            + f"step-id={step_id}, line-id={line_id}, include-other-identifiers={include_other_identifiers}",
            404
        )

    return jsonify(jobs), status


# get a specific job for this edition
@core.server.route(core.server.root_path + '/editions/<edition_id>/jobs/<job_id>', require_auth=None)
def job(edition_id, job_id):
    core.server.expected_args(request, ["step-id", "line-id", "include-other-identifiers"])

    step_id = core.server.get_arg(request, "step-id", default="", type=str)
    line_id = core.server.get_arg(request, "line-id", default="", type=str)
    include_other_identifiers = core.server.get_arg(request, "include-other-identifiers", default="true", type=str)

    step_id = step_id if step_id else None
    line_id = line_id if line_id else None
    include_other_identifiers = include_other_identifiers == "true"

    # note that step_id and line_id is only relevant here if job_id is "latest"
    job, status = getJobs(edition_id, job_id=job_id, step_id=step_id, line_id=line_id, include_other_identifiers=include_other_identifiers)
    if status != 200:
        return job, status

    return jsonify(job), status


# list all files in the job directory
@core.server.route(core.server.root_path + '/editions/<edition_id>/jobs/<job_id>/files', require_auth=None)
def job_files(edition_id, job_id):
    core.server.expected_args(request, ["step-id", "line-id", "include-other-identifiers"])

    step_id = core.server.get_arg(request, "step-id", default="", type=str)
    line_id = core.server.get_arg(request, "line-id", default="", type=str)
    include_other_identifiers = core.server.get_arg(request, "include-other-identifiers", default="true", type=str)

    step_id = step_id if step_id else None
    line_id = line_id if line_id else None
    include_other_identifiers = include_other_identifiers == "true"

    # note that step_id and line_id is only relevant here if job_id is "latest"
    path_report, status = get_report_path(edition_id, job_id, step_id=step_id, line_id=line_id, include_other_identifiers=include_other_identifiers)
    if not status == 200:
        return path_report, status

    paths = []
    for root, dirs, files in os.walk(path_report):
        for dir in dirs:
            fullpath = os.path.join(root, dir)
            relpath = os.path.relpath(fullpath, path_report)
            paths.append(relpath + "/")
        for file in files:
            fullpath = os.path.join(root, file)
            relpath = os.path.relpath(fullpath, path_report)
            paths.append(relpath)
    paths = list(sorted(paths))

    return jsonify(paths), 200


# get a file from the job directory
@core.server.route(core.server.root_path + '/editions/<edition_id>/jobs/<job_id>/files/<path:path>', require_auth=None)
def job_file(edition_id, job_id, path):
    core.server.expected_args(request, ["step-id", "line-id", "include-other-identifiers"])

    step_id = core.server.get_arg(request, "step-id", default="", type=str)
    line_id = core.server.get_arg(request, "line-id", default="", type=str)
    include_other_identifiers = core.server.get_arg(request, "include-other-identifiers", default="true", type=str)

    step_id = step_id if step_id else None
    line_id = line_id if line_id else None
    include_other_identifiers = include_other_identifiers == "true"

    # note that step_id and line_id is only relevant here if job_id is "latest"
    path_report, status = get_report_path(edition_id, job_id, path=path, step_id=step_id, line_id=line_id, include_other_identifiers=include_other_identifiers)
    if not status == 200:
        return path_report, status

    reports_dir = Config.get("reports_dir")
    path_report_relative = os.path.relpath(path_report, reports_dir)
    return send_from_directory(reports_dir, path_report_relative)


# get the detailed log file (plain text)
@core.server.route(core.server.root_path + '/editions/<edition_id>/jobs/<job_id>/log', require_auth=None)
def log(edition_id, job_id):
    return job_file(edition_id, job_id, "log.txt")


# get the latest report (HTML)
@core.server.route(core.server.root_path + '/editions/<edition_id>/jobs/<job_id>/report', require_auth=None)
def report(edition_id, job_id):
    return job_file(edition_id, job_id, "email.html")


def getJobs(edition_id, step_id=None, line_id=None, job_id=None, include_other_identifiers=True):
    assert step_id is None or isinstance(step_id, str), f"step-id must be a string if specified. Was: {step_id} ({type(step_id)})"
    assert line_id is None or isinstance(line_id, str), f"line-id must be a string if specified. Was: {line_id} ({type(line_id)})"
    assert job_id is None or isinstance(job_id, str), f"job-id must be a string if specified. Was: {job_id} ({type(job_id)})"
    assert include_other_identifiers in [True, False], (
        f"include-other-identifiers must be a boolean. Was: {include_other_identifiers} ({type(include_other_identifiers)})"
    )

    result = []

    # if we include other identifiers, invoke getJobs multiple times and combine the results
    if include_other_identifiers:
        identifiers = Metadata.get_identifiers(edition_id, use_cache_if_possible=True)
        for identifier in identifiers:
            edition_jobs, status = getJobs(identifier,
                                           step_id=step_id,
                                           line_id=line_id,
                                           job_id=job_id,
                                           include_other_identifiers=False)
            if status not in [200, 404]:
                return edition_jobs, status
            if status == 200:
                if isinstance(edition_jobs, dict):
                    return edition_jobs, status  # we found the job we were looking for, don't look further
                result.extend(edition_jobs)
        return result, 200

    reports_dir = Config.get("reports_dir")

    if not reports_dir:
        return "reports_dir was not found", 500

    production_lines = Config.get("production-lines", [])

    current_month = datetime.now(timezone.utc)

    if job_id == "latest":
        latest_job_path, status = get_report_path(edition_id, job_id, step_id=step_id, line_id=line_id)
        if status != 200:
            return latest_job_path, status
        job_id = os.path.basename(latest_job_path)
        this_step_id = "-".join(job_id.split("-")[5:])
        step = [step for step in Pipeline.pipelines if step.uid == this_step_id]
        step = step[0] if step else None
        if not step:
            return f"Unknown step: {this_step_id}", 404
        this_line_ids = [line["id"] for line in production_lines if this_step_id in line["steps"]]
        result.append({
            "edition_id": edition_id,
            "step_id": this_step_id,
            "line_ids": this_line_ids,
            "job_id": job_id,
            "title": step.title,
            "labels": step.labels,
            "format": step.publication_format
        })

    else:
        logging.debug(f"Finding reports for latest 3 months for the edition {edition_id}…")
        for i in range(0, 3):
            month = (current_month - relativedelta(months=i)).strftime("%Y-%m")

            path_reports = os.path.join(reports_dir, "logs", month, edition_id)
            if not os.path.exists(path_reports):
                continue
            dirs = os.listdir(path_reports)
            for dir in dirs:
                if job_id is not None and dir != job_id:
                    continue  # we're looking for a specific job, skip all others
                this_step_id = "-".join(dir.split("-")[5:])
                step = [step for step in Pipeline.pipelines if step.uid == this_step_id]
                step = step[0] if step else None
                if not step:
                    logging.debug(f"Unknown step in job '{dir}': {this_step_id}")
                    continue
                this_line_ids = [line["id"] for line in production_lines if this_step_id in line["steps"]]
                if step_id is not None and step_id != this_step_id:
                    continue  # we're looking for a specific step, skip all others
                if line_id is not None and line_id not in this_line_ids:
                    continue  # we're looking for a specific line, skip all others
                result.append({
                    "edition_id": edition_id,
                    "step_id": this_step_id,
                    "line_ids": this_line_ids,
                    "job_id": dir,
                    "title": step.title,
                    "labels": step.labels,
                    "format": step.publication_format
                })

    if not result:
        return (
            f"No report for edition '{edition_id}' with parameters: "
            + f"step-id={step_id}, line-id={line_id}, job-id={job_id}, include-other-identifiers={include_other_identifiers}",
            404
        )

    if job_id is not None:
        result = result[0]

    return result, 200


def get_report_path(edition_id, job_id, step_id=None, line_id=None, path=None, include_other_identifiers=False):
    assert include_other_identifiers in [True, False], "include-other-identifiers must be a boolean"

    identifiers = [edition_id]
    if include_other_identifiers:
        identifiers = Metadata.get_identifiers(edition_id, use_cache_if_possible=True)

    reports_dir = Config.get("reports_dir")

    if not reports_dir:
        return "reports_dir was not found", 500

    production_lines = Config.get("production-lines", [])

    path_report = None

    if job_id == "latest":
        # Return latest report
        current_month = datetime.now(timezone.utc)
        path_report = None
        path_report_mtime = None
        for i in range(0, 3):
            month = (current_month - relativedelta(months=i)).strftime("%Y-%m")
            for identifier in identifiers:
                path_reports = os.path.join(reports_dir, "logs", month, identifier)
                if not os.path.isdir(path_reports):
                    continue  # no jobs for this edition in this month
                for dir in os.listdir(path_reports):
                    this_path = os.path.join(path_reports, dir)
                    this_step_id = "-".join(dir.split("-")[5:])
                    step = [step for step in Pipeline.pipelines if step.uid == this_step_id]
                    step = step[0] if step else None
                    if not step:
                        logging.debug(f"Unknown step in job '{dir}': {this_step_id}")
                        continue
                    this_line_ids = [line["id"] for line in production_lines if this_step_id in line["steps"]]
                    if step_id is not None and this_step_id != step_id:
                        continue  # we're looking for a specific step
                    if line_id is not None and line_id not in this_line_ids:
                        continue  # we're looking for a specific step
                    mtime = os.path.getmtime(this_path)
                    if path_report_mtime is None or mtime > path_report_mtime:
                        path_report = this_path
                        path_report_mtime = mtime
                if path_report is not None:
                    break
            if path_report is not None:
                break
        if path_report is None:
            return f"No report was found for the edition {'/'.join(identifiers)}", 404

    else:
        # Return specific report
        current_month = datetime.now(timezone.utc)
        for i in range(0, 3):
            month = (current_month - relativedelta(months=i)).strftime("%Y-%m")
            for identifier in identifiers:
                path_report = os.path.join(reports_dir, "logs", month, identifier, job_id)
                if os.path.isdir(path_report):
                    break  # found
                else:
                    path_report = None  # not found, set to None
            if path_report is not None:
                break  # found
        if path_report is None:
            return f"The report {job_id} for the edition {'/'.join(identifiers)} was not found", 404

    if job_id == "latest":
        job_id = os.path.basename(path_report)
    if path is not None:
        path_report = os.path.join(path_report, path)
        if not os.path.isfile(path_report):
            return f"The report {job_id} for the edition {'/'.join(identifiers)} does not have a file named {path}", 404

    return path_report, 200
