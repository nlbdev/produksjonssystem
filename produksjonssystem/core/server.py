#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import copy
import logging
import os
import sys
import traceback
from datetime import date, datetime
from decimal import Decimal
from functools import wraps
from random import random
import threading

import pybrake.flask
import requests
from authlib.jose import jwt
from flask import Flask
from flask import jsonify as flask_jsonify
from flask import redirect, request
from flask.json import JSONEncoder
from werkzeug.exceptions import HTTPException, InternalServerError

from core.config import Config
from core.utils.filesystem import Filesystem


class CustomJSONEncoder(JSONEncoder):
    def default(self, obj):
        try:
            if isinstance(obj, date):
                return obj.isoformat()
            if isinstance(obj, Decimal):
                return float(obj)
            iterable = iter(obj)
        except TypeError:
            pass
        else:
            return list(iterable)
        return JSONEncoder.default(self, obj)


def jsonify_filter(obj):

    # list recursion
    if isinstance(obj, list):
        return [jsonify_filter(item) for item in obj]

    # dict recursion
    elif isinstance(obj, dict):
        result = {}
        for key in obj:
            result[jsonify_filter(key)] = jsonify_filter(obj[key])
        return result

    # tuple recursion
    elif isinstance(obj, tuple):
        return tuple([jsonify_filter(item) for item in list(obj)])

    elif obj == float("Inf") or obj == float("-Inf") or obj == float("NaN"):
        return None  # ±Infinite and NaN is not allowed in the JSON standard

    else:
        return obj


def jsonify(obj):
    filtered_obj = jsonify_filter(obj)

    return flask_jsonify(filtered_obj)


app = Flask(__name__)
app.url_map.strict_slashes = False
app.json_encoder = CustomJSONEncoder
app.config['JSON_SORT_KEYS'] = False  # retain insertion order of keys (gives nicer JSON output)
shouldRun = True
test = "test" in sys.argv or os.environ.get("TEST", "0") == "1"
mock_jwt_claims = None

root_path = "/prodsys"
version = 1
host = os.getenv("HOST", default="0.0.0.0")
port = os.getenv("PORT", default=3875)
root_path = "{}/v{}".format(root_path, version)
base_url = "http://{}{}{}".format(host,
                                  ":{}".format(port),
                                  root_path)

thread = None
shutdown_function = None


def route(rule, **options):
    global test
    global mock_jwt_claims

    # require_auth:
    #  - if None: publically available endpoint
    #  - if not None, at least one of the permissions in the list must be claimed (an empty list will always be denied auth)
    def auth(func):
        @wraps(func)
        def decorated(*args, **kwargs):
            jwt_token = request.headers.get('Authorization')
            jwt_secret = os.environ.get("JWT_SECRET")

            # handle all cases of Authorization, AUTHORIZATION, authorization, etc.
            if not jwt_token:
                for name, value in request.headers:
                    if name.lower() == "authorization":
                        jwt_token = value
                        break

            claims = None

            if test and mock_jwt_claims is not None:
                claims = copy.deepcopy(mock_jwt_claims)

            else:
                if not isinstance(jwt_token, str):
                    return jsonify({"head": {"message": "JSON Web Token is missing"}, "data": None}), 403

                if not isinstance(jwt_secret, str):
                    return jsonify({"head": {"message": "JSON Web Token is not configured correctly"}, "data": None}), 500

                # remove type ("Bearer") if present
                jwt_token = jwt_token.split(" ")[-1]

                try:
                    claims = jwt.decode(jwt_token, jwt_secret)
                    claims.validate()
                except Exception:
                    traceback.print_exc()
                    return jsonify({"head": {"message": "Invalid JSON Web Token"}, "data": None}), 403

            if "user_permissions" not in claims or not isinstance(claims["user_permissions"], list):
                return jsonify({"head": {"message": "JSON Web Token is missing 'user_permissions', or 'user_permissions' is not a list"}, "data": None}), 403

            # will for instance replace "{identifier}" with whatever the identifier argument is set to
            require_auth = options.get("require_auth", [])
            if require_auth is not None:
                require_auth = [permission.format(**kwargs) for permission in require_auth]

            # check if either of the permissions in require_auth are claimed (note: an empty list will not be granted access)
            authorized = False
            if require_auth is None:
                authorized = True
            else:
                if require_auth is not None:
                    for permission in require_auth:
                        if permission in claims["user_permissions"]:
                            authorized = True
                            break

            if authorized:
                return func(*args, **kwargs)

            logging.warn(f"Unauthorized JWT claims: {claims}")

            return jsonify({"head": {"message": "Unauthorized"}, "data": None}), 403

        return decorated

    def decorator(func):
        global app

        assert "require_auth" in options, "require_auth must be defined for routes"

        url_rule_options = copy.deepcopy(options)
        endpoint = url_rule_options.pop("endpoint", None)
        require_auth = url_rule_options.pop("require_auth", [])

        assert require_auth is None or isinstance(require_auth, list), "require_auth must be either None or a list"

        if require_auth is not None:
            func = auth(func)

        app.add_url_rule(rule, endpoint, func, **url_rule_options)

        return func

    return decorator


