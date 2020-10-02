import copy


class Config():
    config = {}

    @staticmethod
    def get(name, default=None):
        return copy.deepcopy(Config.config[name]) if name in Config.config else default

    @staticmethod
    def set(name, value):
        Config.config[name] = value
