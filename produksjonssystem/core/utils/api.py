# -*- coding: utf-8 -*-

import traceback
from flask import Response
import requests

from core.config import Config

class Api():

    def __init__(self) -> None:
        pass
    
    def get(url: str, payload: str, headers: dict) -> Response | None:
        try:
            response = requests.get(Config.get("nlb_api_url") + url, params=payload, headers=headers)
            return response
        except Exception as e:
            print(e)
            traceback.print_exc()
            return None

    def post(url: str, payload: str, headers: dict) -> Response | None:
        try:
            response = requests.post(Config.get("nlb_api_url") + url, data=payload, headers=headers)
            return response
        except Exception as e:
            print(e)
            traceback.print_exc()
            return None

    def put(url: str, payload: str, headers: dict) -> Response | None:
        try:
            response = requests.put(Config.get("nlb_api_url") + url, data=payload, headers=headers)
            return response
        except Exception as e:
            print(e)
            traceback.print_exc()
            return None

    def delete(url: str, payload: str, headers: dict) -> Response | None:
        try:
            response = requests.delete(Config.get("nlb_api_url") + url, data=payload, headers=headers)
            return response
        except Exception as e:
            print(e)
            traceback.print_exc()
            return None