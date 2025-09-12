import json
import sys
import requests
import logging

# Ensure a message is provided
if len(sys.argv) < 3:
    print("Usage: python discord_handler.py config_file warning_message")
    sys.exit(1)

# Combine all arguments into a single string (so no need for quotes)
message = "".join(sys.argv[2:])
config_file = "".join(sys.argv[1])

# --- Load Config ---
try:
    with open(config_file, "r") as f:
        config = json.load(f)
except FileNotFoundError:
    print("Error: config.json not found.")
    sys.exit(1)
except json.JSONDecodeError:
    print("Error: config.json is not valid JSON.")
    sys.exit(1)

BOT_TOKEN = config.get("discord", {}).get("bot_token")
CHANNEL_ID = config.get("discord", {}).get("channel_id")
log_file = config.get("script", {}).get("log_file")

if not log_file:
    log_file = config.get("script", {}).get("server_dir") + "/maintenance/logs/server.log"

# --- Logging Setup ---
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

if not BOT_TOKEN or not CHANNEL_ID:
    logging.critical("BOT_TOKEN or CHANNEL_ID missing from config.json")
    print("Error: BOT_TOKEN or CHANNEL_ID missing from config.json")
    sys.exit(1)

# Send message to Discord
url = f"https://discord.com/api/v9/channels/{CHANNEL_ID}/messages"
headers = {
    "Authorization": f"Bot {BOT_TOKEN}",
    "Content-Type": "application/json"
}
payload = {"content": message}

try:
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code == 200:
        logging.info(f"Message sent successfully: {message}")
    else:
        logging.error(f"Failed to send message ({response.status_code}): {response.text}")
except requests.RequestException as e:
    logging.exception("Request to Discord API failed.")
    pass