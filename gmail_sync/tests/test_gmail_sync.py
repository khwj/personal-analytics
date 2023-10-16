from datetime import datetime
import tempfile
import unittest
from unittest.mock import MagicMock, Mock, patch

from gmail_sync import Attachment, GmailSync, Message
from state_manager import StateManager
from storage_manager import StorageManager


class GmailSyncTest(unittest.TestCase):

    @patch('gmail_sync.build')  # Mocking Gmail API Client
    def setUp(self, mock_gmail_build):
        # Creating mocks for dependencies
        self.mock_storage = Mock(spec=StorageManager)
        self.mock_gmail_client = Mock()
        self.mock_state_store = Mock(spec=StateManager)

        mock_set_document_result = Mock()
        mock_set_document_result.update_time.return_value = datetime.now()
        self.mock_state_store.set_document_by_id.return_value = mock_set_document_result
        mock_gmail_build.return_value = self.mock_gmail_client

        # Initializing GmailSync with mocked dependencies
        self.gmail_sync = GmailSync(
            state_store=self.mock_state_store,
            storage=self.mock_storage,
            gmail_client=self.mock_gmail_client
        )

    @patch("gmail_sync.Credentials")
    @patch("gmail_sync.build")
    @patch('gmail_sync.os.path.exists')
    def test_init_gmail_client(self, mock_exists, mock_build, mock_credentials):
        mock_exists.return_value = False
        mock_build.return_value = Mock()
        mock_creds = MagicMock()
        mock_creds.to_json.return_value = '{"token": "fake_token"}'
        mock_credentials.from_authorized_user_info.return_value = mock_creds
        mock_credentials.from_authorized_user_file.return_value = None

        self.mock_state_store.get_document_by_id.return_value = {
            'client_secret': "MOCK_CLIENT_SECRET",
            'refresh_token': "MOCK_REFRESH_TOKEN",
            'client_id': "MOCK_CLIENT_ID"
        }

        with tempfile.NamedTemporaryFile(delete=True) as temp:
            temp.write(b'some fake credentials')
            cache_path = temp.name
            credentials_doc_id = "credentials_doc_id"

            client = self.gmail_sync._GmailSync__init_gmail_client(cache_path, credentials_doc_id)

            # Assert the Gmail client is built correctly
            mock_credentials = mock_credentials.from_authorized_user_info.return_value
            mock_build.assert_called_once_with('gmail', 'v1', credentials=mock_credentials)
            self.assertEqual(client, mock_build.return_value)

    @patch("gmail_sync.Credentials")
    @patch("gmail_sync.build")
    @patch('gmail_sync.os.path.exists')
    def test_init_gmail_client_when_cache_exists(self, mock_exists, mock_build, mock_credentials):
        mock_exists.return_value = True
        mock_creds = MagicMock()
        mock_creds.valid = True
        mock_creds.expired = False
        mock_credentials.from_authorized_user_file.return_value = mock_creds

        cache_path = 'token.json'
        credentials_doc_id = "credentials_doc_id"
        _ = self.gmail_sync._GmailSync__init_gmail_client(cache_path, credentials_doc_id)

        mock_exists.assert_called_once_with(cache_path)
        mock_credentials.from_authorized_user_file.assert_called_once_with('token.json')
        mock_build.assert_called_once_with('gmail', 'v1', credentials=mock_creds)

    @patch("gmail_sync.Credentials")
    @patch("gmail_sync.build")
    @patch('gmail_sync.os.path.exists')
    def test_init_gmail_client_invalid_credentials(self, mock_exists, mock_build, mock_credentials):
        mock_exists.return_value = True
        mock_creds = MagicMock()
        mock_creds.valid = False
        mock_creds.to_json.return_value = '{"token": "fake_token"}'
        mock_credentials.from_authorized_user_info.return_value = mock_creds
        mock_credentials.from_authorized_user_file.return_value = None

        # Mock methods and attributes
        self.mock_state_store.get_document_by_id.return_value = {
            'client_secret': "MOCK_CLIENT_SECRET",
            'refresh_token': "MOCK_REFRESH_TOKEN",
            'client_id': "MOCK_CLIENT_ID"
        }

        with tempfile.NamedTemporaryFile(delete=True) as temp:
            temp.write(b'some fake credentials')
            cache_path = temp.name
            credentials_doc_id = "credentials_doc_id"

            client = self.gmail_sync._GmailSync__init_gmail_client(cache_path, credentials_doc_id)

            # Assert the Gmail client is built correctly
            mock_credentials = mock_credentials.from_authorized_user_info.return_value
            mock_build.assert_called_once_with('gmail', 'v1', credentials=mock_credentials)
            self.assertEqual(client, mock_build.return_value)

    @patch("gmail_sync.Credentials")
    @patch('gmail_sync.os.path.exists')
    def test_init_gmail_client_missing_credentials(self, mock_exists, mock_credentials):
        mock_exists.return_value = False
        mock_credentials.from_authorized_user_info.side_effect = Exception("Invalid Credentials")

        with self.assertRaises(RuntimeError) as context:
            self.gmail_sync._GmailSync__init_gmail_client('cache_path', 'credentials_doc_id')
        self.assertIn("Failed to initialize Gmail client.", str(context.exception))

    def test_get_message(self):
        self.mock_gmail_client.users().messages().get().execute.return_value = {
            'id': 'msg1',
            'threadId': 'thread1',
            'payload': {
                'headers': [
                    {'name': 'Subject', 'value': 'Test Email'},
                    {'name': 'From', 'value': 'test@example.com'}
                ],
                'parts': []
            },
            'internalDate': '1634047722'
        }
        # Running get_message
        message = self.gmail_sync.get_message(msg_id='msg1')

        # Verifying the returned message and interactions with Gmail API
        self.assertEqual(message.id, 'msg1')
        self.assertEqual(message.from_address, 'test@example.com')
        self.mock_gmail_client.users().messages().get.assert_called_with(userId='me', id='msg1')

    def test_save_message_attachments(self):
        attachment = Attachment(id='att1', filename='file1', mime_type='image/jpeg', data=b'data')
        message = Message(
            id='msg1', thread_id='thread1', from_address='test@example.com',
            subject='Test Email (01/01/2022)', recieved_date=1634047722, attachments=[attachment]
        )
        self.gmail_sync._GmailSync__save_message_attachments(message)
        self.mock_storage.put.assert_called_with(
            key=unittest.mock.ANY,  # UUID will be generated dynamically
            data=attachment.data,
            metadata=unittest.mock.ANY  # Metadata will contain various details
        )

    def test_download_attachment(self):
        # Mocking Gmail API response for attachment download
        self.mock_gmail_client.users().messages().attachments().get().execute.return_value = {
            'data': 'c29tZSBkYXRh'  # 'some data' in base64 url-safe encoding
        }

        # Running __download_attachment
        data = self.gmail_sync._GmailSync__download_attachment('msg1', 'att1')

        # Verifying the returned data and interactions with Gmail API
        self.assertEqual(data, b'some data')
        self.mock_gmail_client.users().messages().attachments().get.assert_called_with(
            userId='me', messageId='msg1', id='att1'
        )

    def test_extract_attachment_info_various_structures(self):
        # Mocking a Gmail API message with nested parts
        message = {
            'payload': {
                'parts': [
                    {'filename': 'file1', 'body': {'attachmentId': 'att1'}},
                    {
                        'mimeType': 'multipart/mixed',
                        'parts': [{'filename': 'file2', 'body': {'attachmentId': 'att2'}}]
                    }
                ]
            }
        }

        attachments = self.gmail_sync._GmailSync__extract_attachment_info(message)

        self.assertEqual(len(attachments), 2)
        self.assertEqual(attachments[0]['filename'], 'file1')
        self.assertEqual(attachments[1]['filename'], 'file2')

    def test_extract_attachment_info_no_attachments(self):
        # Mocking a Gmail API message without attachments
        message = {
            'payload': {
                'parts': [
                    {'mimeType': 'text/plain', 'body': {'data': '...'}},
                    {'mimeType': 'text/html', 'body': {'data': '...'}}
                ]
            }
        }
        attachments = self.gmail_sync._GmailSync__extract_attachment_info(message)
        self.assertEqual(len(attachments), 0)

    def test_sync_with_api_failure(self):
        # Mocking Gmail API failure
        self.mock_gmail_client.users().history().list().execute.side_effect = Exception('API Error')
        # Running sync and verifying that an exception was logged
        with self.assertLogs(level='ERROR') as log:
            self.gmail_sync.sync(label_id='INBOX', start_history_id='12345')
            self.assertIn('API Error', log.output[0])

    def test_sync_no_history(self):
        # Mocking Gmail API response with no history
        self.mock_gmail_client.users().history().list().execute.return_value = {}
        self.gmail_sync.sync(label_id='INBOX', start_history_id='12345')

        # Verifying interactions with mocked Gmail API
        self.mock_gmail_client.users().history().list.assert_called_with(
            userId='me',
            startHistoryId='12345',
            labelId='INBOX',
            historyTypes=['messageAdded', 'labelAdded']
        )

        # Verifying that other methods were not called due to no history
        self.mock_state_store.get_document_by_id.assert_not_called()
        self.mock_state_store.set_document_by_id.assert_not_called()

    def test_sync_with_history(self):
        # Mocking Gmail API response with history
        self.mock_gmail_client.users().history().list().execute.return_value = {
            'history': [
                {'messages': [{'id': 'msg1'}, {'id': 'msg2'}]}
            ],
            'historyId': '12346'
        }

        # Mocking GmailSync.get_message() to avoid actual implementation during test
        mock_message = Message(
            id='msg1', thread_id='thread1', from_address='test@example.com',
            subject='Test Email', recieved_date=1634047722, attachments=[]
        )
        with patch.object(self.gmail_sync, 'get_message', return_value=mock_message):
            with patch.object(self.gmail_sync,
                              '_GmailSync__save_message_attachments') as mock_save_attachments:
                # Running sync
                self.gmail_sync.sync(label_id='INBOX', start_history_id='12345')

                # Verifying interactions with mocked methods
                mock_save_attachments.assert_called_with(mock_message)

        # Verifying that the history ID is saved after sync
        self.mock_state_store.set_document_by_id.assert_called_with(
            id='last_sync_state',
            data={'historyId': '12346', 'updatedTime': unittest.mock.ANY}
        )


# Running the test
if __name__ == "__main__":
    unittest.main()
