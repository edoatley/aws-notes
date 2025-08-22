from flask import Flask, request, jsonify
from llama_cpp import Llama
import os

# Initialize the Flask app
app = Flask(__name__)

# Path to the model file inside the container
model_path = os.path.join("models", "llama-2-7b-chat.gguf")

# Load the Llama model
# n_gpu_layers=-1 will try to offload all layers to the GPU if available.
# Set to 0 to run on CPU only.
# n_ctx sets the context window size.
print("Loading model...")
llm = Llama(model_path=model_path, n_ctx=4096, n_gpu_layers=0, verbose=False)
print("Model loaded successfully.")

@app.route('/generate', methods=['POST'])
def generate():
    """
    API endpoint to generate text from a prompt.
    Expects a JSON payload with a 'prompt' key.
    """
    try:
        data = request.get_json()
        prompt = data.get('prompt')

        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400

        # Generate text using the loaded model
        output = llm(prompt, max_tokens=256, echo=False)

        # The output is a dictionary, the generated text is in the 'text' key of the first choice
        generated_text = output['choices'][0]['text']

        return jsonify({"response": generated_text})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Run the Flask app on port 5000, accessible from any IP address
    app.run(host='0.0.0.0', port=5000)