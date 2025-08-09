# 🛠️ BedrockServer

## 🔍 Overview
BedrockServer is a cron job-based service manager designed for Minecraft Bedrock Edition servers on Linux. It automates essential server management tasks, ensuring smooth operation with minimal manual intervention.

## 🚀 Features
**Automated Backups**: Regular snapshots of your server data to prevent data loss.

**Cloud Storage Integration**: Seamless backup server files to Google Drive.

**Discord Notifications**: Real-time alerts for server events and issues.

**Automatic Updates**: Ensures your server is always running the latest version with nightly updates.

**Robust Logging**: Detailed logs for monitoring and troubleshooting.

## 🛠️ Installation
### Clone the Repository:

```bash
Copy
Edit
git clone https://github.com/LlamaWhisp3r3r/BedrockServer.git
cd BedrockServer
```
### Set Executable Permissions:

```bash
Copy
Edit
chmod +x bedrock_server.sh
```
### ⚙️ Configuration:
Edit the config.json file to set your server paths, notification settings, and other preferences.
Sample config.json:

```json
{
    "script": {
        "server_dir": "/home/server/bedrock-server",
        "version_file": "",
        "tmp_dir": "",
        "log_file": "",
        "backup_folder": "",
        "discord_enabled": false,
        "google_enabled": false
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

### Set Up Cron Job:
Schedule the script to run at your desired intervals using cron:

```bash
crontab -e
```
Add the following line to run the script every minute:

```cron
* * * * * /full/path/to/bedrock_server.sh
```

## 📦 Dependencies
### 🐚 Shell
- chromium-browser
### 🐍Python > 3.5
- requests
- googleapiclient


## 🤝 Contributing
Contributions are welcome! Please fork the repository, create a new branch, and submit a pull request with your proposed changes.

## 📄 License
This project is licensed under the Apache 2.0 License — see the LICENSE file for details.