def filter_claims(filter_func):
    global test
    global mock_jwt_claims

    def decorator(func):
        def wrapper(*args, **kwargs):
            response, status_code = func(*args, **kwargs)

            claims = {}
            if bool(request) is True:
                # If bool(request) is False, then we're not responding
                # to a HTTP request. This happens for instance when we're
                # updating the cache.
                if test and mock_jwt_claims is not None:
                    claims = copy.deepcopy(mock_jwt_claims)

                else:
                    try:
                        jwt_token = request.headers.get('Authorization')
                        jwt_secret = os.environ.get("JWT_SECRET")

                        if jwt_token:
                            # remove type ("Bearer") if present
                            jwt_token = jwt_token.split(" ")[-1]

                        claims = jwt.decode(jwt_token, jwt_secret)
                        claims.validate()

                    except Exception:
                        # This is only to extract claims if the JWT is valid.
                        # If we're unable to get claims from a valid JWT,
                        # we just return an empty dictionary.
                        # We don't throw any exceptions at this point.
                        claims = {}

            filter_func(response, claims)

            return response, status_code

        return wrapper
    return decorator


def claims_has_permission(claims, permission):
    if not isinstance(claims, dict):
        return False

    if "user_permissions" not in claims:
        return False

    if not isinstance(claims["user_permissions"], list):
        return False

    return permission in claims["user_permissions"]


class BadArgumentException(Exception):
    pass  # custom exception to be thrown when the type is wrong


@app.errorhandler(BadArgumentException)
def handle_BadArgumentException(e):
    return jsonify({"head": {"message": str(e)}, "data": None}), 400


@app.errorhandler(HTTPException)
def handle_HTTPException(e):
    logging.exception(request.url)
    return jsonify({"head": {"message": e.name}, "data": None}), e.code


@app.errorhandler(InternalServerError)
def handle_InternalServerError(e):
    logging.exception(request.url)
    return jsonify({"head": {"message": "Internal server error"}, "data": None}), 500


@app.errorhandler(Exception)
def handle_Exception(e):
    logging.exception(request.url)
    return jsonify({"head": {"message": "Internal server error"}, "data": None}), 500


def get_arg(request, *args, **kwargs):
    t = kwargs["type"] if "type" in kwargs else None
    value = request.args.get(*args, **kwargs)

    if "type" in kwargs:
        t = kwargs["type"]
        del kwargs["type"]
        value_untyped = request.args.get(*args, **kwargs)

        if value is not None and not isinstance(value, t):
            raise BadArgumentException(f"{args[0]} must be a {t} (value parsed as incorrect type)")

        if value is None and value_untyped is not None:
            raise BadArgumentException(f"{args[0]} must be a {t}")

    return value


def expected_args(request, expected):
    for arg in request.args:
        if arg not in expected:
            raise BadArgumentException(f"Unexpected argument: {arg}. These arguments are allowed: {expected}")


# endpoint: /kill
def kill():
    """
    Used internally for shutting down. Should not be used by exernal applications.
    """
    # See:
    # - http://flask.pocoo.org/snippets/67/
    # - https://stackoverflow.com/a/26788325/281065

    werkzeug_server_shutdown = request.environ.get("werkzeug.server.shutdown")
    if werkzeug_server_shutdown is None:
        raise RuntimeError("Not running with the Werkzeug Server")
    werkzeug_server_shutdown()
    logging.info("Shutting down…")

    return "Shutting down…"  # won't arrive as a response to the client though, as the server has been shut down…


