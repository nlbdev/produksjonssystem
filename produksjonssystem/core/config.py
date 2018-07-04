class Config():
    config = {}

    @staticmethod
    def get(name, default=None):
        return Config.config[name] if name in Config.config else default

    @staticmethod
    def set(name, value):
        Config.config[name] = value
