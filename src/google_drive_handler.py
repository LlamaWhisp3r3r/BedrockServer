import calendar, time, logging, google.auth, os.path, json, sys
from datetime import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from googleapiclient.errors import HttpError

# Ensure a config.json is provided
if len(sys.argv) < 1:
    print("Usage: python google_drive_handler.py config_file")
    sys.exit(1)

config_file = " ".join(sys.argv[1])

# If modifying these scopes, delete the file token.json.
SCOPES = ["https://www.googleapis.com/auth/drive"]
logger = logging.getLogger(__name__)

# Load config from file
def load_config(path=config_file):
    try:
        with open(path, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        logger.critical(f"Config file not found: {path}")
        raise
    except json.JSONDecodeError as e:
        logger.critical(f"Invalid JSON in config file: {e}")
        raise

def set_logging():
  # --- Logging Setup ---
  log_file = config.get("script", {}).get("log_file")

  if not log_file:
      log_file = config.get("script", {}).get("serve_dir") + "/maintenance/logs/server.log"


  logging.basicConfig(
      filename=log_file,
      level=logging.INFO,
      format="%(asctime)s [%(levelname)s] %(message)s"
  )

config = load_config()
set_logging()

def authenticate():
    creds = None
    local_file_path = config.get("script", {}).get("server_dir", "")
    token_path = config.get("google", {}).get("token_path", f"{local_file_path}/maintenance/token.json")
    credentials_path = config.get("google", {}).get("credentials_path", f"{local_file_path}/maintenance/credentials.json")

    if os.path.exists(token_path):
        creds = Credentials.from_authorized_user_file(token_path, SCOPES)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(credentials_path, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(token_path, "w") as token:
            token.write(creds.to_json())

    logger.info("Authenticated with Google")
    return creds

def get_folder_id_from_name(service, folder_name):
    query = f"mimeType='application/vnd.google-apps.folder' and name='{folder_name}'"
    results = service.files().list(q=query, fields="files(id, name)").execute()
    items = results.get('files', [])

    if not items:
        logger.critical(f'No folder named {folder_name} found.')
        return
    else:
        folder_id = items[0]['id']
        logger.info(f'{folder_name} folder ID: %s' % folder_id)
    return folder_id

def oldest_file_in_folder(service, folder_id):
    query = f"'{folder_id}' in parents and mimeType='application/vnd.google-apps.folder'"
    results = service.files().list(q=query, fields="files(id, name, modifiedTime)").execute()
    items = results.get('files', [])

    if not items:
        logging.critical(f'No folders found in the folder: {folder_id}')
    else:
        logger.info(f'Folders in the folder: {folder_id}')
        oldest_file = None
        for item in items:
            mod_time = item['modifiedTime']
            current_file_time = mod_time[:-5].replace(".", ":").replace('T', ' ')
            item['modifiedTime'] = calendar.timegm(time.strptime(current_file_time, '%Y-%m-%d %H:%M:%S'))
            if oldest_file is None or item['modifiedTime'] < oldest_file['modifiedTime']:
                oldest_file = item
    return oldest_file

def delete_file(service, file_id):
    service.files().delete(fileId=file_id).execute()
    logger.info('Deleted file: {0}'.format(file_id))

def create_folder(service, name, parent_id=None):
    folder_metadata = {
        'name': name,
        'mimeType': 'application/vnd.google-apps.folder'
    }
    if parent_id:
      folder_metadata['parents'] = [parent_id]
    folder = service.files().create(body=folder_metadata, fields='id').execute()
    logger.info(f"Created folder with id: {folder.get('id')}")
    return folder.get('id')

def upload_folder(service, parent_folder_id, local_path):
    for item in os.listdir(local_path):
        item_path = os.path.join(local_path, item)
        if os.path.isdir(item_path):
            folder_id = create_folder(service, item, parent_folder_id)
            upload_folder(service, folder_id, item_path)
        else:
            file_metadata = {
                'name': item,
                'parents': [parent_folder_id]
            }
            media = MediaFileUpload(item_path, resumable=True)
            service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            ).execute()
    logger.info("Uploaded Folder")

def upload_backup_folder(service):
    backup_folder_name = config.get("google", {}).get("drive_folder", "Backups")
    local_file_path = config.get("script", {}).get("server_dir", "")

    backup_folder_id = get_folder_id_from_name(service, backup_folder_name)
    oldest_file = oldest_file_in_folder(service, backup_folder_id)

    if oldest_file:
        delete_file(service, oldest_file['id'])

    name = datetime.today().strftime('%Y-%m-%d')
    new_folder = create_folder(service, name, backup_folder_id)
    upload_folder(service, new_folder, local_file_path)
    logger.info("Finished script")

def configure_logger():
    logging.basicConfig(filename='pythonBackupScript.log', level=logging.INFO)
    logger.info('Started script')

if __name__ == "__main__":
    configure_logger()
    creds = authenticate()
    try:
        service = build("drive", "v3", credentials=creds)
        upload_backup_folder(service)
    except HttpError as e:
        logger.critical(f"Error occurred: {e}")