import logging
from abc import ABC, abstractmethod
from typing import Optional, Any, Dict

from google.cloud.storage import Client as GCSClient


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

    def __init__(self, client: GCSClient, bucket: str):
        # self.__storage = client
        self.__bucket = client.bucket(bucket_name=bucket)

    def put(self, key: str, data: Any, metadata: Optional[Dict] = None) -> None:
        try:
            blob = self.__bucket.blob(key)
            if metadata:
                blob.metadata = metadata
            blob.upload_from_string(data)
            logger.info(f"Data stored with key: {key}")
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
