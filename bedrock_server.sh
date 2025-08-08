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
    tmux new-session -d -s minecraftserver "LD_LIBRARY_PATH=$SERVER_DIR $versionFile"
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
    tmux send-keys -t minecraftserver 'tellraw @a {"rawtext":[{"text":"[§6server§r] §4Realm will restart in '"$restartMins"' minutes"}]}' C-m
}

restartServer() {
    tmux send-keys -t minecraftserver "stop" C-m
    sleep 5
    # TODO: Add server shutdown check instead of kill
    tmux kill-session -t minecraftserver
    downloadLatestBedrock
    # Optional: backup
    # Uncomment to enable
    # python google_drive_handler.py
    # python discord_handler.py
    startServer
}

downloadLatestBedrock() {
    local SERVER_DIR="/path/to/minecraft_server"
    local versionFile=$(ls $SERVER_DIR/bedrock-server-* | head -n 1)
    local tmpDIR="$SERVER_DIR/tmp"

    mkdir -p "$tmpDIR"

    # Fetch download URL from Mojang's official site
    local downloadURL
    downloadURL=$(chromium-browser --mute-audio --log-level=3 --headless --disable-gpu --dump-dom -no-sandbox --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" "https://www.minecraft.net/en-us/download/server/bedrock" | grep -Eo 'https://www\.minecraft\.net/bedrockdedicatedserver/bin-linux/bedrock-server-[0-9.]+\.zip')
    local newVersion=$(echo "$downloadURL" | sed -n 's/.*bedrock-server-\([0-9.]*\)\.zip/\1/p')
    # TODO: Check to see if download worked properly.

    # Compute future .zip file
    local zipFilename
    zipFilename=$(basename "$downloadURL" .zip)

    # Get current installed version
    local currentVersion=$(ls $SERVER_DIR/bedrock-server-* | sed -n 's/.*bedrock-server-\([0-9.]*\)/\1/p')

    # Compare versions
    if [[ "$newVersion" != "$currentVersion" ]]; then
        # New version found
        rm $versionFile
        wget -O "$tmpDIR/$zipFilename.zip" "$downloadURL"
        unzip -ou "$tmpDIR/$zipFilename.zip" -d "$tmpDIR"
        rsync -av --exclude='permissions.json' \
            --exclude='server.properties' \
            --exclude='allowlist.json' \
            --exclude='*.zip' \
            "$tmpDIR/" "$SERVER_DIR"
        mv "$SERVER_DIR/bedrock_server" "$SERVER_DIR/bedrock-server-$newVersion"
    fi

    # Clean up temp folder
    rm -rf "$tmpDIR"
}

checkServer