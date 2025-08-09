import calendar, time, logging, google.auth, os.path
from datetime import datetime
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from googleapiclient.errors import HttpError

# If modifying these scopes, delete the file token.json.
SCOPES = ["https://www.googleapis.com/auth/drive"]
logger = logging.getLogger(__name__)


def authenticate():
  creds = None
  # The file token.json stores the user's access and refresh tokens, and is
  # created automatically when the authorization flow completes for the first
  # time.
  if os.path.exists("token.json"):
    creds = Credentials.from_authorized_user_file("token.json", SCOPES) # TODO Get token from config file
  # If there are no (valid) credentials available, let the user log in.
  if not creds or not creds.valid:
    if creds and creds.expired and creds.refresh_token:
      creds.refresh(Request())
    else:
      flow = InstalledAppFlow.from_client_secrets_file(
          "credentials.json", SCOPES # TODO Get credentials path from config file
      )
      creds = flow.run_local_server(port=0)
    # Save the credentials for the next run
    with open("token.json", "w") as token:
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
   # List folders in the folder
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
        # Get the time in a format datetime package can understand
        current_file_time = mod_time[:-5].replace(".", ":").replace('T', ' ')
        # Convert time to epoch and store in item dict
        item['modifiedTime'] = calendar.timegm(time.strptime(current_file_time, '%Y-%m-%d %H:%M:%S'))
        if oldest_file == None:
          oldest_file = item
        elif item['modifiedTime'] < oldest_file['modifiedTime']:
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
  
  backup_folder_id = get_folder_id_from_name(service, "Backups") # TODO Get backups name from config folder
  oldest_file = oldest_file_in_folder(service, backup_folder_id)
  
  delete_file(service, oldest_file['id'])

  local_file_path = "" # TODO make local_file_path a part of the config file
  name = datetime.today().strftime('%Y-%m-%d')
  new_folder = create_folder(service, name, backup_folder_id)
  upload_folder(service, new_folder, local_file_path)
  logger.info("Finished script")

def configure_logger():
  logging.basicConfig(filename='pythonBackupScript.log', level=logging.INFO)
  logger.info('Started script')

if __name__ == "__main__":
  creds = authenticate()
  try:
    service = build("drive", "v3", credentials=creds)
    upload_backup_folder(service)
  except HttpError as e:
    logger.critical(f"Error occured: {e}")
