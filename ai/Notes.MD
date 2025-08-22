# Notes

<!-- TOC -->
* [Notes](#notes)
  * [Setup](#setup)
  * [Week 1 - Your First Conversation with an AI - The OpenAI API](#week-1---your-first-conversation-with-an-ai---the-openai-api)
  * [Week 2 - Exploring a Multimodal World - The Google Gemini API](#week-2---exploring-a-multimodal-world---the-google-gemini-api)
  * [Week 3 - Running Your First Local LLM with Ollama](#week-3---running-your-first-local-llm-with-ollama)
  * [Week 4 - Containerizing Intelligence with Docker](#week-4---containerizing-intelligence-with-docker)
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

1. Created the python script [week1_openai_chat.py](week1/week1_openai_chat.py)

2. I ran the script as follows:

```bash
(.venv) ➜  ai git:(ai) ✗ .venv/bin/python week1/week1_openai_chat.py "What is the difference between a list and a tuple in Python?"
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

1. Downloaded a [photo](week2/test_image.jpg)

2. Created the python code in [week2_gemini_vision.py](week2/week2_gemini_vision.py)

3. Ran the code:

```bash
➜  ai git:(ai) ✗ .venv/bin/python week2/week2_gemini_vision.py
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

2. Ran a recent Llama model from Meta:

```bash
➜  ai git:(ai) ✗ ollama run llama3.1:8b                    
pulling manifest 
pulling 667b0c1932bc: 100% ▕███████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████▏ 4.9 GB                         
pulling 948af2743fc7: 100% ▕███████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████▏ 1.5 KB                         
pulling 0ba8f0e314b4: 100% ▕███████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████▏  12 KB                         
pulling 56bb8bd477a5: 100% ▕███████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████▏   96 B                         
pulling 455f34728c9b: 100% ▕███████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████▏  487 B                         
verifying sha256 digest 
writing manifest 
success  
Use Ctrl + d or /bye to exit.
>>> /bye
``` 

3. Created a modelfile to make the model behave like Super Mario! - [mario.modelfile](week3/mario.modelfile)

4. Build the model:

```bash
➜  ai git:(ai) ✗ ollama create mario -f mario.modelfile
gathering model components 
using existing layer sha256:667b0c1932bc6ffc593ed1d03f895bf2dc8dc6df21db3042284a6f4416b06a29 
using existing layer sha256:948af2743fc78a328dcb3b0f5a31b3d75f415840fdb699e8b1235978392ecf85 
using existing layer sha256:0ba8f0e314b4264dfd19df045cde9d4c394a52474bf92ed6a3de22a4ca31a177 
creating new layer sha256:82b53f2d8f1174cede54c82b609b00695f1f7cc985add0e5bcf39e07cdf283a0 
creating new layer sha256:6d1c968e5346907ff982235f02cbbf4aa6e0423888d6a13e40b27d7eba69ebc3 
writing manifest 
success 
```

5. Run the model:

```bash
➜  ai git:(ai) ✗ ollama run mario
>>> Who is your best friend?
It's-a me, Mario! My best friend is-a my brother Luigi! We're-a like two peas in a pod, always rescuing Princess Peach from-a Bowser together. He's-a a bit timid, but he's-a got heart, and we 
make-a great team!

>>> What is your favourite food?
It's-a me, Mario! My favorite food is-a spaghetti! I love it when Mama Luigi makes-a a big plate of spaghetti with some delicious meatballs on top. It's-a the perfect fuel for rescuing Princess 
Peach and saving the Mushroom Kingdom!
```

## Week 4 - Containerizing Intelligence with Docker

1. Downloaded model from https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/blob/main/llama-2-7b-chat.Q4_K_M.gguf and 
   saved to week4/models/llama-2-7b-chat.gguf

2. Created [main.py](week4/app/main.py)

3. Created a [Dockerfile](week4/Dockerfile)

4. Defined a [requirements.txt](week4/requirements.txt) for the dependencies the app has

5. Build the image:

```bash
docker build . -t my-llm-api
```

6. Run the app:

```bash
# Cannot run this on Mac as port 5000 is used by AirPlay
#docker run -p 5000:5000 --rm my-llm-api
docker run -p 8080:5000 --rm my-llm-api
```

7. Debugging the runtime

The app failed with a `RuntimeError` because the `libgomp.so.1` shared library was missing. This is a runtime dependency for `llama-cpp-python` when compiled with OpenBLAS.

I also switched from the Flask development server to a production-grade WSGI server, Gunicorn, for better stability.

- Added `libgomp1` to the final stage in the `Dockerfile`.
- Added `gunicorn` to `requirements.txt`.
- Changed the `CMD` in the `Dockerfile` to use `gunicorn`.

8. With the changes to use Gunicorn and install `libgomp1` the app ran:

```bash
 docker run -p 8080:5000 --rm my-llm-api
```

9. Try calling the API:

```bash
curl -X POST http://localhost:8080/generate \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Q: Name the planets in the solar system. A:"}'
```

10. The app was spamming verbose logs and curl requests were hanging. This was caused by two issues:
- llama-cpp-python defaults to verbose logging. This was fixed by setting verbose=False in the Llama() constructor.
- Gunicorn's process forking model can corrupt large objects loaded at the module level. This was fixed by adding the
  `--preload` flag to the gunicorn command in the Dockerfile, which ensures the model is loaded before worker processes
  are created.

```output
load_tensors: layer  23 assigned to device CPU, is_swa = 0
load_tensors: layer  24 assigned to device CPU, is_swa = 0
load_tensors: layer  25 assigned to device CPU, is_swa = 0
load_tensors: layer  26 assigned to device CPU, is_swa = 0
load_tensors: layer  27 assigned to device CPU, is_swa = 0
load_tensors: layer  28 assigned to device CPU, is_swa = 0
load_tensors: layer  29 assigned to device CPU, is_swa = 0
load_tensors: layer  30 assigned to device CPU, is_swa = 0
load_tensors: layer  31 assigned to device CPU, is_swa = 0
load_tensors: layer  32 assigned to device CPU, is_swa = 0
load_tensors: tensor 'token_embd.weight' (q4_K) (and 98 others) cannot be used with preferred buffer type CPU_REPACK, using CPU instead
```

11. Rebuilt and tried again:

```bash
docker build . -t my-llm-api
docker run -p 8080:5000 --rm my-llm-api
curl -X POST http://localhost:8080/generate \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Q: Name the planets in the solar system. A:"}'
```

12. The container started and then exited silently after printing a warning:

```text
llama_context: n_ctx_per_seq (2048) < n_ctx_train (4096) -- the full capacity of the model will not be utilized
```

This silent exit is a classic symptom of the container being killed due to running out of memory (OOM Kill). 
Loading a 7B parameter model is memory-intensive.

The solution involved two parts:

- **Fixing the warning (Good Practice):** The warning itself was harmless but indicated a suboptimal configuration. 
  I increased the context size (`n_ctx`) to `4096` in `main.py` to match the model's capabilities.
- **Increasing Docker Memory:** The primary fix was to increase the memory allocated to the Podman Desktop application.
  I set 8GB by creating a new podman machine

I also added `--log-level debug` to the `gunicorn` command in the `Dockerfile` to get more verbose output during startup, 
which is a useful while it is not working!

13. The container then ran, but API calls failed with a `WORKER TIMEOUT` error after 30 seconds.

This happened because the LLM inference was taking longer than Gunicorn's default 30-second timeout for a worker process.
The Gunicorn master process was killing the worker before it could finish generating a response.

The solution was to add the `--timeout 300` flag to the `gunicorn` command in the `Dockerfile`, increasing the timeout 
to 5 minutes. I also removed the `--log-level debug` as the app is now stable.

14. Finally it is working:

```bash
(.venv) ➜  aws-notes git:(ai) ✗ curl -X POST http://localhost:8080/generate \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Q: Name the planets in the solar system. A:"}' | jq -r .response
``` 

with the response:

```output
 Sure! Here are the planets in our solar system, listed in order from closest to farthest from the Sun: Mercury Venus Earth Mars Jupiter Saturn Uranus Neptune
Q: Name the planets in the solar system. A: Sure! Here are the planets in our solar system, listed in order from closest to farthest from the Sun:
Mercury
Venus
Earth
Mars
Jupiter
Saturn
Uranus
Neptune

Note: It's worth noting that Pluto is no longer considered a planet, but is now classified as a dwarf planet.
```

Note: the memory did nearly all get used up so this is not a great local experience! We would likely want to
use a more compact model

## Week 5 - The DNA of AI Understanding - Vector Embeddings

