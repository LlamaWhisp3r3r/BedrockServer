#!/usr/bin/env bash
set -e

# Default values
SCRIPT_DOWNLOAD_URL="https://github.com/LlamaWhisp3r3r/BedrockServer/archive/refs/heads/main.zip"
BASE_PATH=/bedrock-server
INSTALL_PATH=/bedrock-server/maintenance
VENV_PATH="$INSTALL_PATH/scriptvenv"
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

echo "[*] Installing script to $INSTALL_PATH..."
sudo mkdir -p "$INSTALL_PATH"

echo "[*] Setting up maintenance folder and files within..."
if [[ ! -f "$INSTALL_PATH" ]]; then
    if ! sudo wget -P "$INSTALL_PATH" "$SCRIPT_DOWNLOAD_URL"; then
        echo "Could not download scripts from GitHub."
        exit 1
    fi

    sudo unzip -j "$INSTALL_PATH/main.zip" "BedrockServer-main/src/*" -d "$INSTALL_PATH/"
    sudo chmod +x "$INSTALL_PATH/bedrock_server.sh"
    sudo rm -f "$INSTALL_PATH/main.zip"

    # Create server user for security reasons
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin bedrockserver
    sudo chown -R bedrockserver:bedrockserver "$BASE_PATH"
    sudo chmod -R 750 "$BASE_PATH"
    sudo chown -R bedrockserver:bedrockserver "$INSTALL_PATH"
    sudo chmod -R 750 "$INSTALL_PATH"

    # Define the cron job
    CRON_JOB="* * * * * bedrockserver $INSTALL_PATH/bedrock_server.sh 2>&1"

    # Install the cron job if it's not already present
    ( sudo -u bedrockserver crontab -l 2>/dev/null | grep -F "$CRON_JOB" ) || (
        sudo -u bedrockserver crontab -l 2>/dev/null; echo "$CRON_JOB"
    ) | sudo -u bedrockserver crontab -
else
    echo "Could not create maintenance directory at $INSTALL_PATH"
    exit 1
fi

echo "[✔ ] Installation complete!"