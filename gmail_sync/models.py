from dataclasses import dataclass
from typing import List


@dataclass
class Attachment:
    id: str
    filename: str | None
    mime_type: str | None
    data: bytes


@dataclass
class Message:
    id: str
    thread_id: str
    from_address: str
    subject: str
    recieved_date: int
    attachments: List[Attachment]
