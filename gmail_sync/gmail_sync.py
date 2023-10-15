import logging
import os
import re
import uuid
from datetime import datetime
from typing import Dict, List, Optional

from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

from state_manager import StateManager, SyncState
from storage_manager import StorageManager
from models import Attachment, Message


logger = logging.getLogger(__name__)


ADDRESS_PATTERN = re.compile(r'\<([^\>]+)\>')
EMAIL_PATTERNS = {
    'statement@centralthe1card.com': {
        'pattern': re.compile(r'\((?P<dom>\d\d)/(?P<month>\d\d)/(?P<year>\d{4})\)'),
        'path': 'centralthe1card/statement_date={}/{}'
    },
    'statement@firstchoicecard.com': {
        'pattern': re.compile(r'\((?P<dom>\d\d)/(?P<month>\d\d)/(?P<year>\d{4})\)'),
        'path': 'firstchoicecard/statement_date={}/{}'
    },
}


class GmailSync:
    def __init__(self,
                 state_store: StateManager,
                 storage: StorageManager,
                 gmail_client: Optional[build] = None,
                 base_path: str = '',
                 credentials_cache_path: str = 'token.json',
                 credentials_doc_id: str = 'google_credentials',
                 sync_state_doc_id: str = 'last_sync_state'):
        """
        Initialization of GmailSync class.

        Parameters:
        - state_store (StateManager): An instance of StateManager to manage states.
        - storage (StorageManager): An instance of StorageManager to manage storage.
        - gmail_client (build): An optional instance of Gmail client, defaults to None.
        - base_path (str): The base path, defaults to an empty string.
        - credentials_cache_path (str): Path to credentials cache, defaults to 'token.json'.
        - credentials_doc_id (str): Document ID of credentials, defaults to 'google_credentials'.
        - sync_state_doc_id (str): Document ID of sync state, defaults to 'last_sync_state'.
        """

        self.__state_store = state_store
        self.__storage = storage
        self.__base_path = base_path.strip('/')
        self.__sync_state_doc_id = sync_state_doc_id
        self.__credentials_doc_id = credentials_doc_id

        if not gmail_client:
            self.__init_gmail_client(credentials_cache_path, credentials_doc_id)
        self.__gmail = gmail_client

    def __init_gmail_client(self, credentials_cache_path, credentials_doc_id) -> build:
        """
        Initialize Gmail client.

        Parameters:
        - cache_path (str): Path to cache.
        - credentials_doc_id (str): Document ID of credentials.

        Returns:
        build: Gmail client.
        """
        creds = None
        try:
            if os.path.exists(credentials_cache_path):
                creds = Credentials.from_authorized_user_file('token.json')
            if not creds or not creds.valid or creds.expired:
                creds_doc = self.__state_store.get_document_by_id(credentials_doc_id)
                creds = Credentials.from_authorized_user_info(creds_doc)
                with open(credentials_cache_path, 'w') as token:
                    token.write(creds.to_json())
        except Exception as e:
            raise RuntimeError("Failed to initialize Gmail client.") from e

        return build('gmail', 'v1', credentials=creds)

    def __get_last_history_id(self) -> str:
        last_state = self.__state_store.get_document_by_id(self.__sync_state_doc_id)
        return last_state['historyId']

    def __save_history_id(self, history_id: str):
        ts = datetime.now()
        sync_state = SyncState(historyId=history_id, updatedTime=int(ts.strftime('%s')))
        result = self.__state_store.set_document_by_id(
            id=self.__sync_state_doc_id,
            data=vars(sync_state)
        )
        updated_ts = datetime.fromtimestamp(result.update_time.timestamp())
        return {'took': (updated_ts - ts).microseconds}

    def __get_save_path(self, from_addr, subject, filename):
        """Determine the save path based on sender addresses and subject patterns."""
        config = EMAIL_PATTERNS.get(from_addr.lower())
        if config:
            parts = config['pattern'].search(subject)
            if parts:
                partition = f"{parts['year']}-{parts['month']}-{parts['dom']}"
                return config['path'].format(partition, filename)

        # Default path if no pattern match
        return f'unmatched_documents/from={from_addr}/{uuid.uuid4()}_{filename}'

    def __save_message_attachments(self, msg: Message) -> None:
        """Save message attachments based on sender and subject."""
        from_addr = msg.from_address.lower()

        for attachment in msg.attachments:
            save_path = self.__get_save_path(from_addr, msg.subject, attachment.filename)
            metadata = {
                'subject': msg.subject,
                'from': from_addr,
                'recievedDate': msg.recieved_date,
                'filename': attachment.filename,
                'mimeType': attachment.mime_type,
                'gmailMessageID': msg.id,
                'gmailThreadID': msg.thread_id,
                'attachmentId': attachment.id,
            }
            destination = f"{self.__base_path}/{save_path}"
            self.__storage.put(key=destination, data=attachment.data, metadata=metadata)
            logger.info(f"File '{attachment.filename}' saved at '{destination}'")

    def __download_attachment(self, message_id: str, attachment_id: str, user_id='me'):
        import base64

        attachment_resp = self.__gmail.users().messages().attachments().get(
            userId=user_id,
            messageId=message_id,
            id=attachment_id,
        ).execute()
        return base64.urlsafe_b64decode(attachment_resp.get('data'))

    def __extract_attachment_info(self, message: Dict) -> List[Dict]:
        attachments = []

        def traverse_parts(parts):
            for part in parts:
                if part.get('body', {}).get('attachmentId'):
                    attachment_id = part['body']['attachmentId']
                    attachments.append({
                        'filename': part.get('filename', ''),
                        'mimeType': part.get('mimeType', ''),
                        'attachmentId': attachment_id,
                    })

                # Recursively check if there are nested parts
                if part.get('parts'):
                    traverse_parts(part['parts'])

        # Start the traversal with the top-level parts
        if message.get('payload', {}).get('parts'):
            traverse_parts(message['payload']['parts'])

        return attachments

    def get_message(self, msg_id: str) -> Message:
        message_resp = self.__gmail.users().messages().get(userId='me', id=msg_id).execute()
        headers = message_resp.get('payload', {}).get('headers')
        subject = next((item['value'] for item in headers if item['name'] == 'Subject'), None)
        sender = next((item['value'] for item in headers if item['name'] == 'From'), None)
        sender_found = ADDRESS_PATTERN.search(sender)
        attachment_info = self.__extract_attachment_info(message_resp)
        attachments = []
        for attachment in attachment_info:
            data = self.__download_attachment(
                msg_id, attachment_id=attachment['attachmentId'],
                user_id='me'
            )
            attachments.append(Attachment(
                id=attachment['attachmentId'],
                filename=attachment['filename'],
                mime_type=attachment['mimeType'],
                data=data
            ))

        return Message(
            id=msg_id,
            thread_id=message_resp.get('threadId'),
            subject=subject,
            from_address=sender_found.group(sender_found.lastindex) if sender_found else sender,
            recieved_date=int(message_resp.get('internalDate')),
            attachments=attachments
        )

    def sync(self,
             label_id: str = 'INBOX',
             history_types: List[str] = ["messageAdded", "labelAdded"],
             start_history_id: str = None) -> None:

        if not start_history_id:
            start_history_id = self.__get_last_history_id()

        logger.info(f"Syncing GMail from {start_history_id} with"
                    + " label_id={label_id}, history_types={history_types}")

        try:
            history_resp = self.__gmail.users().history().list(
                userId='me',
                startHistoryId=start_history_id,
                labelId=label_id,
                historyTypes=history_types
            ).execute()
        except Exception as e:
            logger.error(f"Failed to fetch Gmail history: {str(e)}")
            return

        if 'history' in history_resp:
            next_history_id = history_resp['historyId']
            msg_ids = set()
            for entry in history_resp['history']:
                for message_resp in entry['messages']:
                    msg_ids.add(message_resp['id'])

            for msg_id in msg_ids:
                try:
                    msg = self.get_message(msg_id)
                    self.__save_message_attachments(msg)
                except Exception as e:
                    logger.error(f"Failed to process message {msg_id}: {str(e)}")

            self.__save_history_id(next_history_id)
        else:
            logger.info("Data is already up-to-date")
