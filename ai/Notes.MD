# Notes

<!-- TOC -->
* [Notes](#notes)
  * [Setup](#setup)
  * [Week 1 - Your First Conversation with an AI - The OpenAI API](#week-1---your-first-conversation-with-an-ai---the-openai-api)
  * [Week 2 - Exploring a Multimodal World - The Google Gemini API](#week-2---exploring-a-multimodal-world---the-google-gemini-api)
  * [Week 3](#week-3)
<!-- TOC -->

Following the [Plan](./Plan.MD)

## Setup

1. Set up the following secrets:

```text
OPENAI_API_KEY
GEMINI_API_KEY
```

2. Created a virtual environment using the script [init.sh](./init.sh]

## Week 1 - Your First Conversation with an AI - The OpenAI API

1. Created the python script [week1_openai_chat.py](week1_openai_chat.py)

2. I ran the script as follows:

```bash
(.venv) ➜  ai git:(ai) ✗ .venv/bin/python week1_openai_chat.py "What is the difference between a list and a tuple in Python?"
```

Note: had an issue with my local python setup so needed to specifically call the venv python.

3. There was an error in Plan.MD which I corrected in my version of the file week1_openai_chat.py:

```py
messages=[
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": user_prompt}
],
```

4. With this fixed I got some sensible output

```output

-> Sending prompt to OpenAI: 'What is the difference between a list and a tuple in Python?'
... waiting for response...

<- Received response:

In Python, both lists and tuples are used to store collections of items. However, there are several key differences between them:

1. **Mutability**:
   - **List**: Lists are mutable, meaning you can change, add, or remove elements after the list has been created. For example, you can append items, modify existing items, or remove items from a list.
   - **Tuple**: Tuples are immutable, meaning once a tuple is created, its elements cannot be changed, added, or removed. This immutability can make tuples useful as keys in dictionaries or in situations where you want to ensure the data remains constant.

2. **Syntax**:
   - **List**: Lists are defined using square brackets `[]`. Example: `my_list = [1, 2, 3]`.
   - **Tuple**: Tuples are defined using parentheses `()`. Example: `my_tuple = (1, 2, 3)`. Note that for defining a single-element tuple, a trailing comma is required, like `my_singleton_tuple = (1,)`.

3. **Performance**:
   - **List**: Lists generally have a little more overhead because they are designed to
```

Seems to work nicely though the response is truncated which is a bit odd

## Week 2 - Exploring a Multimodal World - The Google Gemini API

1. Downloaded a [photo](test_image.jpg)

2. Created the python code in [week2_gemini_vision.py](week2_gemini_vision.py)

3. Ran the code:

```bash
➜  ai git:(ai) ✗ .venv/bin/python week2_gemini_vision.py
```

Which gave this output:

```output
-> Loading image 'test_image.jpg' and sending prompt to Gemini Vision...
... waiting for response...

<- Received response:

Here's a description of the image:

The photo shows a close-up view of a burning candle sitting on a light gray plastic table outdoors at night.


Here's a breakdown:

* **The Candle:** A round, orange-rimmed candleholder contains a yellowish-orange candle with a single, bright flame burning steadily. The wax appears somewhat melted around the edges.

* **The Table:** The table is light gray plastic or resin, with visible seams or lines creating a grid-like pattern on its surface.

* **The Moth:** A small, light brown and darker-marked moth is visible on the table surface, some distance from the candle. It appears to be resting or possibly attracted to the light.

* **The Background:** The background is dark, indicating it's nighttime. Out-of-focus elements suggest a street or road beyond the table, with faint glimpses of what could be vehicles or vegetation, showing the setting to be outside.

**What is happening?**

The image depicts a simple scene of a candle burning on a table at night. A moth has been drawn to the light of the candle.  The overall impression is one of quiet stillness and a juxtaposition of nature (the moth) and human-made light.
```

Nice result: gives me an interesting interpretation of the image.

## Week 3 - Running Your First Local LLM with Ollama

1. Navigated to https://ollama.com/download/mac and installed Ollama

2.  