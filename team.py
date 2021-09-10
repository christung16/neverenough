import os
import credential
from webexteamsbot import TeamsBot

# Retrieve required details from environment variables
bot_email = credential.bot_email
teams_token = credential.bot_token
bot_url = credential.bot_url
bot_app_name = credential.bot_app_name

# Create a Bot Object
bot = TeamsBot(
    bot_app_name,
    teams_bot_token=teams_token,
    teams_bot_url=bot_url,
    teams_bot_email=bot_email,
)


# A simple command that returns a basic string that will be sent as a reply
def do_something(incoming_msg):
    """
    Sample function to do some action.
    :param incoming_msg: The incoming message object from Teams
    :return: A text or markdown based reply
    """
    return "i did what you said - {}".format(incoming_msg.text)


# Add new commands to the box.
bot.add_command("/dosomething", "help for do something", do_something)


if __name__ == "__main__":
    # Run Bot
    bot.run(host="0.0.0.0", port=5000)
