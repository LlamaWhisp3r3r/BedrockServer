#!/bin/bash

checkServer() {
    # Check if server is already running
    if tmux has-session -t minecraftserver 2>/dev/null; then
        checkRestartTime
    else
        startServer
    fi
}

startServer() {
    # Start a new tmux session running the bedrock server
    tmux new-session -d -s minecraftserver 'LD_LIBRARY_PATH=../bedrock_server ./bedrock_server'
}

checkRestartTime() {
    read hour minute <<< "$(date +"%H %M")"

    # Restart warnings at 30, 15, 10, 5, and 1 minutes before midnight (23:30+)
    if [[ $hour -eq 23 ]]; then
        case $minute in
            30|45|50|55|59)
                mins_until_restart=$((60 - minute))
                sendRestartMessage "$mins_until_restart"
                ;;
        esac
    fi

    # Restart exactly at midnight (00:00)
    if [[ $hour -eq 0 && $minute -eq 0 ]]; then
        restartServer
    fi
}

sendRestartMessage() {
    local restartMins=$1
    # Sends a chat on the server about pending restart
    tmux send-keys -t minecraftserver "/tellraw @a [\"\",{\"text\":\"[\"},{\"text\":\"server\",\"color\":\"gold\"},{\"text\":\"] \"},{\"text\":\"Realm will restart in $restartMins minutes.\",\"color\":\"dark_red\"}]" C-m
}

restartServer() {
    tmux send-keys -t minecraftserver "stop" C-m
    sleep 5
    tmux kill-session -t minecraftserver
    downloadLatestBedrock
    # Optional: backup
    # Uncomment to enable
    # python GoogleDriveAPIConnector.py
    startServer
}

downloadLatestBedrock() {
    local SERVER_DIR="/path/to/minecraft_server"
    local VERSION_FILE=$(ls "$SERVER_DIR/bedrock-server-*" | head -n 1)
    local TMP_DIR="$SERVER_DIR/tmp/minecraft_bedrock_update"

    mkdir -p "$TMP_DIR"

    # Fetch download URL from Mojang's official site
    local DOWNLOAD_URL
    DOWNLOAD_URL=$(curl -s https://www.minecraft.net/en-us/download/server/bedrock \
        | grep -Eo 'https://www\.minecraft\.net/bedrockdedicatedserver/bin-linux/bedrock-server-[0-9.]+\.zip' \
        | head -n 1)
    local NEW_URL=$(echo "$DOWNLOAD_URL" | sed -n 's/.*bedrock-server-\([0-9.]*\)\.zip/\1/p')

    # Compute future .zip file
    local ZIP_FILENAME
    ZIP_FILENAME=$(basename "$DOWNLOAD_URL" .zip)

    # Get current installed version
    local CURRENT_VERSION=$(echo $VERSION_FILE | sed -n 's/.*bedrock-server-\([0-9.]*\)/\1/p')

    # Compare versions
    if [[ "$NEW_URL" == "$CURRENT_VERSION" ]]; then
        return 0
    else
        # New version found
        curl -o "$TMP_DIR/$ZIP_FILENAME.zip" "$DOWNLOAD_URL"
        unzip -ou "$TMP_DIR/$ZIP_FILENAME.zip" -d "$TMP_DIR"
        rsync -av --exclude='permissions.json' \
            --exclude='server.properties' \
            --exclude='whitelist.json' \
            "$TMP_DIR/" "$SERVER_DIR"
    fi

    # Clean up temp folder
    rm -rf "$TMP_DIR"
}

checkServer