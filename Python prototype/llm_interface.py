import requests
import json
import threading
import numpy as np
import time

class OllamaInterface:
    def __init__(self, model="deepseek-r1:14b", temperature=0.7, context_tokens=32768, repeat_penalty=1.1, embedding_model="all-minilm", stop_tokens=None, system=""):
        """Initialize the Ollama API interface"""
        self.base_url = "http://localhost:11434/api"
        self.model = model
        self.embedding_model = embedding_model
        self.temperature = temperature
        self.context_tokens = context_tokens
        self.repeat_penalty = repeat_penalty
        # Default stop tokens for cutting off explanations
        # We avoid using newline as a stop token to preserve the thinking process
        self.stop_tokens = stop_tokens or ["Explanation:", "Let me explain:", "To explain my reasoning:"]
        
        # Default to empty system message
        self.system = system
        
        # Add tracking for active streaming requests
        self.active_stream_thread = None
        self.stream_canceled = threading.Event()
        self.stream_completed = threading.Event()
        
        # Add thread lock for thread management
        self.thread_lock = threading.Lock()
    
    def query(self, prompt, system=None):
        """Query the Ollama API and get a response
        
        Args:
            prompt: The prompt to send to the API
            system: Optional system message to use (overrides the default)
        """
        # Use provided system message or fall back to the default
        system_message = system if system is not None else self.system
        
        payload = {
            "model": self.model,
            "prompt": prompt,
            "system": system_message,
            "stream": False,
            "options": {
                "temperature": self.temperature,
                "num_ctx": self.context_tokens,
                "repeat_penalty": self.repeat_penalty,
                "stop": self.stop_tokens
            }
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/generate",
                json=payload
            )
            
            if response.status_code != 200:
                return f"Error: API returned status code {response.status_code}"
                
            result = response.json()
            return result.get("response", "")
        except Exception as e:
            return f"Error: {str(e)}"
    
    def query_streaming(self, prompt, on_chunk=None, on_complete=None, on_error=None, system=None):
        """Query the Ollama API with streaming responses
        
        Args:
            prompt: The prompt to send to the API
            on_chunk: Callback for each chunk of the response
            on_complete: Callback when the response is complete
            on_error: Callback for errors
            system: Optional system message to use (overrides the default)
        """
        # Reset cancellation and completion flags
        self.stream_canceled.clear()
        self.stream_completed.clear()
        
        # Use provided system message or fall back to the default
        system_message = system if system is not None else self.system
        
        payload = {
            "model": self.model,
            "prompt": prompt,
            "system": system_message,
            "stream": True,
            "options": {
                "temperature": self.temperature,
                "num_ctx": self.context_tokens,
                "repeat_penalty": self.repeat_penalty,
                "stop": self.stop_tokens
            }
        }
        
        # Create and start a new streaming thread with thread-safe handling
        with self.thread_lock:
            # Create a new thread
            new_thread = threading.Thread(
                target=self._stream_response,
                args=(payload, on_chunk, on_complete, on_error),
                daemon=True
            )
            
            # Store the thread reference
            self.active_stream_thread = new_thread
            
            # Start the thread
            new_thread.start()
    
    def _stream_response(self, payload, on_chunk, on_complete, on_error):
        """Process a streaming response"""
        response = None
        try:
            response = requests.post(
                f"{self.base_url}/generate",
                json=payload,
                stream=True
            )
            
            if response.status_code != 200:
                if on_error:
                    on_error(f"API returned status code {response.status_code}")
                self.stream_completed.set()
                return
                
            # Buffer for full response
            full_response = ""
            
            for line in response.iter_lines():
                # Check if the stream has been canceled
                if self.stream_canceled.is_set():
                    if response and hasattr(response, 'close'):
                        response.close()
                    break
                    
                if line:
                    try:
                        data = json.loads(line)
                        if 'response' in data:
                            chunk = data['response']
                            full_response += chunk
                            
                            # Call the callback for each chunk
                            if on_chunk:
                                on_chunk(chunk)
                        
                        # Check if done
                        if data.get('done', False):
                            if on_complete and not self.stream_canceled.is_set():
                                on_complete(full_response)
                            self.stream_completed.set()
                            return
                    except json.JSONDecodeError:
                        continue
                        
            # If we exit the loop without hitting 'done', make sure we mark as completed
            self.stream_completed.set()
            
        except Exception as e:
            if on_error:
                on_error(str(e))
            # Make sure to set the completed flag even on error
            self.stream_completed.set()
        finally:
            # Clean up the response if it exists
            if response and hasattr(response, 'close'):
                response.close()
            self.stream_completed.set()

    def cancel_streaming(self):
        """Cancel any ongoing streaming request"""
        # Get current thread for comparison
        current_thread = threading.current_thread()
        
        # Use thread-safe access to active_stream_thread
        with self.thread_lock:
            stream_thread = self.active_stream_thread
            
            if stream_thread and stream_thread.is_alive():
                # Set the canceled flag
                self.stream_canceled.set()
                
                # Wait for the streaming to actually stop (with timeout)
                completed = self.stream_completed.wait(timeout=2.0)
                
                # Only join if we're not trying to join ourselves
                if stream_thread != current_thread:
                    try:
                        # Force joining the thread to make sure it's done
                        stream_thread.join(timeout=1.0)
                    except RuntimeError as e:
                        # Log the error but continue
                        print(f"Warning: Could not join thread: {e}")
                
                # Reset the active thread reference
                self.active_stream_thread = None
                
                return completed
                
        return True
        
    def wait_for_completion(self, timeout=5.0):
        """Wait for the current streaming request to complete"""
        # Get current thread for comparison
        current_thread = threading.current_thread()
        
        # Use thread-safe access to active_stream_thread
        with self.thread_lock:
            stream_thread = self.active_stream_thread
            
            if stream_thread and stream_thread.is_alive():
                # Wait for the completion event with timeout
                completed = self.stream_completed.wait(timeout=timeout)
                
                # If still not complete, try to cancel
                if not completed:
                    # Set the canceled flag first
                    self.stream_canceled.set()
                    
                    # Only join if we're not trying to join ourselves
                    if stream_thread != current_thread:
                        try:
                            # Try to join with timeout
                            stream_thread.join(timeout=1.0)
                        except RuntimeError as e:
                            # Log the error but continue
                            print(f"Warning: Could not join thread: {e}")
                    
                    # Reset the active thread reference
                    self.active_stream_thread = None
                    
                return self.stream_completed.is_set()
                
        return True

    def get_embeddings(self, texts, model=None):
        """Generate embeddings for a single text or list of texts
        
        Args:
            texts: A string or list of strings to generate embeddings for
            model: Optional model to use for embeddings (defaults to self.embedding_model)
            
        Returns:
            A list of embedding vectors (list of floats)
        """
        if model is None:
            model = self.embedding_model
            
        # Handle single text input
        if isinstance(texts, str):
            texts = [texts]
            
        payload = {
            "model": model,
            "input": texts,
            "truncate": True  # Automatically truncate to fit context
        }
        
        try:
            response = requests.post(
                f"{self.base_url}/embed",
                json=payload
            )
            
            if response.status_code != 200:
                raise Exception(f"API returned status code {response.status_code}")
                
            result = response.json()
            embeddings = result.get("embeddings", [])
            
            if not embeddings:
                raise Exception("No embeddings returned from API")
                
            return embeddings
            
        except Exception as e:
            print(f"Error generating embeddings: {str(e)}")
            # Return zero vectors as fallback
            dimension = 384  # Default dimension for all-minilm model
            return [np.zeros(dimension).tolist() for _ in range(len(texts))]
            
    def get_combined_embedding(self, title, content, weights=(0.3, 0.7)):
        """Get embeddings for title and content, and combine them with weighted average
        
        Args:
            title: The title text
            content: The content text
            weights: Tuple of (title_weight, content_weight)
            
        Returns:
            Tuple of (title_embedding, content_embedding, combined_embedding)
        """
        # Get embeddings for title and content
        embeddings = self.get_embeddings([title, content])
        
        if len(embeddings) != 2:
            # Handle error case - return zero vectors
            dimension = 384  # Default dimension
            zero_vec = np.zeros(dimension).tolist()
            return zero_vec, zero_vec, zero_vec
            
        title_embedding = embeddings[0]
        content_embedding = embeddings[1]
        
        # Calculate weighted average
        title_weight, content_weight = weights
        title_array = np.array(title_embedding)
        content_array = np.array(content_embedding)
        
        combined = title_weight * title_array + content_weight * content_array
        
        # Normalize the combined vector
        norm = np.linalg.norm(combined)
        if norm > 0:
            combined = combined / norm
            
        return title_embedding, content_embedding, combined.tolist()
