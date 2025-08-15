# 🛠️ BedrockServer

## 🔍 Overview
***BedrockServer*** is a cron job-based service manager designed for Minecraft Bedrock Edition servers on Linux. It automates essential server management tasks, ensuring smooth operation with minimal manual intervention.

## 🚀 Features
**Automated Backups**: Regular snapshots of your server data to prevent data loss.

**Cloud Storage Integration**: Seamless backup server files to Google Drive.

**Discord Notifications**: Real-time alerts for server downage and issues.

**Automatic Updates**: Ensures your server is always running the latest version with nightly updates.

**Robust Logging**: Detailed logs for monitoring and troubleshooting.

## 🛠️ Installation
### Use Install Script:
For your ease of use you can use the provided install script. This will install dependecies and set up the enviroment, server user, etc.

```bash
wget https://raw.githubusercontent.com/LlamaWhisp3r3r/BedrockServer/refs/heads/main/install.sh
chmod +x ./install.sh
./install.sh
rm ./install.sh
```

### Install Script Arguments
***install.sh*** has the following arguments you can use to make sure it installed correctly:

    -n  Script download url (default: "https://github.com/LlamaWhisp3r3r/BedrockServer/archive/refs/heads/main.zip")

    -b  Base Minecraft server directory. This is where the bedrock_server executable is. (default: "/bedrock-server")

    -p  Install path of the utilities scripts. (default: "/BASE_DIR/maintanence")

    -e  Venv directory to get the python enviroment. (default: "/BASE_DIR/maintanence/venv")


### ⚙️ Configuration:
Edit the config.json file to set your server paths, notification settings, and other preferences.
Sample config.json:

```json
{
    "script": {
        "server_dir": "/bedrock-server",
        "version_file": "",
        "tmp_dir": "",
        "log_file": "",
        "backup_folder": "",
        "discord_enabled": false,
        "google_enabled": false,
        "venv_path": ""
    },
    "discord": {
        "bot_token": "",
        "channel_id": ""
    },
    "google": {
        "credentials": "",
        "token": "",
        "drive_folder": "",
        "local_folder": ""
    }
}
```

### Config.json Description
Here is a brief explanation on what all the fields do in the *config.json* file.

#### ⚠️ There is only one required option that will need to be included in config.json, ***server_dir***

    "server_dir" [REQUIRED] - Directory where the Minecraft Dedicated Server is installed. Default: "/bedrock-server"

    "version_file" - This is the Minecraft Dedicated Server executable. In this script it renames the file to have the version at the end of the executable. This will be checked to see if there is a new version of the server to be installed. You don't need to specify this unless you have non-default directory structure.

    "tmp_dir" - Directory where the new version of the server will be unzipped and synced with the server directory. If you do not want it on the default "/server_dir/maintenance/tmp" directory then change this.

    "log_file" - This is the file the running script will use to log all the events of the server. Default: "/server_dir/maintenance/logs/server.log"

    "backup_folder" - Directory used to store all the backups made of your server. Default: "/server_dir/maintenance/backups"

    "discord_enabled" - Determines if the script will post on a discord channel when the server is down or has issues. Default: false

    "google_enabled" - Determines if the script will backup the server files to Google Drive. Default: false

    "venv_path" - Directory for virtual python enviroment used by the discord_handler and google_handler. Default: "/server_dir/maintenance/venv"

    "bot_token" - The token used by the Discord intergration script.

    "channel_id" - The channel id to publish messages to when the Discord integration script is used.

    "credentials_path" - File path of the creds.json file used with the Google integration script. Default: "/server_dir/maintenance/credentials.json"

    "token_path" - File path of the token.json file used with the Google integration script. Default: "/server_dir/maintenance/token.json"

    "drive_folder" - The directory to store the backups of you server on Goolge Drive. Default: "Backups"

    

## 🤖 Discord Bot Setup
If you are wanting to use the discord bot to post notifications of your server downages and issues you will need to create your own App. I would highly recommend looking at [this](https://discordpy.readthedocs.io/en/stable/discord.html) tutorial to see how to create the app. 

#### ⚠️ Make sure to give you App the Send Messages permissions 

Now you will need to get the bot token and channel id. Look [here](https://www.writebots.com/discord-bot-token/) for the documentation on how to get the bot token. And [here](https://docs.statbot.net/docs/faq/general/how-find-id/) for the documentation on how to get the channel id you want to publish to.

Now you can copy and paste the token and channel id into the respective fields in the *config.json* file.

#### ⚠️ Make sure to change the discrod_enable to **true** in *config.json*

## 🚗 Google Drive Setup
If you want to backup your server to Google Drive daily you can use the built in Google handler included in this script. Here are the steps to get it working:

1. Go to https://console.cloud.google.com/
2. Create a new project.
3. Create an OAuth token and credential. https://console.cloud.google.com/apis/credentials
4. Download the credentials file and rename it to *credentials.json*
5. Place the credentials file in the same directory the google_drive_handler.py is in (default: "/server_dir/maintenance")
6. Switch google_enabled field in config.json to *true*.

#### ⚠️ Make sure to change drive_folder if you want a different directory then the dedault

## 📦 Dependencies
### 🐚 Shell
- chromium-browser
- jq
- python3
- python3-pip
- python3-venv
- snapd
### 🐍Python > 3.5
- requests
- google-api-python-client
- logging
- datetime


## 🤝 Contributing
Contributions are welcome! Please fork the repository, create a new branch, and submit a pull request with your proposed changes.

## 📄 License
This project is licensed under the Apache 2.0 License — see the LICENSE file for details.