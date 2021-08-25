import os

from flask import jsonify, request

import core.server

from core.endpoints.directories import getDirectoryEditions, getDirectoryEdition
from core.pipeline import Pipeline
from core.directory import Directory


@core.server.route(core.server.root_path + '/steps/', require_auth=None)
def steps():
    core.server.expected_args(request, [])

    return getSteps()


@core.server.route(core.server.root_path + '/pipelines/', require_auth=None)
def deprecated_pipelines():
    return steps()


def getSteps():
    result = {}
    for pipeline in Pipeline.pipelines:
        result[pipeline.uid] = pipeline.title
    return jsonify(result), 200


@core.server.route(core.server.root_path + '/steps/<step_id>/', require_auth=None)
def step(step_id):
    core.server.expected_args(request, [])

    return getStep(step_id)


@core.server.route(core.server.root_path + '/pipelines/<step_id>/', require_auth=None)
def deprecated_pipeline(step_id):
    return step(step_id)


def getStep(step_id):
    pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == step_id]
    pipeline = pipeline[0] if pipeline else None

    if not pipeline:
        return None, 404

    dir_in_id = None
    dir_out_id = None
    for dir in Directory.dirs_flat:
        if pipeline.dir_in and os.path.normpath(pipeline.dir_in) == os.path.normpath(Directory.dirs_flat[dir]):
            dir_in_id = dir
        if pipeline.dir_out and os.path.normpath(pipeline.dir_out) == os.path.normpath(Directory.dirs_flat[dir]):
            dir_out_id = dir

    return jsonify({
        "uid": pipeline.uid,
        "title": pipeline.title,
        "dir_in": dir_in_id,
        "dir_out": dir_out_id,
        "parentdirs": pipeline.parentdirs,
        "labels": pipeline.labels,
        "publication_format": pipeline.publication_format,
        "expected_processing_time": pipeline.expected_processing_time,
        "state": pipeline.get_state(),
        "queue": pipeline.get_queue()
    }), 200


@core.server.route(core.server.root_path + '/steps/<step_id>/creative-works/', require_auth=None)
def step_creativeWorks(step_id):
    core.server.expected_args(request, [])

    return "TODO", 501


@core.server.route(core.server.root_path + '/pipelines/<step_id>/creative-works/', require_auth=None)
def deprecated_pipeline_creativeWorks(step_id, creative_work):
    return step_creativeWorks(step_id)


@core.server.route(core.server.root_path + '/steps/<step_id>/creative-works/<creative_work_id>/', require_auth=None)
def step_creativeWork(step_id, creative_work_id):
    core.server.expected_args(request, [])

    return "TODO", 501


@core.server.route(core.server.root_path + '/steps/<step_id>/editions/', require_auth=None)
def step_editions(step_id):
    core.server.expected_args(request, [])

    return getStepEditions(step_id)


@core.server.route(core.server.root_path + '/pipelines/<step_id>/editions/', require_auth=None)
def deprecated_pipelines_editions(step_id):
    return step_editions(step_id)


def getStepEditions(step_id):
    pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == step_id]
    pipeline = pipeline[0] if pipeline else None

    if not pipeline:
        return None, 404

    else:
        directory_id = [dir for dir in Directory.dirs_flat if os.path.normpath(Directory.dirs_flat[dir]) == os.path.normpath(pipeline.dir_out)][:1]
        directory_id = directory_id[0] if directory_id else None
        return getDirectoryEditions(directory_id)


@core.server.route(core.server.root_path + '/steps/<step_id>/editions/<edition_id>', require_auth=None)
def step_edition(step_id, edition_id):
    core.server.expected_args(request, [])

    return getStepEdition(step_id, edition_id)


@core.server.route(core.server.root_path + '/pipelines/<step_id>/editions/<edition_id>', require_auth=None)
def deprecated_pipeline_edition(step_id, edition_id):
    return getStepEdition(step_id, edition_id)


def getStepEdition(step_id, edition_id):
    pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == step_id]
    pipeline = pipeline[0] if pipeline else None

    if not pipeline:
        return None, 404

    else:
        directory_id = [dir for dir in Directory.dirs_flat if os.path.normpath(Directory.dirs_flat[dir]) == os.path.normpath(pipeline.dir_out)][:1]
        directory_id = directory_id[0] if directory_id else None
        return getDirectoryEdition(directory_id, edition_id, False, "GET")


@core.server.route(core.server.root_path + '/steps/<step_id>/editions/<edition_id>/trigger', require_auth=None, methods=["GET", "PUT", "POST"])
def step_trigger(step_id, edition_id):
    core.server.expected_args(request, [])

    return triggerStepEdition(step_id, edition_id)


@core.server.route(core.server.root_path + '/pipelines/<step_id>/editions/<edition_id>/trigger', require_auth=None, methods=["GET", "PUT", "POST"])
def deprecated_pipeline_trigger(step_id, edition_id):
    return step_trigger(step_id, edition_id)


def triggerStepEdition(step_id, edition_id):
    pipeline = [pipeline for pipeline in Pipeline.pipelines if pipeline.uid == step_id]
    pipeline = pipeline[0] if pipeline else None

    if not pipeline:
        return None, 404

    else:
        pipeline.trigger(edition_id, auto=False)
        return jsonify([step_id]), 200
