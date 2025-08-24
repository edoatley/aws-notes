from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_openai import ChatOpenAI
from langchain.prompts import PromptTemplate
from langchain.chains import LLMChain
import os

# Define constants
EMBEDDING_MODEL_NAME = 'all-MiniLM-L6-v2'
VECTOR_STORE_PATH = '/Users/edoatley/source/aws-notes/ai/week6/my_faiss_index'
LLM_MODEL_NAME = 'gpt-4o'

def main():
    """
    Runs an interactive RAG chatbot from the command line.
    """
    # Check if the vector store exists
    if not os.path.exists(VECTOR_STORE_PATH):
        print(f"Error: Vector store not found at '{VECTOR_STORE_PATH}'.")
        print("Please run the week6_create_db.py script first.")
        return

    # 1. Load the existing vector store and embedding model
    print("Loading vector store and embedding model...")
    embeddings = HuggingFaceEmbeddings(model_name=EMBEDDING_MODEL_NAME)
    db = FAISS.load_local(VECTOR_STORE_PATH, embeddings, allow_dangerous_deserialization=True)
    print("Vector store and model loaded.")

    # Create a retriever object from the vector store
    retriever = db.as_retriever(search_kwargs={"k": 3}) # Retrieve top 3 chunks

    # 2. Initialize the LLM
    print(f"Initializing LLM '{LLM_MODEL_NAME}'...")
    llm = ChatOpenAI(model_name=LLM_MODEL_NAME, temperature=0.7)

    # 3. Create the prompt template (The "Augment" step)
    prompt_template = """
    You are a helpful assistant. Use the following pieces of context to answer the user's question at the end.
    Provide a concise and clear answer based only on the provided context.
    If the information is not in the context, just say that you don't know the answer from the provided document.

    Context:
    {context}

    Question: {question}

    Answer:
    """
    prompt = PromptTemplate(template=prompt_template, input_variables=["context", "question"])

    # Create a simple chain to combine these steps
    # This is a basic way to implement the RAG logic.
    # More advanced methods use `RunnableSequence` in modern LangChain.
    def answer_query(query):
        # Retrieve relevant documents
        docs = retriever.invoke(query)
        context_text = "\n---\n".join([doc.page_content for doc in docs])

        # Format the prompt
        formatted_prompt = prompt.format(context=context_text, question=query)

        # Generate the response
        response = llm.invoke(formatted_prompt)
        return response.content


    # 4. Create an interactive loop
    print("\n--- RAG Chatbot Initialized ---")
    print("Ask a question about your document. Type 'exit' to quit.")
    while True:
        user_query = input("\nYour Question: ")
        if user_query.lower() == 'exit':
            break

        print("... retrieving context and generating answer...")
        # Get the answer from our RAG chain
        answer = answer_query(user_query)
        print(f"\nAnswer: {answer}")

if __name__ == "__main__":
    main()