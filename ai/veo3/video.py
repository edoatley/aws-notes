import time
import os
import sys
from google import genai
from google.genai import types


def main(prompt:str, save_location:str):
    """
       Main function to run the Google Gemini multimodal script.
    """

    # We do not need to authenticate as accoring to https://ai.google.dev/gemini-api/docs/api-key
    # If you set the environment variable GEMINI_API_KEY or GOOGLE_API_KEY, the API key will
    # automatically be picked up by the client when using one of the Gemini API libraries

    client = genai.Client()
    operation = client.models.generate_videos(
        model="veo-3.0-generate-preview",
        prompt=prompt,
    )

    # Poll the operation status until the video is ready.
    while not operation.done:
        print("Waiting for video generation to complete...")
        time.sleep(10)
        operation = client.operations.get(operation)

    # Download the generated video.
    generated_video = operation.response.generated_videos[0]
    client.files.download(file=generated_video.video)
    generated_video.video.save(save_location) # type: ignore
    print(f"Generated video saved to {save_location}")

if __name__ == "__main__":
    # check the correct args are passed and if not fail gracefully
    if len(sys.argv) != 3:
        print("Usage: python script.py <file_name> <user_prompt>")
        sys.exit(1)

    # check that GEMINI_API_KEY is set
    if not os.getenv("GEMINI_API_KEY"):
        print("GEMINI_API_KEY environment variable not found.")
        sys.exit(1)

    file_name=sys.argv[1]
    user_prompt=sys.argv[2]
    main(user_prompt, f'/Users/edoatley/source/aws-notes/ai/veo3/results/{file_name}')

