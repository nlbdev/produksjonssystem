import os
import logging

from pathlib import Path
from flask import jsonify, request

import core.server

from core.config import Config
from core.pipeline import Pipeline
from core.directory import Directory
from core.utils.metadata import Metadata
from core.utils.filesystem import Filesystem


@core.server.route(core.server.root_path + '/directories/', require_auth=None)
def directories():
    core.server.expected_args(request, ["structure"])

    structure = request.args.get('structure', 'simple')

    return getDirectories(structure)


def getDirectories(structure):
    if structure == "ranked":
        return jsonify(Directory.dirs_ranked)

    elif structure == "resolved":
        dirs = {}

        buffered_network_paths = Config.get("buffered_network_paths", {})
        buffered_network_hosts = Config.get("buffered_network_hosts", {})

        for dir in Directory.dirs_flat:
            if isinstance(dir, str) and dir not in buffered_network_paths:
                smb, file, unc = Filesystem.networkpath(Directory.dirs_flat[dir])
                host = Filesystem.get_host_from_url(smb)
                buffered_network_paths[dir] = smb
                Config.set("buffered_network_paths." + dir, smb)
                buffered_network_hosts[dir] = host
                Config.set("buffered_network_hosts." + dir, host)
            dirs[dir] = buffered_network_paths[dir]

        return jsonify(dirs)

    else:
        return jsonify(Directory.dirs_flat)


@core.server.route(core.server.root_path + '/directories/<directory_id>/', require_auth=None)
def directory(directory_id):
    core.server.expected_args(request, [])

    return getDirectory(directory_id)


def getDirectory(directory_id):
    path = os.path.normpath(Directory.dirs_flat[directory_id]) if directory_id in Directory.dirs_flat else None
    if path:
        result = {
            "path": Directory.dirs_flat.get(directory_id, None),
            "input_pipelines": [],
            "output_pipelines": []
        }
        for pipeline in Pipeline.pipelines:
            if pipeline.dir_out and os.path.normpath(pipeline.dir_out) == path:
                result["input_pipelines"].append(pipeline.uid)
            if pipeline.dir_in and os.path.normpath(pipeline.dir_in) == path:
                result["output_pipelines"].append(pipeline.uid)
        return jsonify(result)
    else:
        return None, 404


@core.server.route(core.server.root_path + '/directories/<directory_id>/editions/', require_auth=None)
def directory_editions(directory_id):
    core.server.expected_args(request, [])

    return getDirectoryEditions(directory_id)


def getDirectoryEditions(directory_id):
    path = Directory.dirs_flat.get(directory_id, None)
    if not path:
        return None, 404

    elif path not in Directory.dirs:
        return None, 404

    else:
        names = list(Directory.dirs[path]._md5.keys())
        return jsonify([Path(name).stem for name in names]), 200


@core.server.route(core.server.root_path + '/directories/<directory_id>/editions/<edition_id>/', require_auth=None, methods=["GET", "HEAD"])
def directory_edition(directory_id, edition_id):
    core.server.expected_args(request, ["force_update"])

    force_update = request.args.get("force_update", "false").lower() == "true"

    return getDirectoryEdition(directory_id, edition_id, force_update, request.method)


def getDirectoryEdition(directory_id, edition_id, force_update, method):
    path = os.path.normpath(Directory.dirs_flat[directory_id]) if directory_id in Directory.dirs_flat else None

    if not path:
        return "", 404

    book_path = None
    if path in Directory.dirs:
        names = list(Directory.dirs[path]._md5.keys())
        for name in names:
            if Path(name).stem == edition_id:
                book_path = os.path.join(path, name)
                break

    if not book_path:
        return "", 404

    if method == "HEAD":
        return "", 200
    else:
        return jsonify(Metadata.get_metadata_from_book(logging,
                                                       book_path,
                                                       force_update=force_update)), 200


@core.server.route(core.server.root_path + '/directories/<directory_id>/editions/<edition_id>/trigger/', require_auth=None, methods=["GET", "PUT", "POST"])
def directory_edition_trigger(directory_id, edition_id):
    core.server.expected_args(request, [])

    return triggerDirectoryEdition(directory_id, edition_id)


def triggerDirectoryEdition(directory_id, edition_id):
    path = os.path.normpath(Directory.dirs_flat[directory_id]) if directory_id in Directory.dirs_flat else None

    if not path:
        return None, 404

    file_stems = [Path(file).stem for file in Filesystem.list_book_dir(path)]
    if edition_id not in file_stems:
        return None, 404

    result = []
    for pipeline in Pipeline.pipelines:
        if pipeline.dir_in and os.path.normpath(pipeline.dir_in) == path:
            pipeline.trigger(edition_id, auto=False)
            result.append(pipeline.uid)

    return jsonify(result), 200
