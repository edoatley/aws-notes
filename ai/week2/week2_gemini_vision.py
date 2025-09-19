import os
import sys
import google.generativeai as genai
from PIL import Image

def main():
    """
       Main function to run the Google Gemini multimodal script.
       """
    # The Gemini SDK uses genai.configure() to set the API key.
    # It will look for the key in the GEMINI_API_KEY environment variable if not passed directly.
    try:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY environment variable not found.")
        genai.configure(api_key=api_key)
    except Exception as e:
        print(f"Error configuring Gemini client: {e}")
        sys.exit(1)

    # Define the image path and the text prompt.
    image_path = "test_image.jpg"
    text_prompt = "Describe this image in detail. What is happening?"

    # Verify the image file exists before proceeding.
    if not os.path.exists(image_path):
        print(f"Error: Image file not found at '{image_path}'")
        print("Please place an image file in the project directory and name it 'test_image.jpg'.")
        sys.exit(1)

    print(f"\n-> Loading image '{image_path}' and sending prompt to Gemini Vision...")
    print("... waiting for response...")

    try:
        # Load the image using the Pillow library.
        img = Image.open(image_path)

        # Initialize the specific Gemini model that supports vision.
        model = genai.GenerativeModel('gemini-1.5-flash')

        # The core API call. The 'generate_content' method can accept a list
        # containing different data types (modalities).
        response = model.generate_content([text_prompt, img])

        # The response object contains the generated text directly.
        # We also add error handling for blocked responses.
        if response.parts:
            assistant_response = response.text
        else:
            assistant_response = "Response was blocked or empty. This may be due to safety settings."

        print("\n<- Received response:\n")
        print(assistant_response)
        print("\n")

    except Exception as e:
        print(f"An error occurred while calling the Gemini API: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()