from flask import jsonify, request

import core.server
from core.config import Config


@core.server.route(core.server.root_path + '/lines/', require_auth=None)
def lines():
    core.server.expected_args(request, ["libraries"])

    libraries = core.server.get_arg(request, "limit", default="", type=str)

    return getLines(libraries)


def getLines(libraries):
    assert isinstance(libraries, str), "libraries must be a string"
    libraries = libraries.split(",")
    libraries = set([library.lower() for library in libraries])

    production_lines = []
    for production_line in Config.get("production-lines"):
        if "filters" not in production_line:
            production_lines.append(production_line)
            continue

        filters = production_line["filters"]
        production_line_libraries = set([library.lower() for library in filters.get("libraries", [])])
        if "libraries" in filters and not libraries.intersection(production_line_libraries):
            continue

        production_lines.append(production_line)

    return jsonify(production_lines), 200


@core.server.route(core.server.root_path + '/lines/<line_id>/', require_auth=None)
def line(line_id):
    core.server.expected_args(request, [])

    return getLine(line_id)


def getLine(line_id):
    lines = Config.get("production-lines")
    line = [line for line in lines if line["id"] == line_id]
    if line:
        return jsonify(line[0]), 200
    else:
        return "", 404
