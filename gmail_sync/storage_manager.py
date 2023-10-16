import logging
from abc import ABC, abstractmethod
from typing import Optional, Any, Dict

from google.cloud.storage import Client as GCSClient
from google.oauth2.service_account import Credentials as ServiceAccountCredentials


logger = logging.getLogger(__name__)


class StorageManager(ABC):
    """Abstract base class for storage managers."""

    @abstractmethod
    def put(self, key: str, data: Any, metadata: Optional[Dict] = None) -> None:
        """Stores the provided data associated with the key, and optionally, metadata."""
        pass

    @abstractmethod
    def get(self, key: str) -> Any:
        """Retrieves the data associated with the key."""
        pass


class GoogleCloudStorageManager(StorageManager):
    """StorageManager for Google Cloud Storage."""

    def __init__(self, bucket: str,
                 service_account_file: Optional[str] = None,
                 client: Optional[GCSClient] = None):

        if not client and not service_account_file:
            raise RuntimeError("Neither authorized_user_json_file or client is provided")
        if not client:
            creds = ServiceAccountCredentials.from_service_account_file(service_account_file)
            client = GCSClient(credentials=creds)
        self.__bucket = client.bucket(bucket_name=bucket)

    def put(self, key: str, data: Any, metadata: Optional[Dict] = None) -> None:
        try:
            blob = self.__bucket.blob(key)
            if metadata:
                blob.metadata = metadata
            blob.upload_from_string(data)
            logger.info(f"Blob saved with key: {key}")
        except Exception as e:
            raise RuntimeError(f"Error storing data with key {key}: {str(e)}") from e

    def get(self, key: str) -> Any:
        try:
            blob = self.__bucket.get_blob(key)
            if not blob:
                raise RuntimeError(f"No data found for key: {key}")
            return blob
        except Exception as e:
            raise RuntimeError(f"Error retrieving data with key {key}: {str(e)}") from e
