from langchain_community.document_loaders import TextLoader
from langchain_text_splitters import CharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
import os
import sys

# Define constants for the model and file paths
EMBEDDING_MODEL_NAME = 'all-MiniLM-L6-v2'
VECTOR_STORE_PATH = 'my_faiss_index'

def main(document_path:str):
    """
    Processes a document and creates a FAISS vector store.
    """
    # 1. Document Loading
    print(f"Loading document from '{document_path}'...")
    loader = TextLoader(document_path)
    documents = loader.load()
    print(f"Document loaded. Contains {len(documents)} part(s).")

    # 2. Text Splitting (Chunking)
    # We split the document into smaller chunks to fit into the model's context window.
    # chunk_size is the max number of characters per chunk.
    # chunk_overlap keeps some characters from the end of the previous chunk
    # at the start of the next one to maintain context.
    print("Splitting document into chunks...")
    text_splitter = CharacterTextSplitter(chunk_size=1000, chunk_overlap=100)
    chunks = text_splitter.split_documents(documents)
    print(f"Document split into {len(chunks)} chunks.")

    # 3. Embedding Model Initialization
    # We use HuggingFaceEmbeddings, a LangChain wrapper for sentence-transformers.
    print(f"Initializing embedding model '{EMBEDDING_MODEL_NAME}'...")
    embeddings = HuggingFaceEmbeddings(model_name=EMBEDDING_MODEL_NAME)

    # 4. Storing
    # FAISS.from_documents() is a convenient method that takes the chunks,
    # generates embeddings for them, and builds the FAISS index in one step.
    print("Creating FAISS vector store from chunks...")
    db = FAISS.from_documents(chunks, embeddings)
    print("Vector store created in memory.")

    # Save the vector store to disk for later use.
    db.save_local(VECTOR_STORE_PATH)
    print(f"Vector store saved to disk at '{VECTOR_STORE_PATH}'.")

if __name__ == "__main__":
    doc_path = sys.argv[1] if len(sys.argv) > 1 else 'week6/my_document.txt'
    if not os.path.exists(doc_path):
        print(f"Error: Document file not found at '{doc_path}'. Please create it.")
    else:
        main(document_path=doc_path)