# the easiest way to shut down Flask is through an instance of request,
# so we create this endpoint which gives us a request instance
kill_endpoint = "/kill{}/".format(str(random()).split(".")[-1])  # random endpoint to discourage explicit external usage
app.add_url_rule(root_path + kill_endpoint, "kill", kill, methods=["POST"])


# endpoint: /update
# NOTE: We might want to add some permission requirement to this one in the future.
@route(root_path + '/update/', require_auth=None, methods=["GET", "PUT"])
def update():
    project_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

    process = Filesystem.run_static(["git", "pull"], cwd=project_dir)

    if process.returncode == 0:
        return jsonify(process.stdout.decode("utf-8")), 200
    else:
        return jsonify(process.stderr.decode("utf-8")), 500


# endpoint: /shutdown
# NOTE: does not require auth, as it's an internal system. We might want to add some permission requirement to this one in the future.
@route(root_path + '/shutdown/', require_auth=None, methods=["GET", "PUT"])
def shutdown():
    """
    Shut down the system.
    """

    global shouldRun
    global base_url
    global shutdown_function

    shouldRun = False
    Config.set("system.shouldRun", False)

    if shutdown_function:
        shutdown_function()

    else:
        response = requests.post(base_url + kill_endpoint)

        # at this point the server is shut down though, so this response will not arrive at the client…
        if response.status_code == requests.codes.ok:
            return response.content, 200
        else:
            return {"head": {"message": "An error occured"}, "data": None}, 500


@route(root_path + '/', require_auth=None)
def root():
    """
    Root endpoint. Lists all possible endpoints.
    """

    endpoint = request.url[len(request.url_root)-1:]
    if endpoint != root_path+"/":
        return redirect(root_path+"/", code=302)
    else:
        rules = []
        for rule in app.url_map.iter_rules():
            path = str(rule)[len(root_path)+1:]
            if not path or path.startswith("kill") or "/" not in path:
                continue
            rules.append(path)  # strips root_path, making the result a path relative to root
        return jsonify(rules), 200


# forward endpoints "above" the root, to the root (i.e. /…/ and /…/v1/)
if root_path != "":
    app.add_url_rule("/", "root", root)
    parts = [part for part in root_path.split("/") if part]
    endpoints_above = ["/".join(parts[0:i+1]) for i in range(0, len(parts)-1)]
    for endpoint in endpoints_above:
        app.add_url_rule("/{}/".format(endpoint), "root", root)


def test_client():
    global test
    test = True
    return app.test_client()


def mock_auth(user_permissions):
    global mock_jwt_claims

    assert user_permissions is None or isinstance(user_permissions, list), f"mock_auth: user_permissions must be a list or None. Was: {type(user_permissions)}"

    mock_jwt_claims = {"user_permissions": user_permissions}


mock_datetime_now = None


def datetime_now():
    global mock_datetime_now

    if mock_datetime_now:
        return mock_datetime_now
    else:
        return datetime.now()


def mock_now(now):
    global mock_datetime_now

    mock_datetime_now = now


def run(debug=False, airbrake_config=None, shutdown_function=None):
    global app
    global host
    global port

    if airbrake_config is not None:
        app.config['PYBRAKE'] = airbrake_config
        app = pybrake.flask.init_app(app)

    app.run(debug=debug, host=host, port=port, use_reloader=False)


# Use start and join to run as a thread
def start(hot_reload=False, airbrake_config=None, shutdown_function=None):
    """
    Start thread
    """

    global thread, base_url

    # app.run should ideally not be used in production, but oh well…
    thread = threading.Thread(target=run, name="api", kwargs={
        "debug": hot_reload,
        "airbrake_config": airbrake_config,
        "shutdown_function": shutdown_function,
    })
    thread.setDaemon(True)
    thread.start()

    logging.info("Started API on {}".format(base_url))
    return thread


# Stop the API
def join():
    """
    Stop thread
    """

    global thread, base_url, kill_endpoint

    requests.post(base_url + kill_endpoint)

    logging.debug("joining {}".format(thread.name))
    thread.join(timeout=5)

    if thread.is_alive():
        logging.debug("The API thread is still running. Let's ignore it and continue shutdown…")
