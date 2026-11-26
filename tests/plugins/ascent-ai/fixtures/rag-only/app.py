"""Search the handbook with local embeddings; no model generates text."""
import chromadb

client = chromadb.PersistentClient(path="index")


def search(query: str) -> list:
    return client.get_collection("handbook").query(query_texts=[query], n_results=5)["documents"][0]
