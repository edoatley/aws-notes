from sentence_transformers import SentenceTransformer, util
import torch

def main():
    """
    Demonstrates how to generate and compare sentence embeddings.
    """
    # 1. Load a pre-trained embedding model.
    # 'all-MiniLM-L6-v2' is a popular, high-quality model that runs efficiently on CPU.
    # The library will download the model on its first run.
    print("Loading embedding model...")
    model = SentenceTransformer('all-MiniLM-L6-v2')
    print("Model loaded.")

    # 2. Define a corpus of sentences to be our "database".
    corpus = [
        'A man is eating food.',
        'A man is riding a horse.',
        'A woman is walking her dog on the beach.',
        'Two men are playing chess.',
        'A man is riding a bike.',
        'The new movie is awesome.',
        'The cat is playing with a ball.',
        'A girl is styling her hair.'
    ]

    # 3. Generate embeddings for the entire corpus.
    # The model.encode() method converts the list of sentences into a tensor of vectors.
    print("\nGenerating embeddings for the corpus...")
    corpus_embeddings = model.encode(corpus, convert_to_tensor=True)
    print(f"Shape of corpus embeddings tensor: {corpus_embeddings.shape}")

    # 4. Define a query and generate its embedding.
    query = "A man is riding an animal."
    print(f"\nQuery: '{query}'")
    query_embedding = model.encode(query, convert_to_tensor=True)

    # 5. Calculate cosine similarity between the query and all corpus sentences.
    # The util.cos_sim function performs this calculation efficiently.
    cosine_scores = util.cos_sim(query_embedding, corpus_embeddings)[0]

    # 6. Find the most similar sentence.
    # We use torch.argmax to find the index of the highest score.
    most_similar_idx = torch.argmax(cosine_scores)
    print("\n--- Search Results ---")
    print(f"Most similar sentence in corpus: '{corpus[most_similar_idx]}'")
    print(f"Similarity score: {cosine_scores[most_similar_idx]:.4f}")

if __name__ == "__main__":
    main()