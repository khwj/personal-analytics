import json
import logging
import os

import functions_framework
from google_auth_oauthlib.flow import Flow
from google.cloud import error_reporting
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials as OAuth2Credentials
from googleapiclient.discovery import build

from state_manager import FirestoreStateManager
from storage_manager import GoogleCloudStorageManager
from gmail_sync import GmailSync

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logging.basicConfig(level=LOG_LEVEL)

FIRESTORE_DB = os.environ.get('FIRESTORE_DB', 'default')
FIRESTORE_COLLECTION = os.environ.get('FIRESTORE_COLLECTION', 'gmail_sync')
SERVICE_ACCOUNT_KEY_FILE = os.environ.get('SERVICE_ACCOUNT_KEY_FILE')
GMAIL_LABEL_ID = os.environ.get('GMAIL_LABEL_ID')
GMAIL_NOTIFICATIONS_TOPIC = os.environ.get('GMAIL_NOTIFICATIONS_TOPIC')
GMAIL_HISTORY_TYPES = [type.strip() for type in os.environ.get('GMAIL_HISTORY_TYPES', '').split(',')]
GOOGLE_CLIENT_SECRETS_FILE = os.environ.get('GOOGLE_CLIENT_SECRETS_FILE')
GOOGLE_OAUTH_SCOPES = [scope.strip() for scope in os.environ.get('GOOGLE_OAUTH_SCOPES', '').split(',')]
GOOGLE_OAUTH_REDIRECT_URI = os.environ.get('GOOGLE_OAUTH_REDIRECT_URI', '')
GOOGLE_CREDENTIALS_DOCUMENT_ID = os.environ.get('GOOGLE_CREDENTIALS_DOCUMENT_ID',
                                                'google_credentials')
DESTINATION_BUCKET_NAME = os.environ.get('DESTINATION_BUCKET_NAME')
DESTINATION_BASE_PATH = os.environ.get('DESTINATION_BASE_PATH')
SYNC_STATE_DOCUMENT_ID = os.environ.get('SYNC_STATE_DOCUMENT_ID')


@functions_framework.http
def download_attachments_handler(request):
    reporting_client = error_reporting.Client()
    try:
        state_store = FirestoreStateManager(
            database=FIRESTORE_DB,
            collection=FIRESTORE_COLLECTION,
            service_account_file=SERVICE_ACCOUNT_KEY_FILE,
        )
        gcs_store = GoogleCloudStorageManager(
            bucket=DESTINATION_BUCKET_NAME,
            service_account_file=SERVICE_ACCOUNT_KEY_FILE,
        )
        gmail_sync = GmailSync(
            state_store=state_store,
            storage=gcs_store,
            base_path=DESTINATION_BASE_PATH,
            credentials_doc_id=GOOGLE_CREDENTIALS_DOCUMENT_ID,
            sync_state_doc_id=SYNC_STATE_DOCUMENT_ID
        )
        return gmail_sync.sync(
            label_id=GMAIL_LABEL_ID,
            history_types=GMAIL_HISTORY_TYPES,
        )
    except Exception:
        reporting_client.report_exception()

@functions_framework.http
def callback_handler(request):
    reporting_client = error_reporting.Client()
    try:
        code = request.args.get('code')
        if not code:
            return "Code not found the request url"

        flow = Flow.from_client_secrets_file(
            client_secrets_file=GOOGLE_CLIENT_SECRETS_FILE,
            scopes=GOOGLE_OAUTH_SCOPES,
            redirect_uri=GOOGLE_OAUTH_REDIRECT_URI
        )
        flow.fetch_token(code=code)
        creds = flow.credentials
        state_store = FirestoreStateManager(
            database=FIRESTORE_DB,
            collection=FIRESTORE_COLLECTION,
            service_account_file=SERVICE_ACCOUNT_KEY_FILE,
        )
        status = state_store.set_document_by_id(
            GOOGLE_CREDENTIALS_DOCUMENT_ID,
            json.loads(creds.to_json())
        )
        return f"Successfully retrieved access token <br/>{status}"

    except Exception:
        reporting_client.report_exception()


@functions_framework.http
def refresh_token_handler(request):
    reporting_client = error_reporting.Client()
    try:
        state_store = FirestoreStateManager(
            database=FIRESTORE_DB,
            collection=FIRESTORE_COLLECTION,
            service_account_file=SERVICE_ACCOUNT_KEY_FILE,
        )
        creds_doc = state_store.get_document_by_id(GOOGLE_CREDENTIALS_DOCUMENT_ID)
        creds = OAuth2Credentials.from_authorized_user_info(creds_doc)
        creds.refresh(Request())
        status = state_store.set_document_by_id(
            GOOGLE_CREDENTIALS_DOCUMENT_ID,
            json.loads(creds.to_json())
        )
        return f"Token is successfully refreshed <br/>{status}"
    except Exception:
        reporting_client.report_exception()


@functions_framework.http
def renew_watch_handler(request):
    reporting_client = error_reporting.Client()
    try:
        state_store = FirestoreStateManager(
            database=FIRESTORE_DB,
            collection=FIRESTORE_COLLECTION,
            service_account_file=SERVICE_ACCOUNT_KEY_FILE,
        )
        creds_doc = state_store.get_document_by_id(GOOGLE_CREDENTIALS_DOCUMENT_ID)
        creds = OAuth2Credentials.from_authorized_user_info(creds_doc)
        gmail = build('gmail', 'v1', credentials=creds)
        watch_request = {
            'labelIds': [GMAIL_LABEL_ID],
            'topicName': GMAIL_NOTIFICATIONS_TOPIC,
            'labelFilterBehavior': 'INCLUDE'
        }
        return gmail.users().watch(userId='me', body=watch_request).execute()
    except Exception:
        reporting_client.report_exception()
