from flask import jsonify, request

import core.server
from core.config import Config


@core.server.route(core.server.root_path + '/creative-works/', require_auth=None)
def creativeWorks(self):
    core.server.expected_args(request, [])

    # [ "<isbn>", "<isbn>", "<isbn>", "-<edition_id>", "-<edition_id>", "-<edition_id>" ]
    return "TODO", 501
