## Endpoints

-   [Generate a completion](https://docs.ollama.com/api#generate-a-completion)
-   [Generate a chat completion](https://docs.ollama.com/api#generate-a-chat-completion)
-   [Create a Model](https://docs.ollama.com/api#create-a-model)
-   [List Local Models](https://docs.ollama.com/api#list-local-models)
-   [Show Model Information](https://docs.ollama.com/api#show-model-information)
-   [Copy a Model](https://docs.ollama.com/api#copy-a-model)
-   [Delete a Model](https://docs.ollama.com/api#delete-a-model)
-   [Pull a Model](https://docs.ollama.com/api#pull-a-model)
-   [Push a Model](https://docs.ollama.com/api#push-a-model)
-   [Generate Embeddings](https://docs.ollama.com/api#generate-embeddings)
-   [List Running Models](https://docs.ollama.com/api#list-running-models)
-   [Web search](https://docs.ollama.com/api#web-search)
-   [Version](https://docs.ollama.com/api#version)

## Conventions

### Model names

Model names follow a `model:tag` format, where `model` can have an optional namespace such as `example/model`. Some examples are `orca-mini:3b-q4_1` and `llama3:70b`. The tag is optional and, if not provided, will default to `latest`. The tag is used to identify a specific version.

### Durations

All durations are returned in nanoseconds.

### Streaming responses

Certain endpoints stream responses as JSON objects. Streaming can be disabled by providing `{"stream": false}` for these endpoints.

## Generate a completion

Generate a response for a given prompt with a provided model. This is a streaming endpoint, so there will be a series of responses. The final response object will include statistics and additional data from the request.

### Parameters

-   `model`: (required) the [model name](https://docs.ollama.com/api#model-names)
-   `prompt`: the prompt to generate a response for
-   `suffix`: the text after the model response
-   `images`: (optional) a list of base64-encoded images (for multimodal models such as `llava`)

Advanced parameters (optional):

-   `format`: the format to return a response in. Format can be `json` or a JSON schema
-   `options`: additional model parameters listed in the documentation for the [Modelfile](https://docs.ollama.com/modelfile.md#valid-parameters-and-values) such as `temperature`
-   `system`: system message to (overrides what is defined in the `Modelfile`)
-   `template`: the prompt template to use (overrides what is defined in the `Modelfile`)
-   `stream`: if `false` the response will be returned as a single response object, rather than a stream of objects
-   `raw`: if `true` no formatting will be applied to the prompt. You may choose to use the `raw` parameter if you are specifying a full templated prompt in your request to the API
-   `keep_alive`: controls how long the model will stay loaded into memory following the request (default: `5m`)
-   `context` (deprecated): the context parameter returned from a previous request to `/generate`, this can be used to keep a short conversational memory

#### Structured outputs

Structured outputs are supported by providing a JSON schema in the `format` parameter. The model will generate a response that matches the schema. See the [structured outputs](https://docs.ollama.com/api#request-structured-outputs) example below.

#### JSON mode

Enable JSON mode by setting the `format` parameter to `json`. This will structure the response as a valid JSON object. See the JSON mode [example](https://docs.ollama.com/api#request-json-mode) below.

### Examples

#### Generate request (Streaming)

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "prompt": "Why is the sky blue?"</span></span>
<span><span>}'</span></span>
```

##### Response

A stream of JSON objects is returned:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T08:52:19.385406455-07:00"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>"The"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>false</span></span>
<span><span>}</span></span>
```

The final response in the stream also includes additional data about the generation:

-   `total_duration`: time spent generating the response
-   `load_duration`: time spent in nanoseconds loading the model
-   `prompt_eval_count`: number of tokens in the prompt
-   `prompt_eval_duration`: time spent in nanoseconds evaluating the prompt
-   `eval_count`: number of tokens in the response
-   `eval_duration`: time in nanoseconds spent generating the response
-   `context`: an encoding of the conversation used in this response, this can be sent in the next request to keep a conversational memory
-   `response`: empty if the response was streamed, if not streamed, this will contain the full response

To calculate how fast the response is generated in tokens per second (token/s), divide `eval_count` / `eval_duration` \* `10^9`.

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T19:22:45.499127Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>""</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "context"</span><span>: [</span><span>1</span><span>, </span><span>2</span><span>, </span><span>3</span><span>],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>10706818083</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>6338219291</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>26</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>130079000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>259</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>4232710000</span></span>
<span><span>}</span></span>
```

#### Request (No streaming)

##### Request

A response can be received in one reply when streaming is off.

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "prompt": "Why is the sky blue?",</span></span>
<span><span>  "stream": false</span></span>
<span><span>}'</span></span>
```

##### Response

If `stream` is set to `false`, the response will be a single JSON object:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T19:22:45.499127Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>"The sky is blue because it is the color of the sky."</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "context"</span><span>: [</span><span>1</span><span>, </span><span>2</span><span>, </span><span>3</span><span>],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>5043500667</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>5025959</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>26</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>325953000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>290</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>4709213000</span></span>
<span><span>}</span></span>
```

#### Request (with suffix)

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "codellama:code",</span></span>
<span><span>  "prompt": "def compute_gcd(a, b):",</span></span>
<span><span>  "suffix": "    return result",</span></span>
<span><span>  "options": {</span></span>
<span><span>    "temperature": 0</span></span>
<span><span>  },</span></span>
<span><span>  "stream": false</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"codellama:code"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2024-07-22T20:47:51.147561Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>"</span><span>\n</span><span>  if a == 0:</span><span>\n</span><span>    return b</span><span>\n</span><span>  else:</span><span>\n</span><span>    return compute_gcd(b % a, a)</span><span>\n\n</span><span>def compute_lcm(a, b):</span><span>\n</span><span>  result = (a * b) / compute_gcd(a, b)</span><span>\n</span><span>"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "done_reason"</span><span>: </span><span>"stop"</span><span>,</span></span>
<span><span>  "context"</span><span>: [</span><span>...</span><span>],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>1162761250</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>6683708</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>17</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>201222000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>63</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>953997000</span></span>
<span><span>}</span></span>
```

#### Request (Structured outputs)

##### Request

```
<span><span>curl</span><span> -X</span><span> POST</span><span> http://localhost:11434/api/generate</span><span> -H</span><span> "Content-Type: application/json"</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.1:8b",</span></span>
<span><span>  "prompt": "Ollama is 22 years old and is busy saving the world. Respond using JSON",</span></span>
<span><span>  "stream": false,</span></span>
<span><span>  "format": {</span></span>
<span><span>    "type": "object",</span></span>
<span><span>    "properties": {</span></span>
<span><span>      "age": {</span></span>
<span><span>        "type": "integer"</span></span>
<span><span>      },</span></span>
<span><span>      "available": {</span></span>
<span><span>        "type": "boolean"</span></span>
<span><span>      }</span></span>
<span><span>    },</span></span>
<span><span>    "required": [</span></span>
<span><span>      "age",</span></span>
<span><span>      "available"</span></span>
<span><span>    ]</span></span>
<span><span>  }</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.1:8b"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2024-12-06T00:48:09.983619Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>"{</span><span>\n</span><span>  \"</span><span>age</span><span>\"</span><span>: 22,</span><span>\n</span><span>  \"</span><span>available</span><span>\"</span><span>: true</span><span>\n</span><span>}"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "done_reason"</span><span>: </span><span>"stop"</span><span>,</span></span>
<span><span>  "context"</span><span>: [</span><span>1</span><span>, </span><span>2</span><span>, </span><span>3</span><span>],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>1075509083</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>567678166</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>28</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>236000000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>16</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>269000000</span></span>
<span><span>}</span></span>
```

#### Request (JSON mode)

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "prompt": "What color is the sky at different times of the day? Respond using JSON",</span></span>
<span><span>  "format": "json",</span></span>
<span><span>  "stream": false</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-11-09T21:07:55.186497Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>"{</span><span>\n\"</span><span>morning</span><span>\"</span><span>: {</span><span>\n\"</span><span>color</span><span>\"</span><span>: </span><span>\"</span><span>blue</span><span>\"\n</span><span>},</span><span>\n\"</span><span>noon</span><span>\"</span><span>: {</span><span>\n\"</span><span>color</span><span>\"</span><span>: </span><span>\"</span><span>blue-gray</span><span>\"\n</span><span>},</span><span>\n\"</span><span>afternoon</span><span>\"</span><span>: {</span><span>\n\"</span><span>color</span><span>\"</span><span>: </span><span>\"</span><span>warm gray</span><span>\"\n</span><span>},</span><span>\n\"</span><span>evening</span><span>\"</span><span>: {</span><span>\n\"</span><span>color</span><span>\"</span><span>: </span><span>\"</span><span>orange</span><span>\"\n</span><span>}</span><span>\n</span><span>}</span><span>\n</span><span>"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "context"</span><span>: [</span><span>1</span><span>, </span><span>2</span><span>, </span><span>3</span><span>],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>4648158584</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>4071084</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>36</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>439038000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>180</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>4196918000</span></span>
<span><span>}</span></span>
```

The value of `response` will be a string containing JSON similar to:

```
<span><span>{</span></span>
<span><span>  "morning"</span><span>: {</span></span>
<span><span>    "color"</span><span>: </span><span>"blue"</span></span>
<span><span>  },</span></span>
<span><span>  "noon"</span><span>: {</span></span>
<span><span>    "color"</span><span>: </span><span>"blue-gray"</span></span>
<span><span>  },</span></span>
<span><span>  "afternoon"</span><span>: {</span></span>
<span><span>    "color"</span><span>: </span><span>"warm gray"</span></span>
<span><span>  },</span></span>
<span><span>  "evening"</span><span>: {</span></span>
<span><span>    "color"</span><span>: </span><span>"orange"</span></span>
<span><span>  }</span></span>
<span><span>}</span></span>
```

#### Request (with images)

To submit images to multimodal models such as `llava` or `bakllava`, provide a list of base64-encoded `images`:

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llava",</span></span>
<span><span>  "prompt":"What is in this picture?",</span></span>
<span><span>  "stream": false,</span></span>
<span><span>  "images": ["iVBORw0KGgoAAAANSUhEUgAAAG0AAABmCAYAAADBPx+VAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAA3VSURBVHgB7Z27r0zdG8fX743i1bi1ikMoFMQloXRpKFFIqI7LH4BEQ+NWIkjQuSWCRIEoULk0gsK1kCBI0IhrQVT7tz/7zZo888yz1r7MnDl7z5xvsjkzs2fP3uu71nNfa7lkAsm7d++Sffv2JbNmzUqcc8m0adOSzZs3Z+/XES4ZckAWJEGWPiCxjsQNLWmQsWjRIpMseaxcuTKpG/7HP27I8P79e7dq1ars/yL4/v27S0ejqwv+cUOGEGGpKHR37tzJCEpHV9tnT58+dXXCJDdECBE2Ojrqjh071hpNECjx4cMHVycM1Uhbv359B2F79+51586daxN/+pyRkRFXKyRDAqxEp4yMlDDzXG1NPnnyJKkThoK0VFd1ELZu3TrzXKxKfW7dMBQ6bcuWLW2v0VlHjx41z717927ba22U9APcw7Nnz1oGEPeL3m3p2mTAYYnFmMOMXybPPXv2bNIPpFZr1NHn4HMw0KRBjg9NuRw95s8PEcz/6DZELQd/09C9QGq5RsmSRybqkwHGjh07OsJSsYYm3ijPpyHzoiacg35MLdDSIS/O1yM778jOTwYUkKNHWUzUWaOsylE00MyI0fcnOwIdjvtNdW/HZwNLGg+sR1kMepSNJXmIwxBZiG8tDTpEZzKg0GItNsosY8USkxDhD0Rinuiko2gfL/RbiD2LZAjU9zKQJj8RDR0vJBR1/Phx9+PHj9Z7REF4nTZkxzX4LCXHrV271qXkBAPGfP/atWvu/PnzHe4C97F48eIsRLZ9+3a3f/9+87dwP1JxaF7/3r17ba+5l4EcaVo0lj3SBq5kGTJSQmLWMjgYNei2GPT1MuMqGTDEFHzeQSP2wi/jGnkmPJ/nhccs44jvDAxpVcxnq0F6eT8h4ni/iIWpR5lPyA6ETkNXoSukvpJAD3AsXLiwpZs49+fPn5ke4j10TqYvegSfn0OnafC+Tv9ooA/JPkgQysqQNBzagXY55nO/oa1F7qvIPWkRL12WRpMWUvpVDYmxAPehxWSe8ZEXL20sadYIozfmNch4QJPAfeJgW3rNsnzphBKNJM2KKODo1rVOMRYik5ETy3ix4qWNI81qAAirizgMIc+yhTytx0JWZuNI03qsrgWlGtwjoS9XwgUhWGyhUaRZZQNNIEwCiXD16tXcAHUs79co0vSD8rrJCIW98pzvxpAWyyo3HYwqS0+H0BjStClcZJT5coMm6D2LOF8TolGJtK9fvyZpyiC5ePFi9nc/oJU4eiEP0jVoAnHa9wyJycITMP78+eMeP37sXrx44d6+fdt6f82aNdkx1pg9e3Zb5W+RSRE+n+VjksQWifvVaTKFhn5O8my63K8Qabdv33b379/PiAP//vuvW7BggZszZ072/+TJk91YgkafPn166zXB1rQHFvouAWHq9z3SEevSUerqCn2/dDCeta2jxYbr69evk4MHDyY7d+7MjhMnTiTPnz9Pfv/+nfQT2ggpO2dMF8cghuoM7Ygj5iWCqRlGFml0QC/ftGmTmzt3rmsaKDsgBSPh0/8yPeLLBihLkOKJc0jp8H8vUzcxIA1k6QJ/c78tWEyj5P3o4u9+jywNPdJi5rAH9x0KHcl4Hg570eQp3+vHXGyrmEeigzQsQsjavXt38ujRo44LQuDDhw+TW7duRS1HGgMxhNXHgflaNTOsHyKvHK5Ijo2jbFjJBQK9YwFd6RVMzfgRBmEfP37suBBm/p49e1qjEP2mwTViNRo0VJWH1deMXcNK08uUjVUu7s/zRaL+oLNxz1bpANco4npUgX4G2eFbpDFyQoQxojBCpEGSytmOH8qrH5Q9vuzD6ofQylkCUmh8DBAr+q8JCyVNtWQIidKQE9wNtLSQnS4jDSsxNHogzFuQBw4cyM61UKVsjfr3ooBkPSqqQHesUPWVtzi9/vQi1T+rJj7WiTz4Pt/l3LxUkr5P2VYZaZ4URpsE+st/dujQoaBBYokbrz/8TJNQYLSonrPS9kUaSkPeZyj1AWSj+d+VBoy1pIWVNed8P0Ll/ee5HdGRhrHhR5GGN0r4LGZBaj8oFDJitBTJzIZgFcmU0Y8ytWMZMzJOaXUSrUs5RxKnrxmbb5YXO9VGUhtpXldhEUogFr3IzIsvlpmdosVcGVGXFWp2oU9kLFL3dEkSz6NHEY1sjSRdIuDFWEhd8KxFqsRi1uM/nz9/zpxnwlESONdg6dKlbsaMGS4EHFHtjFIDHwKOo46l4TxSuxgDzi+rE2jg+BaFruOX4HXa0Nnf1lwAPufZeF8/r6zD97WK2qFnGjBxTw5qNGPxT+5T/r7/7RawFC3j4vTp09koCxkeHjqbHJqArmH5UrFKKksnxrK7FuRIs8STfBZv+luugXZ2pR/pP9Ois4z+TiMzUUkUjD0iEi1fzX8GmXyuxUBRcaUfykV0YZnlJGKQpOiGB76x5GeWkWWJc3mOrK6S7xdND+W5N6XyaRgtWJFe13GkaZnKOsYqGdOVVVbGupsyA/l7emTLHi7vwTdirNEt0qxnzAvBFcnQF16xh/TMpUuXHDowhlA9vQVraQhkudRdzOnK+04ZSP3DUhVSP61YsaLtd/ks7ZgtPcXqPqEafHkdqa84X6aCeL7YWlv6edGFHb+ZFICPlljHhg0bKuk0CSvVznWsotRu433alNdFrqG45ejoaPCaUkWERpLXjzFL2Rpllp7PJU2a/v7Ab8N05/9t27Z16KUqoFGsxnI9EosS2niSYg9SpU6B4JgTrvVW1flt1sT+0ADIJU2maXzcUTraGCRaL1Wp9rUMk16PMom8QhruxzvZIegJjFU7LLCePfS8uaQdPny4jTTL0dbee5mYokQsXTIWNY46kuMbnt8Kmec+LGWtOVIl9cT1rCB0V8WqkjAsRwta93TbwNYoGKsUSChN44lgBNCoHLHzquYKrU6qZ8lolCIN0Rh6cP0Q3U6I6IXILYOQI513hJaSKAorFpuHXJNfVlpRtmYBk1Su1obZr5dnKAO+L10Hrj3WZW+E3qh6IszE37F6EB+68mGpvKm4eb9bFrlzrok7fvr0Kfv727dvWRmdVTJHw0qiiCUSZ6wCK+7XL/AcsgNyL74DQQ730sv78Su7+t/A36MdY0sW5o40ahslXr58aZ5HtZB8GH64m9EmMZ7FpYw4T6QnrZfgenrhFxaSiSGXtPnz57e9TkNZLvTjeqhr734CNtrK41L40sUQckmj1lGKQ0rC37x544r8eNXRpnVE3ZZY7zXo8NomiO0ZUCj2uHz58rbXoZ6gc0uA+F6ZeKS/jhRDUq8MKrTho9fEkihMmhxtBI1DxKFY9XLpVcSkfoi8JGnToZO5sU5aiDQIW716ddt7ZLYtMQlhECdBGXZZMWldY5BHm5xgAroWj4C0hbYkSc/jBmggIrXJWlZM6pSETsEPGqZOndr2uuuR5rF169a2HoHPdurUKZM4CO1WTPqaDaAd+GFGKdIQkxAn9RuEWcTRyN2KSUgiSgF5aWzPTeA/lN5rZubMmR2bE4SIC4nJoltgAV/dVefZm72AtctUCJU2CMJ327hxY9t7EHbkyJFseq+EJSY16RPo3Dkq1kkr7+q0bNmyDuLQcZBEPYmHVdOBiJyIlrRDq41YPWfXOxUysi5fvtyaj+2BpcnsUV/oSoEMOk2CQGlr4ckhBwaetBhjCwH0ZHtJROPJkyc7UjcYLDjmrH7ADTEBXFfOYmB0k9oYBOjJ8b4aOYSe7QkKcYhFlq3QYLQhSidNmtS2RATwy8YOM3EQJsUjKiaWZ+vZToUQgzhkHXudb/PW5YMHD9yZM2faPsMwoc7RciYJXbGuBqJ1UIGKKLv915jsvgtJxCZDubdXr165mzdvtr1Hz5LONA8jrUwKPqsmVesKa49S3Q4WxmRPUEYdTjgiUcfUwLx589ySJUva3oMkP6IYddq6HMS4o55xBJBUeRjzfa4Zdeg56QZ43LhxoyPo7Lf1kNt7oO8wWAbNwaYjIv5lhyS7kRf96dvm5Jah8vfvX3flyhX35cuX6HfzFHOToS1H4BenCaHvO8pr8iDuwoUL7tevX+b5ZdbBair0xkFIlFDlW4ZknEClsp/TzXyAKVOmmHWFVSbDNw1l1+4f90U6IY/q4V27dpnE9bJ+v87QEydjqx/UamVVPRG+mwkNTYN+9tjkwzEx+atCm/X9WvWtDtAb68Wy9LXa1UmvCDDIpPkyOQ5ZwSzJ4jMrvFcr0rSjOUh+GcT4LSg5ugkW1Io0/SCDQBojh0hPlaJdah+tkVYrnTZowP8iq1F1TgMBBauufyB33x1v+NWFYmT5KmppgHC+NkAgbmRkpD3yn9QIseXymoTQFGQmIOKTxiZIWpvAatenVqRVXf2nTrAWMsPnKrMZHz6bJq5jvce6QK8J1cQNgKxlJapMPdZSR64/UivS9NztpkVEdKcrs5alhhWP9NeqlfWopzhZScI6QxseegZRGeg5a8C3Re1Mfl1ScP36ddcUaMuv24iOJtz7sbUjTS4qBvKmstYJoUauiuD3k5qhyr7QdUHMeCgLa1Ear9NquemdXgmum4fvJ6w1lqsuDhNrg1qSpleJK7K3TF0Q2jSd94uSZ60kK1e3qyVpQK6PVWXp2/FC3mp6jBhKKOiY2h3gtUV64TWM6wDETRPLDfSakXmH3w8g9Jlug8ZtTt4kVF0kLUYYmCCtD/DrQ5YhMGbA9L3ucdjh0y8kOHW5gU/VEEmJTcL4Pz/f7mgoAbYkAAAAAElFTkSuQmCC"]</span></span>
<span><span>}'</span></span>
```

#### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llava"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-11-03T15:36:02.583064Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>"A happy cartoon character, which is cute and cheerful."</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "context"</span><span>: [</span><span>1</span><span>, </span><span>2</span><span>, </span><span>3</span><span>],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>2938432250</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>2559292</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>1</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>2195557000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>44</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>736432000</span></span>
<span><span>}</span></span>
```

#### Request (Raw Mode)

In some cases, you may wish to bypass the templating system and provide a full prompt. In this case, you can use the `raw` parameter to disable templating. Also note that raw mode will not return a context.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "mistral",</span></span>
<span><span>  "prompt": "[INST] why is the sky blue? [/INST]",</span></span>
<span><span>  "raw": true,</span></span>
<span><span>  "stream": false</span></span>
<span><span>}'</span></span>
```

#### Request (Reproducible outputs)

For reproducible outputs, set `seed` to a number:

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "mistral",</span></span>
<span><span>  "prompt": "Why is the sky blue?",</span></span>
<span><span>  "options": {</span></span>
<span><span>    "seed": 123</span></span>
<span><span>  }</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"mistral"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-11-03T15:36:02.583064Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>" The sky appears blue because of a phenomenon called Rayleigh scattering."</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>8493852375</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>6589624375</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>14</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>119039000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>110</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>1779061000</span></span>
<span><span>}</span></span>
```

#### Generate request (With options)

If you want to set custom options for the model at runtime rather than in the Modelfile, you can do so with the `options` parameter. This example sets every available option, but you can set any of them individually and omit the ones you do not want to override.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "prompt": "Why is the sky blue?",</span></span>
<span><span>  "stream": false,</span></span>
<span><span>  "options": {</span></span>
<span><span>    "num_keep": 5,</span></span>
<span><span>    "seed": 42,</span></span>
<span><span>    "num_predict": 100,</span></span>
<span><span>    "top_k": 20,</span></span>
<span><span>    "top_p": 0.9,</span></span>
<span><span>    "min_p": 0.0,</span></span>
<span><span>    "typical_p": 0.7,</span></span>
<span><span>    "repeat_last_n": 33,</span></span>
<span><span>    "temperature": 0.8,</span></span>
<span><span>    "repeat_penalty": 1.2,</span></span>
<span><span>    "presence_penalty": 1.5,</span></span>
<span><span>    "frequency_penalty": 1.0,</span></span>
<span><span>    "mirostat": 1,</span></span>
<span><span>    "mirostat_tau": 0.8,</span></span>
<span><span>    "mirostat_eta": 0.6,</span></span>
<span><span>    "penalize_newline": true,</span></span>
<span><span>    "stop": ["\n", "user:"],</span></span>
<span><span>    "numa": false,</span></span>
<span><span>    "num_ctx": 1024,</span></span>
<span><span>    "num_batch": 2,</span></span>
<span><span>    "num_gpu": 1,</span></span>
<span><span>    "main_gpu": 0,</span></span>
<span><span>    "low_vram": false,</span></span>
<span><span>    "vocab_only": false,</span></span>
<span><span>    "use_mmap": true,</span></span>
<span><span>    "use_mlock": false,</span></span>
<span><span>    "num_thread": 8</span></span>
<span><span>  }</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T19:22:45.499127Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>"The sky is blue because it is the color of the sky."</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "context"</span><span>: [</span><span>1</span><span>, </span><span>2</span><span>, </span><span>3</span><span>],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>4935886791</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>534986708</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>26</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>107345000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>237</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>4289432000</span></span>
<span><span>}</span></span>
```

#### Load a model

If an empty prompt is provided, the model will be loaded into memory.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2"</span></span>
<span><span>}'</span></span>
```

##### Response

A single JSON object is returned:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-12-18T19:52:07.071755Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>""</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span></span>
<span><span>}</span></span>
```

#### Unload a model

If an empty prompt is provided and the `keep_alive` parameter is set to `0`, a model will be unloaded from memory.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/generate</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "keep_alive": 0</span></span>
<span><span>}'</span></span>
```

##### Response

A single JSON object is returned:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2024-09-12T03:54:03.516566Z"</span><span>,</span></span>
<span><span>  "response"</span><span>: </span><span>""</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "done_reason"</span><span>: </span><span>"unload"</span></span>
<span><span>}</span></span>
```

## Generate a chat completion

Generate the next message in a chat with a provided model. This is a streaming endpoint, so there will be a series of responses. Streaming can be disabled using `"stream": false`. The final response object will include statistics and additional data from the request.

### Parameters

-   `model`: (required) the [model name](https://docs.ollama.com/api#model-names)
-   `messages`: the messages of the chat, this can be used to keep a chat memory
-   `tools`: list of tools in JSON for the model to use if supported

The `message` object has the following fields:

-   `role`: the role of the message, either `system`, `user`, `assistant`, or `tool`
-   `content`: the content of the message
-   `images` (optional): a list of images to include in the message (for multimodal models such as `llava`)
-   `tool_calls` (optional): a list of tools in JSON that the model wants to use

Advanced parameters (optional):

-   `format`: the format to return a response in. Format can be `json` or a JSON schema.
-   `options`: additional model parameters listed in the documentation for the [Modelfile](https://docs.ollama.com/modelfile.md#valid-parameters-and-values) such as `temperature`
-   `stream`: if `false` the response will be returned as a single response object, rather than a stream of objects
-   `keep_alive`: controls how long the model will stay loaded into memory following the request (default: `5m`)

### Structured outputs

Structured outputs are supported by providing a JSON schema in the `format` parameter. The model will generate a response that matches the schema. See the [Chat request (Structured outputs)](https://docs.ollama.com/api#chat-request-structured-outputs) example below.

### Examples

#### Chat Request (Streaming)

##### Request

Send a chat message with a streaming response.

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "messages": [</span></span>
<span><span>    {</span></span>
<span><span>      "role": "user",</span></span>
<span><span>      "content": "why is the sky blue?"</span></span>
<span><span>    }</span></span>
<span><span>  ]</span></span>
<span><span>}'</span></span>
```

##### Response

A stream of JSON objects is returned:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T08:52:19.385406455-07:00"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>"The"</span><span>,</span></span>
<span><span>    "images"</span><span>: </span><span>null</span></span>
<span><span>  },</span></span>
<span><span>  "done"</span><span>: </span><span>false</span></span>
<span><span>}</span></span>
```

Final response:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T19:22:45.499127Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>""</span></span>
<span><span>  },</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>4883583458</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>1334875</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>26</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>342546000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>282</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>4535599000</span></span>
<span><span>}</span></span>
```

#### Chat request (No streaming)

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "messages": [</span></span>
<span><span>    {</span></span>
<span><span>      "role": "user",</span></span>
<span><span>      "content": "why is the sky blue?"</span></span>
<span><span>    }</span></span>
<span><span>  ],</span></span>
<span><span>  "stream": false</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-12-12T14:13:43.416799Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>"Hello! How are you today?"</span></span>
<span><span>  },</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>5191566416</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>2154458</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>26</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>383809000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>298</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>4799921000</span></span>
<span><span>}</span></span>
```

#### Chat request (Structured outputs)

##### Request

```
<span><span>curl</span><span> -X</span><span> POST</span><span> http://localhost:11434/api/chat</span><span> -H</span><span> "Content-Type: application/json"</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.1",</span></span>
<span><span>  "messages": [{"role": "user", "content": "Ollama is 22 years old and busy saving the world. Return a JSON object with the age and availability."}],</span></span>
<span><span>  "stream": false,</span></span>
<span><span>  "format": {</span></span>
<span><span>    "type": "object",</span></span>
<span><span>    "properties": {</span></span>
<span><span>      "age": {</span></span>
<span><span>        "type": "integer"</span></span>
<span><span>      },</span></span>
<span><span>      "available": {</span></span>
<span><span>        "type": "boolean"</span></span>
<span><span>      }</span></span>
<span><span>    },</span></span>
<span><span>    "required": [</span></span>
<span><span>      "age",</span></span>
<span><span>      "available"</span></span>
<span><span>    ]</span></span>
<span><span>  },</span></span>
<span><span>  "options": {</span></span>
<span><span>    "temperature": 0</span></span>
<span><span>  }</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.1"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2024-12-06T00:46:58.265747Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>"{</span><span>\"</span><span>age</span><span>\"</span><span>: 22, </span><span>\"</span><span>available</span><span>\"</span><span>: false}"</span></span>
<span><span>  },</span></span>
<span><span>  "done_reason"</span><span>: </span><span>"stop"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>2254970291</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>574751416</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>34</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>1502000000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>12</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>175000000</span></span>
<span><span>}</span></span>
```

#### Chat request (With History)

Send a chat message with a conversation history. You can use this same approach to start the conversation using multi-shot or chain-of-thought prompting.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "messages": [</span></span>
<span><span>    {</span></span>
<span><span>      "role": "user",</span></span>
<span><span>      "content": "why is the sky blue?"</span></span>
<span><span>    },</span></span>
<span><span>    {</span></span>
<span><span>      "role": "assistant",</span></span>
<span><span>      "content": "due to rayleigh scattering."</span></span>
<span><span>    },</span></span>
<span><span>    {</span></span>
<span><span>      "role": "user",</span></span>
<span><span>      "content": "how is that different than mie scattering?"</span></span>
<span><span>    }</span></span>
<span><span>  ]</span></span>
<span><span>}'</span></span>
```

##### Response

A stream of JSON objects is returned:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T08:52:19.385406455-07:00"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>"The"</span></span>
<span><span>  },</span></span>
<span><span>  "done"</span><span>: </span><span>false</span></span>
<span><span>}</span></span>
```

Final response:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-08-04T19:22:45.499127Z"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>8113331500</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>6396458</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>61</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>398801000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>468</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>7701267000</span></span>
<span><span>}</span></span>
```

#### Chat request (with images)

##### Request

Send a chat message with images. The images should be provided as an array, with the individual images encoded in Base64.

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llava",</span></span>
<span><span>  "messages": [</span></span>
<span><span>    {</span></span>
<span><span>      "role": "user",</span></span>
<span><span>      "content": "what is in this image?",</span></span>
<span><span>      "images": ["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"]</span></span>
<span><span>    }</span></span>
<span><span>  ]</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llava"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-12-13T22:42:50.203334Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>" The image features a cute, little pig with an angry facial expression. It's wearing a heart on its shirt and is waving in the air. This scene appears to be part of a drawing or sketching project."</span><span>,</span></span>
<span><span>    "images"</span><span>: </span><span>null</span></span>
<span><span>  },</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>1668506709</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>1986209</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>26</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>359682000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>83</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>1303285000</span></span>
<span><span>}</span></span>
```

#### Chat request (Reproducible outputs)

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "messages": [</span></span>
<span><span>    {</span></span>
<span><span>      "role": "user",</span></span>
<span><span>      "content": "Hello!"</span></span>
<span><span>    }</span></span>
<span><span>  ],</span></span>
<span><span>  "options": {</span></span>
<span><span>    "seed": 101,</span></span>
<span><span>    "temperature": 0</span></span>
<span><span>  }</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2023-12-12T14:13:43.416799Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>"Hello! How are you today?"</span></span>
<span><span>  },</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>5191566416</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>2154458</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>26</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>383809000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>298</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>4799921000</span></span>
<span><span>}</span></span>
```

#### Chat request (with tools)

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "messages": [</span></span>
<span><span>    {</span></span>
<span><span>      "role": "user",</span></span>
<span><span>      "content": "What is the weather today in Paris?"</span></span>
<span><span>    }</span></span>
<span><span>  ],</span></span>
<span><span>  "stream": false,</span></span>
<span><span>  "tools": [</span></span>
<span><span>    {</span></span>
<span><span>      "type": "function",</span></span>
<span><span>      "function": {</span></span>
<span><span>        "name": "get_current_weather",</span></span>
<span><span>        "description": "Get the current weather for a location",</span></span>
<span><span>        "parameters": {</span></span>
<span><span>          "type": "object",</span></span>
<span><span>          "properties": {</span></span>
<span><span>            "location": {</span></span>
<span><span>              "type": "string",</span></span>
<span><span>              "description": "The location to get the weather for, e.g. San Francisco, CA"</span></span>
<span><span>            },</span></span>
<span><span>            "format": {</span></span>
<span><span>              "type": "string",</span></span>
<span><span>              "description": "The format to return the weather in, e.g. 'celsius' or 'fahrenheit'",</span></span>
<span><span>              "enum": ["celsius", "fahrenheit"]</span></span>
<span><span>            }</span></span>
<span><span>          },</span></span>
<span><span>          "required": ["location", "format"]</span></span>
<span><span>        }</span></span>
<span><span>      }</span></span>
<span><span>    }</span></span>
<span><span>  ]</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2024-07-22T20:33:28.123648Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>""</span><span>,</span></span>
<span><span>    "tool_calls"</span><span>: [</span></span>
<span><span>      {</span></span>
<span><span>        "function"</span><span>: {</span></span>
<span><span>          "name"</span><span>: </span><span>"get_current_weather"</span><span>,</span></span>
<span><span>          "arguments"</span><span>: {</span></span>
<span><span>            "format"</span><span>: </span><span>"celsius"</span><span>,</span></span>
<span><span>            "location"</span><span>: </span><span>"Paris, FR"</span></span>
<span><span>          }</span></span>
<span><span>        }</span></span>
<span><span>      }</span></span>
<span><span>    ]</span></span>
<span><span>  },</span></span>
<span><span>  "done_reason"</span><span>: </span><span>"stop"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span><span>,</span></span>
<span><span>  "total_duration"</span><span>: </span><span>885095291</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>3753500</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>122</span><span>,</span></span>
<span><span>  "prompt_eval_duration"</span><span>: </span><span>328493000</span><span>,</span></span>
<span><span>  "eval_count"</span><span>: </span><span>33</span><span>,</span></span>
<span><span>  "eval_duration"</span><span>: </span><span>552222000</span></span>
<span><span>}</span></span>
```

#### Load a model

If the messages array is empty, the model will be loaded into memory.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "messages": []</span></span>
<span><span>}'</span></span>
```

##### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2024-09-12T21:17:29.110811Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>""</span></span>
<span><span>  },</span></span>
<span><span>  "done_reason"</span><span>: </span><span>"load"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span></span>
<span><span>}</span></span>
```

#### Unload a model

If the messages array is empty and the `keep_alive` parameter is set to `0`, a model will be unloaded from memory.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/chat</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2",</span></span>
<span><span>  "messages": [],</span></span>
<span><span>  "keep_alive": 0</span></span>
<span><span>}'</span></span>
```

##### Response

A single JSON object is returned:

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"llama3.2"</span><span>,</span></span>
<span><span>  "created_at"</span><span>: </span><span>"2024-09-12T21:33:17.547535Z"</span><span>,</span></span>
<span><span>  "message"</span><span>: {</span></span>
<span><span>    "role"</span><span>: </span><span>"assistant"</span><span>,</span></span>
<span><span>    "content"</span><span>: </span><span>""</span></span>
<span><span>  },</span></span>
<span><span>  "done_reason"</span><span>: </span><span>"unload"</span><span>,</span></span>
<span><span>  "done"</span><span>: </span><span>true</span></span>
<span><span>}</span></span>
```

## Create a Model

Create a model from:

-   another model;
-   a safetensors directory; or
-   a GGUF file.

If you are creating a model from a safetensors directory or from a GGUF file, you must [create a blob](https://docs.ollama.com/api#create-a-blob) for each of the files and then use the file name and SHA256 digest associated with each blob in the `files` field.

### Parameters

-   `model`: name of the model to create
-   `from`: (optional) name of an existing model to create the new model from
-   `files`: (optional) a dictionary of file names to SHA256 digests of blobs to create the model from
-   `adapters`: (optional) a dictionary of file names to SHA256 digests of blobs for LORA adapters
-   `template`: (optional) the prompt template for the model
-   `license`: (optional) a string or list of strings containing the license or licenses for the model
-   `system`: (optional) a string containing the system prompt for the model
-   `parameters`: (optional) a dictionary of parameters for the model (see [Modelfile](https://docs.ollama.com/modelfile.md#valid-parameters-and-values) for a list of parameters)
-   `messages`: (optional) a list of message objects used to create a conversation
-   `stream`: (optional) if `false` the response will be returned as a single response object, rather than a stream of objects
-   `quantize` (optional): quantize a non-quantized (e.g. float16) model

#### Quantization types

| Type | Recommended |
| --- | --- |
| q2\_K |  |
| q3\_K\_L |  |
| q3\_K\_M |  |
| q3\_K\_S |  |
| q4\_0 |  |
| q4\_1 |  |
| q4\_K\_M | \* |
| q4\_K\_S |  |
| q5\_0 |  |
| q5\_1 |  |
| q5\_K\_M |  |
| q5\_K\_S |  |
| q6\_K |  |
| q8\_0 | \* |

### Examples

#### Create a new model

Create a new model from an existing model.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/create</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "mario",</span></span>
<span><span>  "from": "llama3.2",</span></span>
<span><span>  "system": "You are Mario from Super Mario Bros."</span></span>
<span><span>}'</span></span>
```

##### Response

A stream of JSON objects is returned:

```
<span><span>{</span><span>"status"</span><span>:</span><span>"reading model metadata"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"creating system layer"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using already created layer sha256:22f7f8ef5f4c791c1b03d7eb414399294764d7cc82c7e94aa81a1feb80a983a2"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using already created layer sha256:8c17c2ebb0ea011be9981cc3922db8ca8fa61e828c5d3f44cb6ae342bf80460b"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using already created layer sha256:7c23fb36d80141c4ab8cdbb61ee4790102ebd2bf7aeff414453177d4f2110e5d"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using already created layer sha256:2e0493f67d0c8c9c68a8aeacdf6a38a2151cb3c4c1d42accf296e19810527988"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using already created layer sha256:2759286baa875dc22de5394b4a925701b1896a7e3f8e53275c36f75a877a82c9"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"writing layer sha256:df30045fe90f0d750db82a058109cecd6d4de9c90a3d75b19c09e5f64580bb42"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"writing layer sha256:f18a68eb09bf925bb1b669490407c1b1251c5db98dc4d3d81f3088498ea55690"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"writing manifest"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"success"</span><span>}</span></span>
```

#### Quantize a model

Quantize a non-quantized model.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/create</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.1:quantized",</span></span>
<span><span>  "from": "llama3.1:8b-instruct-fp16",</span></span>
<span><span>  "quantize": "q4_K_M"</span></span>
<span><span>}'</span></span>
```

##### Response

A stream of JSON objects is returned:

```
<span><span>{</span><span>"status"</span><span>:</span><span>"quantizing F16 model to Q4_K_M"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"creating new layer sha256:667b0c1932bc6ffc593ed1d03f895bf2dc8dc6df21db3042284a6f4416b06a29"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using existing layer sha256:11ce4ee3e170f6adebac9a991c22e22ab3f8530e154ee669954c4bc73061c258"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using existing layer sha256:0ba8f0e314b4264dfd19df045cde9d4c394a52474bf92ed6a3de22a4ca31a177"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using existing layer sha256:56bb8bd477a519ffa694fc449c2413c6f0e1d3b1c88fa7e3c9d88d3ae49d4dcb"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"creating new layer sha256:455f34728c9b5dd3376378bfb809ee166c145b0b4c1f1a6feca069055066ef9a"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"writing manifest"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"success"</span><span>}</span></span>
```

#### Create a model from GGUF

Create a model from a GGUF file. The `files` parameter should be filled out with the file name and SHA256 digest of the GGUF file you wish to use. Use [/api/blobs/:digest](https://docs.ollama.com/api#push-a-blob) to push the GGUF file to the server before calling this API.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/create</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "my-gguf-model",</span></span>
<span><span>  "files": {</span></span>
<span><span>    "test.gguf": "sha256:432f310a77f4650a88d0fd59ecdd7cebed8d684bafea53cbff0473542964f0c3"</span></span>
<span><span>  }</span></span>
<span><span>}'</span></span>
```

##### Response

A stream of JSON objects is returned:

```
<span><span>{</span><span>"status"</span><span>:</span><span>"parsing GGUF"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using existing layer sha256:432f310a77f4650a88d0fd59ecdd7cebed8d684bafea53cbff0473542964f0c3"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"writing manifest"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"success"</span><span>}</span></span>
```

#### Create a model from a Safetensors directory

The `files` parameter should include a dictionary of files for the safetensors model which includes the file names and SHA256 digest of each file. Use [/api/blobs/:digest](https://docs.ollama.com/api#push-a-blob) to first push each of the files to the server before calling this API. Files will remain in the cache until the Ollama server is restarted.

##### Request

```
<span><span>curl</span><span> http://localhost:11434/api/create</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "fred",</span></span>
<span><span>  "files": {</span></span>
<span><span>    "config.json": "sha256:dd3443e529fb2290423a0c65c2d633e67b419d273f170259e27297219828e389",</span></span>
<span><span>    "generation_config.json": "sha256:88effbb63300dbbc7390143fbbdd9d9fa50587b37e8bfd16c8c90d4970a74a36",</span></span>
<span><span>    "special_tokens_map.json": "sha256:b7455f0e8f00539108837bfa586c4fbf424e31f8717819a6798be74bef813d05",</span></span>
<span><span>    "tokenizer.json": "sha256:bbc1904d35169c542dffbe1f7589a5994ec7426d9e5b609d07bab876f32e97ab",</span></span>
<span><span>    "tokenizer_config.json": "sha256:24e8a6dc2547164b7002e3125f10b415105644fcf02bf9ad8b674c87b1eaaed6",</span></span>
<span><span>    "model.safetensors": "sha256:1ff795ff6a07e6a68085d206fb84417da2f083f68391c2843cd2b8ac6df8538f"</span></span>
<span><span>  }</span></span>
<span><span>}'</span></span>
```

##### Response

A stream of JSON objects is returned:

```
<span><span>{</span><span>"status"</span><span>:</span><span>"converting model"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"creating new layer sha256:05ca5b813af4a53d2c2922933936e398958855c44ee534858fcfd830940618b6"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using autodetected template llama3-instruct"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"using existing layer sha256:56bb8bd477a519ffa694fc449c2413c6f0e1d3b1c88fa7e3c9d88d3ae49d4dcb"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"writing manifest"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"success"</span><span>}</span></span>
```

## Check if a Blob Exists

Ensures that the file blob (Binary Large Object) used with create a model exists on the server. This checks your Ollama server and not ollama.com.

### Query Parameters

-   `digest`: the SHA256 digest of the blob

### Examples

#### Request

```
<span><span>curl</span><span> -I</span><span> http://localhost:11434/api/blobs/sha256:29fdb92e57cf0827ded04ae6461b5931d01fa595843f55d36f5b275a52087dd2</span></span>
```

#### Response

Return 200 OK if the blob exists, 404 Not Found if it does not.

## Push a Blob

Push a file to the Ollama server to create a “blob” (Binary Large Object).

### Query Parameters

-   `digest`: the expected SHA256 digest of the file

### Examples

#### Request

```
<span><span>curl</span><span> -T</span><span> model.gguf</span><span> -X</span><span> POST</span><span> http://localhost:11434/api/blobs/sha256:29fdb92e57cf0827ded04ae6461b5931d01fa595843f55d36f5b275a52087dd2</span></span>
```

#### Response

Return 201 Created if the blob was successfully created, 400 Bad Request if the digest used is not expected.

## List Local Models

List models that are available locally.

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/tags</span></span>
```

#### Response

A single JSON object will be returned.

```
<span><span>{</span></span>
<span><span>  "models"</span><span>: [</span></span>
<span><span>    {</span></span>
<span><span>      "name"</span><span>: </span><span>"codellama:13b"</span><span>,</span></span>
<span><span>      "modified_at"</span><span>: </span><span>"2023-11-04T14:56:49.277302595-07:00"</span><span>,</span></span>
<span><span>      "size"</span><span>: </span><span>7365960935</span><span>,</span></span>
<span><span>      "digest"</span><span>: </span><span>"9f438cb9cd581fc025612d27f7c1a6669ff83a8bb0ed86c94fcf4c5440555697"</span><span>,</span></span>
<span><span>      "details"</span><span>: {</span></span>
<span><span>        "format"</span><span>: </span><span>"gguf"</span><span>,</span></span>
<span><span>        "family"</span><span>: </span><span>"llama"</span><span>,</span></span>
<span><span>        "families"</span><span>: </span><span>null</span><span>,</span></span>
<span><span>        "parameter_size"</span><span>: </span><span>"13B"</span><span>,</span></span>
<span><span>        "quantization_level"</span><span>: </span><span>"Q4_0"</span></span>
<span><span>      }</span></span>
<span><span>    },</span></span>
<span><span>    {</span></span>
<span><span>      "name"</span><span>: </span><span>"llama3:latest"</span><span>,</span></span>
<span><span>      "modified_at"</span><span>: </span><span>"2023-12-07T09:32:18.757212583-08:00"</span><span>,</span></span>
<span><span>      "size"</span><span>: </span><span>3825819519</span><span>,</span></span>
<span><span>      "digest"</span><span>: </span><span>"fe938a131f40e6f6d40083c9f0f430a515233eb2edaa6d72eb85c50d64f2300e"</span><span>,</span></span>
<span><span>      "details"</span><span>: {</span></span>
<span><span>        "format"</span><span>: </span><span>"gguf"</span><span>,</span></span>
<span><span>        "family"</span><span>: </span><span>"llama"</span><span>,</span></span>
<span><span>        "families"</span><span>: </span><span>null</span><span>,</span></span>
<span><span>        "parameter_size"</span><span>: </span><span>"7B"</span><span>,</span></span>
<span><span>        "quantization_level"</span><span>: </span><span>"Q4_0"</span></span>
<span><span>      }</span></span>
<span><span>    }</span></span>
<span><span>  ]</span></span>
<span><span>}</span></span>
```

## Show Model Information

Show information about a model including details, modelfile, template, parameters, license, system prompt.

### Parameters

-   `model`: name of the model to show
-   `verbose`: (optional) if set to `true`, returns full data for verbose response fields

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/show</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llava"</span></span>
<span><span>}'</span></span>
```

#### Response

```
<span><span>{</span></span>
<span><span>  "modelfile"</span><span>: </span><span>"# Modelfile generated by </span><span>\"</span><span>ollama show</span><span>\"\n</span><span># To build a new Modelfile based on this one, replace the FROM line with:</span><span>\n</span><span># FROM llava:latest</span><span>\n\n</span><span>FROM /Users/matt/.ollama/models/blobs/sha256:200765e1283640ffbd013184bf496e261032fa75b99498a9613be4e94d63ad52</span><span>\n</span><span>TEMPLATE </span><span>\"\"\"</span><span>{{ .System }}</span><span>\n</span><span>USER: {{ .Prompt }}</span><span>\n</span><span>ASSISTANT: </span><span>\"\"\"\n</span><span>PARAMETER num_ctx 4096</span><span>\n</span><span>PARAMETER stop </span><span>\"\u003c</span><span>/s</span><span>\u003e\"\n</span><span>PARAMETER stop </span><span>\"</span><span>USER:</span><span>\"\n</span><span>PARAMETER stop </span><span>\"</span><span>ASSISTANT:</span><span>\"</span><span>"</span><span>,</span></span>
<span><span>  "parameters"</span><span>: </span><span>"num_keep                       24</span><span>\n</span><span>stop                           </span><span>\"</span><span>&lt;|start_header_id|&gt;</span><span>\"\n</span><span>stop                           </span><span>\"</span><span>&lt;|end_header_id|&gt;</span><span>\"\n</span><span>stop                           </span><span>\"</span><span>&lt;|eot_id|&gt;</span><span>\"</span><span>"</span><span>,</span></span>
<span><span>  "template"</span><span>: </span><span>"{{ if .System }}&lt;|start_header_id|&gt;system&lt;|end_header_id|&gt;</span><span>\n\n</span><span>{{ .System }}&lt;|eot_id|&gt;{{ end }}{{ if .Prompt }}&lt;|start_header_id|&gt;user&lt;|end_header_id|&gt;</span><span>\n\n</span><span>{{ .Prompt }}&lt;|eot_id|&gt;{{ end }}&lt;|start_header_id|&gt;assistant&lt;|end_header_id|&gt;</span><span>\n\n</span><span>{{ .Response }}&lt;|eot_id|&gt;"</span><span>,</span></span>
<span><span>  "details"</span><span>: {</span></span>
<span><span>    "parent_model"</span><span>: </span><span>""</span><span>,</span></span>
<span><span>    "format"</span><span>: </span><span>"gguf"</span><span>,</span></span>
<span><span>    "family"</span><span>: </span><span>"llama"</span><span>,</span></span>
<span><span>    "families"</span><span>: [</span><span>"llama"</span><span>],</span></span>
<span><span>    "parameter_size"</span><span>: </span><span>"8.0B"</span><span>,</span></span>
<span><span>    "quantization_level"</span><span>: </span><span>"Q4_0"</span></span>
<span><span>  },</span></span>
<span><span>  "model_info"</span><span>: {</span></span>
<span><span>    "general.architecture"</span><span>: </span><span>"llama"</span><span>,</span></span>
<span><span>    "general.file_type"</span><span>: </span><span>2</span><span>,</span></span>
<span><span>    "general.parameter_count"</span><span>: </span><span>8030261248</span><span>,</span></span>
<span><span>    "general.quantization_version"</span><span>: </span><span>2</span><span>,</span></span>
<span><span>    "llama.attention.head_count"</span><span>: </span><span>32</span><span>,</span></span>
<span><span>    "llama.attention.head_count_kv"</span><span>: </span><span>8</span><span>,</span></span>
<span><span>    "llama.attention.layer_norm_rms_epsilon"</span><span>: </span><span>0.00001</span><span>,</span></span>
<span><span>    "llama.block_count"</span><span>: </span><span>32</span><span>,</span></span>
<span><span>    "llama.context_length"</span><span>: </span><span>8192</span><span>,</span></span>
<span><span>    "llama.embedding_length"</span><span>: </span><span>4096</span><span>,</span></span>
<span><span>    "llama.feed_forward_length"</span><span>: </span><span>14336</span><span>,</span></span>
<span><span>    "llama.rope.dimension_count"</span><span>: </span><span>128</span><span>,</span></span>
<span><span>    "llama.rope.freq_base"</span><span>: </span><span>500000</span><span>,</span></span>
<span><span>    "llama.vocab_size"</span><span>: </span><span>128256</span><span>,</span></span>
<span><span>    "tokenizer.ggml.bos_token_id"</span><span>: </span><span>128000</span><span>,</span></span>
<span><span>    "tokenizer.ggml.eos_token_id"</span><span>: </span><span>128009</span><span>,</span></span>
<span><span>    "tokenizer.ggml.merges"</span><span>: [], </span><span>// populates if `verbose=true`</span></span>
<span><span>    "tokenizer.ggml.model"</span><span>: </span><span>"gpt2"</span><span>,</span></span>
<span><span>    "tokenizer.ggml.pre"</span><span>: </span><span>"llama-bpe"</span><span>,</span></span>
<span><span>    "tokenizer.ggml.token_type"</span><span>: [], </span><span>// populates if `verbose=true`</span></span>
<span><span>    "tokenizer.ggml.tokens"</span><span>: [] </span><span>// populates if `verbose=true`</span></span>
<span><span>  },</span></span>
<span><span>  "capabilities"</span><span>: [</span><span>"completion"</span><span>, </span><span>"vision"</span><span>]</span></span>
<span><span>}</span></span>
```

## Copy a Model

Copy a model. Creates a model with another name from an existing model.

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/copy</span><span> -d</span><span> '{</span></span>
<span><span>  "source": "llama3.2",</span></span>
<span><span>  "destination": "llama3-backup"</span></span>
<span><span>}'</span></span>
```

#### Response

Returns a 200 OK if successful, or a 404 Not Found if the source model doesn’t exist.

## Delete a Model

Delete a model and its data.

### Parameters

-   `model`: model name to delete

### Examples

#### Request

```
<span><span>curl</span><span> -X</span><span> DELETE</span><span> http://localhost:11434/api/delete</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3:13b"</span></span>
<span><span>}'</span></span>
```

#### Response

Returns a 200 OK if successful, 404 Not Found if the model to be deleted doesn’t exist.

## Pull a Model

Download a model from the ollama library. Cancelled pulls are resumed from where they left off, and multiple calls will share the same download progress.

### Parameters

-   `model`: name of the model to pull
-   `insecure`: (optional) allow insecure connections to the library. Only use this if you are pulling from your own library during development.
-   `stream`: (optional) if `false` the response will be returned as a single response object, rather than a stream of objects

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/pull</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "llama3.2"</span></span>
<span><span>}'</span></span>
```

#### Response

If `stream` is not specified, or set to `true`, a stream of JSON objects is returned: The first object is the manifest:

```
<span><span>{</span></span>
<span><span>  "status"</span><span>: </span><span>"pulling manifest"</span></span>
<span><span>}</span></span>
```

Then there is a series of downloading responses. Until any of the download is completed, the `completed` key may not be included. The number of files to be downloaded depends on the number of layers specified in the manifest.

```
<span><span>{</span></span>
<span><span>  "status"</span><span>: </span><span>"downloading digestname"</span><span>,</span></span>
<span><span>  "digest"</span><span>: </span><span>"digestname"</span><span>,</span></span>
<span><span>  "total"</span><span>: </span><span>2142590208</span><span>,</span></span>
<span><span>  "completed"</span><span>: </span><span>241970</span></span>
<span><span>}</span></span>
```

After all the files are downloaded, the final responses are:

```
<span><span>{</span></span>
<span><span>    "status"</span><span>: </span><span>"verifying sha256 digest"</span></span>
<span><span>}</span></span>
<span><span>{</span></span>
<span><span>    "status"</span><span>: </span><span>"writing manifest"</span></span>
<span><span>}</span></span>
<span><span>{</span></span>
<span><span>    "status"</span><span>: </span><span>"removing any unused layers"</span></span>
<span><span>}</span></span>
<span><span>{</span></span>
<span><span>    "status"</span><span>: </span><span>"success"</span></span>
<span><span>}</span></span>
```

if `stream` is set to false, then the response is a single JSON object:

## Push a Model

Upload a model to a model library. Requires registering for ollama.ai and adding a public key first.

### Parameters

-   `model`: name of the model to push in the form of `<namespace>/<model>:<tag>`
-   `insecure`: (optional) allow insecure connections to the library. Only use this if you are pushing to your library during development.
-   `stream`: (optional) if `false` the response will be returned as a single response object, rather than a stream of objects

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/push</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "mattw/pygmalion:latest"</span></span>
<span><span>}'</span></span>
```

#### Response

If `stream` is not specified, or set to `true`, a stream of JSON objects is returned:

```
<span><span>{ </span><span>"status"</span><span>: </span><span>"retrieving manifest"</span><span> }</span></span>
```

and then:

```
<span><span>{</span></span>
<span><span>  "status"</span><span>: </span><span>"starting upload"</span><span>,</span></span>
<span><span>  "digest"</span><span>: </span><span>"sha256:bc07c81de745696fdf5afca05e065818a8149fb0c77266fb584d9b2cba3711ab"</span><span>,</span></span>
<span><span>  "total"</span><span>: </span><span>1928429856</span></span>
<span><span>}</span></span>
```

Then there is a series of uploading responses:

```
<span><span>{</span></span>
<span><span>  "status"</span><span>: </span><span>"starting upload"</span><span>,</span></span>
<span><span>  "digest"</span><span>: </span><span>"sha256:bc07c81de745696fdf5afca05e065818a8149fb0c77266fb584d9b2cba3711ab"</span><span>,</span></span>
<span><span>  "total"</span><span>: </span><span>1928429856</span></span>
<span><span>}</span></span>
```

Finally, when the upload is complete:

```
<span><span>{</span><span>"status"</span><span>:</span><span>"pushing manifest"</span><span>}</span></span>
<span><span>{</span><span>"status"</span><span>:</span><span>"success"</span><span>}</span></span>
```

If `stream` is set to `false`, then the response is a single JSON object:

## Generate Embeddings

Generate embeddings from a model

### Parameters

-   `model`: name of model to generate embeddings from
-   `input`: text or list of text to generate embeddings for

Advanced parameters:

-   `truncate`: truncates the end of each input to fit within context length. Returns error if `false` and context length is exceeded. Defaults to `true`
-   `options`: additional model parameters listed in the documentation for the [Modelfile](https://docs.ollama.com/modelfile.md#valid-parameters-and-values) such as `temperature`
-   `keep_alive`: controls how long the model will stay loaded into memory following the request (default: `5m`)

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/embed</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "all-minilm",</span></span>
<span><span>  "input": "Why is the sky blue?"</span></span>
<span><span>}'</span></span>
```

#### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"all-minilm"</span><span>,</span></span>
<span><span>  "embeddings"</span><span>: [</span></span>
<span><span>    [</span></span>
<span><span>      0.010071029</span><span>, </span><span>-0.0017594862</span><span>, </span><span>0.05007221</span><span>, </span><span>0.04692972</span><span>, </span><span>0.054916814</span><span>,</span></span>
<span><span>      0.008599704</span><span>, </span><span>0.105441414</span><span>, </span><span>-0.025878139</span><span>, </span><span>0.12958129</span><span>, </span><span>0.031952348</span></span>
<span><span>    ]</span></span>
<span><span>  ],</span></span>
<span><span>  "total_duration"</span><span>: </span><span>14143917</span><span>,</span></span>
<span><span>  "load_duration"</span><span>: </span><span>1019500</span><span>,</span></span>
<span><span>  "prompt_eval_count"</span><span>: </span><span>8</span></span>
<span><span>}</span></span>
```

#### Request (Multiple input)

```
<span><span>curl</span><span> http://localhost:11434/api/embed</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "all-minilm",</span></span>
<span><span>  "input": ["Why is the sky blue?", "Why is the grass green?"]</span></span>
<span><span>}'</span></span>
```

#### Response

```
<span><span>{</span></span>
<span><span>  "model"</span><span>: </span><span>"all-minilm"</span><span>,</span></span>
<span><span>  "embeddings"</span><span>: [</span></span>
<span><span>    [</span></span>
<span><span>      0.010071029</span><span>, </span><span>-0.0017594862</span><span>, </span><span>0.05007221</span><span>, </span><span>0.04692972</span><span>, </span><span>0.054916814</span><span>,</span></span>
<span><span>      0.008599704</span><span>, </span><span>0.105441414</span><span>, </span><span>-0.025878139</span><span>, </span><span>0.12958129</span><span>, </span><span>0.031952348</span></span>
<span><span>    ],</span></span>
<span><span>    [</span></span>
<span><span>      -0.0098027075</span><span>, </span><span>0.06042469</span><span>, </span><span>0.025257962</span><span>, </span><span>-0.006364387</span><span>, </span><span>0.07272725</span><span>,</span></span>
<span><span>      0.017194884</span><span>, </span><span>0.09032035</span><span>, </span><span>-0.051705178</span><span>, </span><span>0.09951512</span><span>, </span><span>0.09072481</span></span>
<span><span>    ]</span></span>
<span><span>  ]</span></span>
<span><span>}</span></span>
```

## List Running Models

List models that are currently loaded into memory.

#### Examples

### Request

```
<span><span>curl</span><span> http://localhost:11434/api/ps</span></span>
```

#### Response

A single JSON object will be returned.

```
<span><span>{</span></span>
<span><span>  "models"</span><span>: [</span></span>
<span><span>    {</span></span>
<span><span>      "name"</span><span>: </span><span>"mistral:latest"</span><span>,</span></span>
<span><span>      "model"</span><span>: </span><span>"mistral:latest"</span><span>,</span></span>
<span><span>      "size"</span><span>: </span><span>5137025024</span><span>,</span></span>
<span><span>      "digest"</span><span>: </span><span>"2ae6f6dd7a3dd734790bbbf58b8909a606e0e7e97e94b7604e0aa7ae4490e6d8"</span><span>,</span></span>
<span><span>      "details"</span><span>: {</span></span>
<span><span>        "parent_model"</span><span>: </span><span>""</span><span>,</span></span>
<span><span>        "format"</span><span>: </span><span>"gguf"</span><span>,</span></span>
<span><span>        "family"</span><span>: </span><span>"llama"</span><span>,</span></span>
<span><span>        "families"</span><span>: [</span><span>"llama"</span><span>],</span></span>
<span><span>        "parameter_size"</span><span>: </span><span>"7.2B"</span><span>,</span></span>
<span><span>        "quantization_level"</span><span>: </span><span>"Q4_0"</span></span>
<span><span>      },</span></span>
<span><span>      "expires_at"</span><span>: </span><span>"2024-06-04T14:38:31.83753-07:00"</span><span>,</span></span>
<span><span>      "size_vram"</span><span>: </span><span>5137025024</span></span>
<span><span>    }</span></span>
<span><span>  ]</span></span>
<span><span>}</span></span>
```

## Generate Embedding

Generate embeddings from a model

### Parameters

-   `model`: name of model to generate embeddings from
-   `prompt`: text to generate embeddings for

Advanced parameters:

-   `options`: additional model parameters listed in the documentation for the [Modelfile](https://docs.ollama.com/modelfile.md#valid-parameters-and-values) such as `temperature`
-   `keep_alive`: controls how long the model will stay loaded into memory following the request (default: `5m`)

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/embeddings</span><span> -d</span><span> '{</span></span>
<span><span>  "model": "all-minilm",</span></span>
<span><span>  "prompt": "Here is an article about llamas..."</span></span>
<span><span>}'</span></span>
```

#### Response

```
<span><span>{</span></span>
<span><span>  "embedding"</span><span>: [</span></span>
<span><span>    0.5670403838157654</span><span>, </span><span>0.009260174818336964</span><span>, </span><span>0.23178744316101074</span><span>,</span></span>
<span><span>    -0.2916173040866852</span><span>, </span><span>-0.8924556970596313</span><span>, </span><span>0.8785552978515625</span><span>,</span></span>
<span><span>    -0.34576427936553955</span><span>, </span><span>0.5742510557174683</span><span>, </span><span>-0.04222835972905159</span><span>,</span></span>
<span><span>    -0.137906014919281</span></span>
<span><span>  ]</span></span>
<span><span>}</span></span>
```

## Version

Retrieve the Ollama version

### Examples

#### Request

```
<span><span>curl</span><span> http://localhost:11434/api/version</span></span>
```

#### Response