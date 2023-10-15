import logging
import os
import subprocess
import threading
import unittest

from state_manager import FirestoreStateManager, SyncState, WriteResult


logger = logging.getLogger(__name__)


TEST_FIRESTORE_HOST = 'localhost:8143'


class FirestoreStateStoreIntegrationTest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Start the Firestore emulator as a subprocess
        cls.emulator_process = subprocess.Popen([
            "gcloud",
            "emulators",
            "firestore",
            "start",
            f"--host-port={TEST_FIRESTORE_HOST}"
        ], stderr=subprocess.PIPE, stdout=subprocess.PIPE, close_fds=True)

        # Give a few seconds to allow the emulator to start up... if its necessary
        # time.sleep(5)
        logger.info(cls.emulator_process.stdout)

        os.environ["FIRESTORE_EMULATOR_HOST"] = TEST_FIRESTORE_HOST
        os.environ["GCLOUD_PROJECT"] = "test-project"
        cls.firestore_state_store = FirestoreStateManager(collection="test-collection")

    @classmethod
    def tearDownClass(cls):
        # Clean up the Firestore emulator subprocess
        cls.emulator_process.terminate()
        cls.emulator_process.wait()

    def test_set_and_get_document(self):
        test_id = "test_id"
        test_data = SyncState(historyId="12345", updatedTime=1616885415)

        write_result = self.firestore_state_store.set_document_by_id(test_id, vars(test_data))
        self.assertEqual(write_result.status, WriteResult.Status.SUCCESS)

        fetched_data = self.firestore_state_store.get_document_by_id(test_id)
        self.assertDictEqual(fetched_data, vars(test_data))

    def test_get_nonexistent_document(self):
        non_existent_id = "non_existent_id"

        with self.assertRaises(RuntimeError):
            _ = self.firestore_state_store.get_document_by_id(non_existent_id)

    def test_special_characters_in_id(self):
        special_char_id = "test_id_!@#$%^&*()"
        test_data = SyncState(historyId="12345", updatedTime=1616885415)

        write_result = self.firestore_state_store.set_document_by_id(
            special_char_id,
            vars(test_data)
        )
        self.assertEqual(write_result.status, WriteResult.Status.SUCCESS)

        fetched_data = self.firestore_state_store.get_document_by_id(special_char_id)
        self.assertDictEqual(fetched_data, vars(test_data))

    def test_concurrent_write(self):
        test_id = "test_concurrent_write"
        test_data_1 = SyncState(historyId="11111", updatedTime=1616885415)
        test_data_2 = SyncState(historyId="22222", updatedTime=1616885416)

        def write_data_1():
            self.firestore_state_store.set_document_by_id(test_id, vars(test_data_1))

        def write_data_2():
            self.firestore_state_store.set_document_by_id(test_id, vars(test_data_2))

        # Simulating concurrent writes
        thread_1 = threading.Thread(target=write_data_1)
        thread_2 = threading.Thread(target=write_data_2)

        thread_1.start()
        thread_2.start()

        thread_1.join()
        thread_2.join()

        # The result should be one of the written data
        fetched_data = self.firestore_state_store.get_document_by_id(test_id)
        self.assertTrue(fetched_data == vars(test_data_1) or fetched_data == vars(test_data_2))


if __name__ == "__main__":
    unittest.main()
