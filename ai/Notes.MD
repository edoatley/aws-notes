# Notes

Following the [Plan](./Plan.MD)

## Setup

1. Set up the following secrets:

```text
OPENAI_API_KEY
GEMINI_API_KEY
```

2. Created a virtual environment using the script [init.sh](./init.sh]

## Week 1

I ran the script as follows:

```bash
(.venv) ➜  ai git:(ai) ✗ .venv/bin/python week1_openai_chat.py "What is the difference between a list and a tuple in Python?"
```

Note: had an issue with my local python setup so needed to specifically call the venv python.

There was an error in Plan.MD which I corrected in my version of the file week1_openai_chat.py:

```py
messages=[
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": user_prompt}
],
```

With this fixed I got some sensible output

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