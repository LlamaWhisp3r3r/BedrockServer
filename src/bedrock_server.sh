#!/bin/bash
maintenance_dir="$1"
config_file="${2:-$maintenance_dir/config.json}"
if [[ ! -f $config_file ]]; then
    echo "Could not find config.json at $config_file"
    exit 1
fi
server_dir=$(jq -r '.script.server_dir // empty' $config_file)
version_file=$(jq -r '.script.version_file // empty' $config_file)
tmp_dir=$(jq -r '.script.tmp_dir // empty' $config_file)
log_file=$(jq -r '.script.log_file // empty' $config_file)
backup_folder=$(jq -r '.script.backup_folder // empty' $config_file)
discord_enabled=$(jq -r '.script.discord_enabled // empty' $config_file)
google_enabled=$(jq -r '.script.google_enabled // empty' $config_file)
venv_path=$(jq -r '.script.venv_path // empty' $config_file)
criticalLevel="CRITICAL"
infoLevel="INFO"
warningLevel="WARNING"

log() {
    # Check if logs and log file exists. If not, create them
    if [[ ! -d "$maintenance_dir/logs" ]]; then
        mkdir "$maintenance_dir/logs"
    fi
    if [[ ! -f "$log_file" ]]; then
        touch "$log_file"
    fi

    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$log_file"
}

checkGlobalVariables() {

    # Check server_dir was provided and exists
    if [[ -z "$server_dir" || ! -d "$server_dir" ]]; then
        log "$criticalLevel" "No server_dir provided or it doesn't exist."
        exit 1
    fi

    if [[ -z "$maintenance_dir" ]]; then
        maintenance_dir="$server_dir/maintenance"
    elif [[ ! -d "$maintenance_dir" ]]; then
        log "$criticalLevel" "$maintenance_dir does not exist!"
        exit 1
    fi

    # Check version_file
    if [[ -n "$version_file" ]]; then
        version_file="$version_file"
    else
        # Check if file exist in the default directory
        files=( "$server_dir"/bedrock-server-* )
        if [[ -e "${files[0]}" ]]; then
            version_file="${files[0]}"
        else
            log "$criticalLevel" "No version file found in $server_dir"
            exit 1
        fi
    fi

    # Check tmp_dir
    if [[ -z "$tmp_dir" ]]; then
        tmp_dir="$maintenance_dir/tmp"
    fi

    # Check log_file
    if [[ -z "$log_file" ]]; then
        log_file="$maintenance_dir/logs/server.log"
    fi

    # Check back_folder
    if [[ -z "$backup_folder" ]]; then
        backup_folder="$maintenance_dir/backups"
    fi

    # Check discord_enabled
    if [[ -z "$discord_enabled" ]]; then
        discord_enabled=false
    fi

    # Check google_enabled
    if [[ -z "$google_enabled" ]]; then
        google_enabled=false
    fi

    # Check tmp_dir
    if [[ -z "$tmp_dir" ]]; then
        tmp_dir="$maintenance_dir/venv"
    fi

}

sendDiscord() {
    local message="$2"
    if [ "$discord_enabled" = true ]; then
        log "$infoLevel" "Sending discord message, $message"
        source "$venv_path/bin/activate"
        python discord_handler.py "$config_file" "$message"
    fi
}

checkServer() {
    # Check if server is already running
    if tmux has-session -t minecraftserver 2>/dev/null; then
        checkRestartTime
    else
        # Start server if it stopped for some reason
        log "$warningLevel" "Server is not running when it's expected to be. Trying to start again."
        startServer
    fi
}

