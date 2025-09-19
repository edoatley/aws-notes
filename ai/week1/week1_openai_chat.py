# week1/openai_chat.py
import os
import sys
from openai import OpenAI

def main():
    """
    Main function to run the OpenAI chat completion script.
    """
    # The OpenAI client will automatically look for the API key in the
    # OPENAI_API_KEY environment variable.
    # Ensure you have set this variable before running the script.
    try:
        client = OpenAI()
    except Exception as e:
        print(f"Error initializing OpenAI client: {e}")
        print("Please ensure your OPENAI_API_KEY environment variable is set correctly.")
        sys.exit(1)

    # Check if a user prompt was provided as a command-line argument.
    if len(sys.argv) < 2:
        print("Usage: python week1_openai_chat.py \"<your question>\"")
        sys.exit(1)

    user_prompt = " ".join(sys.argv[1:])

    print(f"\n-> Sending prompt to OpenAI: '{user_prompt}'")
    print("... waiting for response...")

    try:
        # This is the core API call to the chat completions endpoint.
        response = client.chat.completions.create(
            # Specify the model to use. 'gpt-4o' is a powerful and versatile model.
            model="gpt-4o",
            # Construct the messages array.
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": user_prompt}
            ],
            # Set a maximum number of tokens for the response to avoid overly long answers.
            max_tokens=250,
            # Set the temperature to control randomness. 0.7 is a good balance of creative and factual.
            temperature=0.7
        )

        # The response object contains a list of 'choices'. We are interested in the first one.
        # The generated text is in the 'content' attribute of the message object.
        assistant_response = response.choices[0].message.content

        print("\n<- Received response:\n")
        print(assistant_response)
        print("\n")

    except Exception as e:
        print(f"An error occurred while calling the OpenAI API: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
