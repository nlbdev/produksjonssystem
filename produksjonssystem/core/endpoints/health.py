import os
import psutil
import time
from flask import jsonify

import core.server
from core.config import Config


system_shouldRun_False_Since = None


@core.server.route(core.server.root_path + '/health/', require_auth=None)
def health():
    global system_shouldRun_False_Since

    head = {}

    process = psutil.Process(os.getpid())
    memory_used = process.memory_info().rss
    head["memory_used"] = memory_used
    head["memory_used_human_readable"] = human_readable_bytes(memory_used)

    healthy = False
    if Config.get("system.shouldRun", False):
        system_shouldRun_False_Since = None
        head["message"] = "Running"
        healthy = True

    else:
        if not system_shouldRun_False_Since:
            system_shouldRun_False_Since = time.time()

        # unhealthy if it takes more than 10m to shut down
        if time.time() - system_shouldRun_False_Since > 600:
            head["message"] = "Shutdown is taking more than ten minutes"
            healthy = False
        else:
            head["message"] = "Shutting down"
            healthy = True

    return jsonify({"head": head, "data": healthy}), 200


def human_readable_bytes(bytes):
    if bytes < 1024:
        return str(bytes) + " B"
    elif bytes < 1024**2:
        return str(int(bytes / 1024)) + " kiB"
    elif bytes < 1024**3:
        return str(int(bytes / (1024**2))) + " MiB"
    elif bytes < 1024**4:
        return str(int(bytes / (1024**3))) + " GiB"
    elif bytes < 1024**5:
        return str(int(bytes / (1024**4))) + " TiB"
    else:
        return str(bytes) + " B"
