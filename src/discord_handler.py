import requests
import json
import os
import logging
import argparse

# Load the JSON config
config_path = os.path.join(os.path.dirname(__file__), "config.json")

with open(config_path, "r") as f:
    config = json.load(f)

# Extract logging settings with defaults if keys are missing
log_file = config.get("logging", {}).get("log_file", "discord_bot.log")
log_level_str = config.get("logging", {}).get("log_level", "INFO").upper()

# Convert string log level to logging module level
log_level = getattr(logging, log_level_str, logging.INFO)

# Set up logging using config values
logging.basicConfig(
    filename=log_file,
    filemode="a",
    format="%(asctime)s - %(levelname)s - %(message)s",
    level=log_level
)

BOT_TOKEN = ""
CHANNEL_ID = ""

def send_message(content):
    url = f"https://discord.com/api/v10/channels/{CHANNEL_ID}/messages"
    headers = {
        "Authorization": f"Bot {BOT_TOKEN}",
        "Content-Type": "application/json"
    }
    json_data = {"content": content}
    r = requests.post(url, headers=headers, json=json_data)
    if r.status_code == 200 or r.status_code == 204:
        logging.info("Message sent successfully")
    else:
        print(f"Failed to send message: {r.status_code}, {r.text}")

# Example usage
send_message("🚨 The server is DOWN!")