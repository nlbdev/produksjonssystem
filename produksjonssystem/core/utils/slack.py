import logging
import os

import slack


class Slack():

    _slack = None
    slack_token = os.getenv("SLACK_BOT_TOKEN", None)
    slack_authed = None
    slack_channel = os.getenv("SLACK_CHANNEL", "#test")

    @staticmethod
    def slack(text, attachments, retry=True):
        assert not text or isinstance(text, str)
        assert not attachments or isinstance(attachments, list)
        assert text or attachments

        try:
            # If not authenticated: try to authenticate and test authorization
            if (not Slack.slack_authed or Slack._slack is None) and Slack.slack_token is not None:
                logging.info("Connecting to Slack…")
                Slack._slack = slack.WebClient(token=Slack.slack_token)
                try:
                    logging.info("Verifying connection to Slack…")
                    auth = Slack._slack.auth_test()
                    if auth.data.get("ok"):
                        logging.info("Slack authenticated as \"{}\" as part of the team \"{}\"".format(auth.data.get("user"), auth.data.get("team")))
                        Slack.slack_authed = True
                    else:
                        logging.warning("Failed to authenticate to Slack")
                        Slack.slack_authed = False

                except Exception:
                    logging.exception("Failed to authenticate to Slack")
                    Slack.slack_authed = False

            # Try to send
            if Slack.slack_authed:
                try:
                    Slack._slack.chat_postMessage(channel=Slack.slack_channel, text=text)  # TODO: fix attachments with slack library
                except Exception:
                    Slack._slack = None  # set to None so that we try to create a new connection when sending the next message
                    if retry:
                        Slack.slack(text, attachments, retry=False)
                    else:
                        logging.exception("An exception occured while trying to send a message to Slack")

            else:
                logging.warning("Not authenticated to send messages to Slack")
                logging.warning("Tried to send message to {}: {}".format(Slack.slack_channel, text))

        except Exception:
            logging.error("An error occured while trying to send a message to slack")
            logging.debug("text: " + str(text))
            logging.debug("attachments: " + str(attachments))
            logging.debug("retry: " + str(retry))
            logging.exception("Stacktrace for debugging")
            raise