startServer() {
    # Start a new tmux session running the bedrock server
    tmux new-session -d -s minecraftserver -c "$server_dir" "LD_LIBRARY_PATH=$server_dir $version_file"

    sleep 3

    if ! tmux has-session -t minecraftserver 2>/dev/null; then
        # TODO: server did not start correctly. Send error message
        local errorMessage="Server did not start correctly."
        log "$criticalLevel" "$errorMessage"
        sendDiscord "$errorMessage"
        return 1
    fi
    log "$infoLevel" "Server started correctly."
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
    log "$infoLevel" "Server will restart in $restartMins."
    tmux send-keys -t minecraftserver 'tellraw @a {"rawtext":[{"text":"[§6server§r] §4Realm will restart in '"$restartMins"' minutes"}]}' C-m
}

restartServer() {
    tmux send-keys -t minecraftserver "stop" C-m
    sleep 3
    # Check if server is already running
    if tmux has-session -t minecraftserver 2>/dev/null; then
        # Server did not stop properly
        local errorMessage="Server did not stop properly."
        log "$criticalLevel" "$errorMessage"
        sendDiscord "$errorMessage"
        exit 1
    else
        downloadLatestBedrock
        backupServer
        if [ "$google_enabled" = true ]; then
            log "$infoLevel" "Backing up server to Google Drive."
            source "$venv_path/bin/activate"
            python google_drive_handler.py "$config_file"
        fi
    fi
    startServer
}

downloadLatestBedrock() {
    # Check if tmp folder is there and clear it if it is
    if [[ ! -d "$tmp_dir" ]]; then
        mkdir -p "$tmp_dir"
    else
        # Clean up temp folder
        rm -rf "$tmp_dir"
    fi

    # Fetch download URL from Mojang's official site using chromium
    local downloadURL
    downloadURL=$(chromium --mute-audio --log-level=3 --headless --disable-gpu --dump-dom -no-sandbox --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36" "https://www.minecraft.net/en-us/download/server/bedrock" | grep -Eo 'https://www\.minecraft\.net/bedrockdedicatedserver/bin-linux/bedrock-server-[0-9.]+\.zip')
    local newVersion=$(echo "$downloadURL" | sed -n 's/.*bedrock-server-\([0-9.]*\)\.zip/\1/p')
    # Check if it was able to get new version
    if [[ -z "$downloadURL" ]]; then
        # Could not get new version number
        log "$warningLevel" "Could not download new version number from Minecraft website."
        return 1
    else
        # Compute future .zip file
        local zipFilename
        zipFilename=$(basename "$downloadURL" .zip)

        # Get current installed version
        local currentVersion=$(ls "$server_dir"/bedrock-server-* | sed -n 's/.*bedrock-server-\([0-9.]*\)/\1/p')

        # Compare versions
        if [[ "$newVersion" != "$currentVersion" ]]; then
            # New version found
            rm "$version_file"
            if ! wget -O "$tmp_dir/$zipFilename.zip" "$downloadURL"; then
                log "$criticalLevel" "Failed to download $downloadURL"
                return 1
            fi
            if [ ! -s "$tmp_dir/$zipFilename.zip" ]; then
                log "$criticalLevel" "Downloaded file is empty: $zipFilename.zip"
                return 1
            fi
            unzip -ou "$tmp_dir/$zipFilename.zip" -d "$tmp_dir"
            rsync -av --exclude='permissions.json' \
                --exclude='server.properties' \
                --exclude='allowlist.json' \
                --exclude='*.zip' \
                "$tmp_dir/" "$server_dir"
            mv "$server_dir/bedrock_server" "$server_dir/bedrock-server-$newVersion"
            log "$infoLevel" "Downloaded and installed new server version: $newVersion."
        fi
        log "$infoLevel" "Current version: $currentVersion is the same as new version: $newVersion."
    fi
}

backupServer() {
    if [[ ! -d "$backup_folder" ]]; then
        mkdir "$backup_folder"
    fi

    # Backup server
    tar --exclude='maintenance' --exclude='logs' -czf "$backup_folder/bedrock-server-backup-$(date +%Y-%m-%d_%H-%M-%S).tar.gz" -C "$server_dir" .
    log "$infoLevel" "Backed up server."
}

if checkGlobalVariables; then
    startServer
fi