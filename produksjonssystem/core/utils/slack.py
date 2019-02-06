import logging
import os

from slacker import Slacker


class Slack():

    _slack = None
    _slack_token = os.getenv("SLACK_TOKEN", None)
    _slack_authed = None
    _slack_channel = os.getenv("SLACK_CHANNEL", "#test")

    @staticmethod
    def slack(text, attachments, retry=True):
        assert not text or isinstance(text, str)
        assert not attachments or isinstance(attachments, list)
        assert text or attachments

        # If not authenticated: try to authenticate and test authorization
        if not Slack._slack_authed or Slack._slack is None:
            Slack._slack = Slacker(os.getenv("SLACK_TOKEN"))
            try:
                auth = Slack._slack.auth.test()
                if auth.successful:
                    logging.info("Slack authorized as \"{}\" as part of the team \"{}\"".format(auth.body.get("user"), auth.body.get("team")))
                    Slack._slack_authed = True
                else:
                    logging.warning("Failed to authorize to Slack")
                    Slack._slack_authed = False

            except Exception:
                logging.exception("Failed to authorize to Slack")
                Slack._slack_authed = False

        # Try to send
        if Slack._slack_authed:
            try:
                Slack._slack.chat.post_message(channel=Slack._slack_channel, as_user=True, text=text, attachments=attachments)
            except Exception:
                Slack._slack = None  # set to None so that we try to create a new connection when sending the next message
                if retry:
                    Slack.slack(text, attachments, retry=False)
                else:
                    logging.exception("An exception occured while trying to send a message to Slack")

        else:
            logging.warning("Not authorized to send messages to Slack")
            logging.warning("Tried to send message to {}: {}".format(Slack._slack_channel, text))
