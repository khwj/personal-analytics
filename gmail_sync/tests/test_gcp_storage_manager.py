import unittest
from unittest.mock import Mock, patch

from storage_manager import GoogleCloudStorageManager


class TestGoogleCloudStorageManager(unittest.TestCase):
    
    @patch("google.cloud.storage.Client")
    def setUp(self, mock_gcs_client):
        # Mocking GCSClient and Bucket in setUp method
        self.mock_bucket = Mock()
        mock_gcs_client.bucket.return_value = self.mock_bucket
        
        self.bucket_name = "test_bucket"
        self.storage_manager = GoogleCloudStorageManager(client=mock_gcs_client, bucket=self.bucket_name)

    def test_put_data(self):
        mock_blob = Mock()
        self.mock_bucket.blob.return_value = mock_blob
        key = "test_key"
        data = b"test_data"
        metadata = {"key": "value"}
        self.storage_manager.put(key, data, metadata)
        
        self.mock_bucket.blob.assert_called_once_with(key)

    def test_get_data(self):
        mock_blob = Mock()
        self.mock_bucket.get_blob.return_value = mock_blob
        key = "test_key"
        
        retrieved_blob = self.storage_manager.get(key)
        self.mock_bucket.get_blob.assert_called_once_with(key)
        self.assertEqual(retrieved_blob, mock_blob)

    def test_get_data_nonexistent_key(self):
        # Return None to simulate non-existing blob
        self.mock_bucket.get_blob.return_value = None
        key = "nonexistent_key"
        
        with self.assertRaises(RuntimeError):
            _ = self.storage_manager.get(key)


# Running the tests
if __name__ == "__main__":
    unittest.main()
