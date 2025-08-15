#!/usr/bin/env bash
set -e

# Default values
SCRIPT_DOWNLOAD_URL="https://github.com/LlamaWhisp3r3r/BedrockServer/archive/refs/heads/main.zip"
BASE_PATH=/bedrock-server
INSTALL_PATH=/bedrock-server/maintenance
VENV_PATH="$INSTALL_PATH/venv"
DEPS=("jq" "chromium-browser" "python3" "python3-pip" "python3-venv")
PYTHON_DEPS=("requests" "google-api-python-client")

usage() {
    echo "Usage: $0 [-n script_download_url] [-p install_path] [-e venv_directory]"
    echo "  -n  Script download url (default: $SCRIPT_DOWNLOAD_URL)"
    echo "  -b  Base server directory (default: $BASE_PATH)"
    echo "  -p  Install path (default: $INSTALL_PATH)"
    echo "  -e  Venv directory (default: $VENV_PATH)"
    exit 1
}

# Parse command-line arguments
while getopts "n:p:c:h" opt; do
    case "$opt" in
        n) SCRIPT_NAME="$OPTARG" ;;
        p) INSTALL_PATH="$OPTARG" ;;
        e) VENV_PATH="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

echo "[*] Installing dependencies..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y "${DEPS[@]}"
    sudo python3 -m venv "$VENV_PATH"
    source "$VENV_PATH/bin/activate"
    sudo "$VENV_PATH/bin/pip" install --upgrade pip
    sudo "$VENV_PATH/bin/pip" install "${PYTHON_DEPS[@]}"
elif command -v yum &> /dev/null; then
    sudo yum install -y "${DEPS[@]}"
    sudo python3 -m pip install "${PYTHON_DEPS[@]}"
else
    echo "Please install: ${DEPS[*]}"
fi

downloadURL=$(chromium-browser --mute-audio --log-level=3 --headless --disable-gpu --dump-dom -no-sandbox --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" "https://www.minecraft.net/en-us/download/server/bedrock" | grep -Eo 'https://www\.minecraft\.net/bedrockdedicatedserver/bin-linux/bedrock-server-[0-9.]+\.zip')
newVersion=$(echo "$downloadURL" | sed -n 's/.*bedrock-server-\([0-9.]*\)\.zip/\1/p')
mv "$BASE_PATH/bedrock_server" "$BASE_PATH/bedrock-server-$newVersion"
echo "[*] Installing script to $INSTALL_PATH..."
sudo mkdir -p "$INSTALL_PATH"

echo "[*] Setting up maintenance folder and files within..."
if [[ ! -f "$INSTALL_PATH" ]]; then
    if ! sudo wget -P "$INSTALL_PATH" "$SCRIPT_DOWNLOAD_URL"; then
        echo "Could not download scripts from GitHub."
        exit 1
    fi

    sudo unzip -oj "$INSTALL_PATH/main.zip" "BedrockServer-main/src/*" -d "$INSTALL_PATH/"
    sudo chmod +x "$INSTALL_PATH/bedrock_server.sh"
    sudo rm -f "$INSTALL_PATH/main.zip"
    # Update config file to match parameters passed to script
    jq --arg serverdir "$BASE_PATH" --arg venvpath "$VENV_PATH" '.script.server_dir = $serverdir | .script.venv_path = $venvpath' $INSTALL_PATH/config.json > tmp.$$.json && sudo mv -f tmp.$$.json $INSTALL_PATH/config.json

    if id -u bedrockserver >/dev/null 2>&1; then
        echo "User 'username' already exists, skipping useradd."
    else
        sudo useradd --system --no-create-home --shell /usr/sbin/nologin bedrockserver
    fi
    if getent group bedrockgroup >/dev/null 2>&1; then
        echo "Group 'bedrockgroup' already exists, skipping groupadd."
    else
        sudo groupadd bedrockgroup
    fi
    sudo usermod -aG bedrockgroup $USER
    sudo usermod -aG bedrockgroup bedrockserver
    sudo chgrp -R bedrockgroup "$BASE_PATH"
    sudo chmod -R 770 "$BASE_PATH"
    sudo find "$BASE_PATH" -type d -exec chmod g+s {} \;

    # Define the cron job
    CRON_JOB="* * * * *  $INSTALL_PATH/bedrock_server.sh $INSTALL_PATH >> $INSTALL_PATH/cron.log 2>&1"
    echo "CRONJOB! $CRON_JOB"

    # Install the cron job if it's not already present
    ( sudo crontab -u bedrockserver -l 2>/dev/null | grep -F "$CRON_JOB" ) || (sudo crontab -u bedrockserver -l 2>/dev/null; echo "$CRON_JOB") | sudo -u bedrockserver crontab - 
else
    echo "Could not create maintenance directory at $INSTALL_PATH"
    exit 1
fi

echo "[✔ ] Installation complete!"