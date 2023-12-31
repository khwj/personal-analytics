from datetime import datetime
import logging
from abc import ABC, abstractmethod
from enum import Enum
from dataclasses import dataclass
from typing import Dict

from google.cloud.firestore import Client as FirestoreClient
from google.oauth2.service_account import Credentials as ServiceAccountCredentials


logger = logging.getLogger(__name__)


@dataclass
class SyncState:
    historyId: str
    updatedTime: int


@dataclass
class WriteResult:
    class Status(Enum):
        SUCCESS = 0
        FAILED = 1

    status: Status
    update_time: datetime
    message: str


class StateManager(ABC):

    @abstractmethod
    def get_document_by_id(self, id: str) -> Dict:
        pass

    @abstractmethod
    def set_document_by_id(self, id: str, data: Dict) -> WriteResult:
        pass


class FirestoreStateManager(StateManager):

    def __init__(self,
                 collection: str,
                 database: str = 'default',
                 service_account_file: str = None):

        creds = None
        if service_account_file:
            creds = ServiceAccountCredentials.from_service_account_file(service_account_file)
        self.db = FirestoreClient(database=database, credentials=creds)
        self.collection = collection

    def get_document_by_id(self, id: str) -> Dict:
        try:
            doc_ref = self.db.collection(self.collection).document(id)
            if not doc_ref.get().exists:
                raise RuntimeError(f"Document `{id}` not found in `{self.collection}`")
            return doc_ref.get().to_dict()
        except Exception as e:
            raise RuntimeError(f"Error fetching document {id}: {str(e)}") from e

    def set_document_by_id(self, id: str, data: dict) -> WriteResult:
        try:
            doc_ref = self.db.collection(self.collection).document(id)
            result = doc_ref.set(data)
            update_time = datetime.fromtimestamp(result.update_time.timestamp())
            return WriteResult(
                status=WriteResult.Status.SUCCESS,
                update_time=update_time,
                message=str(result)
            )
        except Exception as e:
            logger.error(f"Error writing document {id}: {str(e)}")
            return WriteResult(
                status=WriteResult.Status.FAILED,
                message=str(e)
            )
