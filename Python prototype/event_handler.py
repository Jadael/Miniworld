import threading
import time
import re
from tkinter import messagebox
import gui_utils
from gui_utils import set_status, update_prompt_text, update_response_text, append_response_text

class EventHandler:
    def __init__(self, gui):
        self.gui = gui
        # Initialize buffers and state for streaming response handling
        self.complete_response = ""
        self.post_thinking_buffer = ""
        self.thinking_complete = False
        self.command_detected = False
        self.detected_command = None
        self.has_early_stopped = False
        # Add a lock for thread safety
        self.response_lock = threading.Lock()
        # Add a completion event for coordinating turn completion
        self.turn_completed = threading.Event()
    
    def clean_event_message(self, message, actor=None, observer=None):
        """Clean an event message for display"""
        # Import helper from gui_utils if needed
        from gui_utils import clean_event_text
        
        # Call the utility function
        return clean_event_text(message, actor, observer)

    def execute_minimind_turn(self):
        """Execute a turn for the selected minimind"""
        # Check if it's a minimind's turn
        next_character = self.gui.turn_manager.get_next_character()
        
        if next_character == self.gui.player_name:
            messagebox.showinfo("Not Minimind's Turn", "It's your turn, not a minimind's.")
            return
            
        if next_character not in self.gui.miniminds:
            messagebox.showinfo("Error", f"Unknown character: {next_character}")
            return
            
        if self.gui.turn_in_progress:
            return
        
        # Reset turn completion event
        self.turn_completed.clear()
        
        # Set the active minimind to the one whose turn it is
        self.gui.active_minimind = next_character
            
        self.gui.turn_in_progress = True
        set_status(self.gui, f"Processing {self.gui.active_minimind}'s turn...")
        
        # Reset stop streaming flag
        self.gui.stop_streaming.clear()
        
        # Reset streaming state variables
        with self.response_lock:
            self.complete_response = ""
            self.post_thinking_buffer = ""
            self.thinking_complete = False
            self.command_detected = False
            self.detected_command = None
            self.has_early_stopped = False
        
        # Clear response text
        self.gui.response_text.delete("1.0", "end")
        
        # Start in a separate thread to avoid blocking the UI
        threading.Thread(target=self.run_minimind_turn, daemon=True).start()

    def run_minimind_turn(self):
        """Run the minimind turn in a separate thread"""
        try:
            # Get the active minimind
            minimind = self.gui.miniminds[self.gui.active_minimind]
            
            # Get location data from the world
            location = minimind.location
            location_data = self.gui.world.get_location_data(location)
            
            # Update LLM settings
            self.gui.llm.model = self.gui.model_var.get()
            self.gui.llm.temperature = self.gui.temp_var.get()
            self.gui.llm.context_tokens = self.gui.context_var.get()
            
            # Update memory and note count settings
            self.gui.memories_count = self.gui.memories_var.get()
            self.gui.notes_count = self.gui.notes_var.get()
            
            # Construct prompt for the LLM with updated settings, now returns (prompt, system_prompt)
            prompt_result = minimind.construct_prompt(location_data, self.gui.memories_count, self.gui.notes_count)
            
            # Handle both the prompt and system_prompt
            if isinstance(prompt_result, tuple) and len(prompt_result) == 2:
                prompt, system_prompt = prompt_result
            else:
                # Backward compatibility for older method that just returns prompt
                prompt = prompt_result
                system_prompt = None
            
            # Store prompt and system prompt for saving with turn details
            self.prompt = prompt
            self.system_prompt = system_prompt
            
            # Show prompt in debug window
            self.gui.root.after(0, lambda: update_prompt_text(self.gui, prompt))
            
            # Call LLM to get minimind's action with streaming
            self.gui.llm.query_streaming(
                prompt, 
                on_chunk=self.handle_response_chunk,
                on_complete=self.handle_response_complete,
                on_error=self.handle_response_error,
                system=system_prompt  # Pass the system prompt if available
            )
            
            # Wait for streaming to complete with a more definitive check
            while self.gui.turn_in_progress and not self.gui.stop_streaming.is_set():
                time.sleep(0.1)
            
            # Check if streaming is actually complete
            if not self.gui.llm.wait_for_completion(timeout=3.0):
                print("Forcibly cancelling incomplete streaming after timeout")
                self.gui.llm.cancel_streaming()
            
            # Wait for turn to be fully completed
            self.turn_completed.wait(timeout=5.0)
            
            # Final cleanup
            if self.gui.turn_in_progress:
                print("Turn was never properly completed - forcing cleanup")
                self.gui.turn_in_progress = False
                set_status(self.gui, "Turn processing timed out.")
                
        except Exception as e:
            # Fix: Capture the exception message in a variable first
            error_msg = str(e)
            # Then use that variable in the lambda
            self.gui.root.after(0, lambda msg=error_msg: set_status(self.gui, f"Error: {msg}"))
            self.gui.turn_in_progress = False
            
            # Make sure to cancel any ongoing streaming
            self.gui.llm.cancel_streaming()
            
            # Signal turn completion
            self.turn_completed.set()

    def handle_response_chunk(self, chunk):
        """Handle a chunk of text from the streaming response"""
        # Use lock to prevent race conditions
        with self.response_lock:
            # If we've already detected a command, no need to process further
            if self.command_detected:
                return
                
            # Append chunk to UI
            self.gui.root.after(0, lambda text=chunk: append_response_text(self.gui, text))
            
            # Add to complete response
            self.complete_response += chunk
            
            # Look for end of thinking section if we haven't found it yet
            if not self.thinking_complete:
                think_end_match = re.search(r'</think>', self.complete_response)
                if think_end_match:
                    self.thinking_complete = True
                    # Extract everything after </think>
                    end_pos = think_end_match.end()
                    self.post_thinking_buffer = self.complete_response[end_pos:].strip()
            else:
                # Append to post-thinking buffer
                self.post_thinking_buffer += chunk
            
            # Only start looking for commands after the thinking stage
            if self.thinking_complete:
                # Check if this looks like a valid command from a complete line
                command = self.extract_command_from_buffer(self.post_thinking_buffer)
                if command:
                    # Clean the command before processing
                    command = self.clean_event_message(command, 
                                                    self.gui.active_minimind, 
                                                    self.gui.active_minimind)
                    
                    # Debug: Print the detected command to the console
                    print(f"Detected command: {command}")
                    
                    self.command_detected = True
                    self.detected_command = command
                    
                    # Signal early stopping of the generation
                    self.has_early_stopped = True
                    self.gui.stop_streaming.set()
                    
                    # Store thinking part in the minimind
                    self.store_thinking_chain()
                    
                    # Cancel the streaming request explicitly
                    self.gui.llm.cancel_streaming()
                    
                    # Process the command with prompt and response data
                    self.gui.root.after(500, lambda cmd=command: 
                        self.process_command_safely(
                            cmd,
                            getattr(self, 'prompt', None),
                            getattr(self, 'system_prompt', None),
                            self.complete_response
                        )
                    )

    def process_command_safely(self, command, prompt=None, system_prompt=None, llm_response=None):
        """Process command with additional safety checks"""
        try:
            # Verify no active streaming is happening anymore
            self.gui.llm.wait_for_completion(timeout=2.0)
            
            # Proceed with command processing
            print(f"Processing command safely: {command}")
            self.gui.command_processor.process_minimind_action(
                command,
                prompt,
                system_prompt,
                llm_response
            )
            
            # Signal turn completion after processing
            self.turn_completed.set()
        except Exception as e:
            print(f"Error processing command: {str(e)}")
            self.gui.turn_in_progress = False
            self.turn_completed.set()

    def handle_response_complete(self, full_response):
        """Handle completion of the response"""
        with self.response_lock:
            # Don't process if we've already detected and processed a command
            if self.has_early_stopped:
                return
                    
            # Update complete response
            self.complete_response = full_response
            
            # Store thinking chain if we have one
            self.store_thinking_chain()
            
            # Wait to make sure any cancellation hasn't happened
            time.sleep(0.2)
            
            # Check again if we've been early-stopped during the delay
            if self.has_early_stopped:
                return
            
            # Clean action - parse the response to extract just the command
            if not self.detected_command:
                cleaned_action = self.clean_llm_response(full_response)
                
                # Process the action through the command processor with prompt and response data
                self.gui.root.after(0, lambda act=cleaned_action: 
                    self.safe_process_full_response(
                        act, 
                        getattr(self, 'prompt', None),
                        getattr(self, 'system_prompt', None),
                        full_response
                    )
                )
            
            # Set the stop event after a delay to allow processing to complete
            self.gui.root.after(200, lambda: self.gui.stop_streaming.set())

    def safe_process_full_response(self, action, prompt=None, system_prompt=None, llm_response=None):
        """Process a full response safely"""
        try:
            # Wait for any pending operations to complete
            time.sleep(0.3)
            
            # Process the action if we haven't already
            if not self.has_early_stopped and self.gui.turn_in_progress:
                self.gui.command_processor.process_minimind_action(
                    action, 
                    prompt,
                    system_prompt,
                    llm_response
                )
            
            # Signal turn completion
            self.turn_completed.set()
        except Exception as e:
            print(f"Error processing full response: {str(e)}")
            self.gui.turn_in_progress = False
            self.turn_completed.set()

    def handle_response_error(self, error):
        """Handle an error from the LLM"""
        self.gui.root.after(0, lambda: update_response_text(self.gui, f"Error: {str(error)}\n"))
        self.gui.turn_in_progress = False
        self.gui.stop_streaming.set()
        
        # Signal turn completion
        self.turn_completed.set()
    
    def store_thinking_chain(self):
        """Extract and store the thinking chain from the complete response"""
        thought_chain = None
        think_pattern = re.compile(r'<think>(.*?)</think>', re.DOTALL)
        think_match = think_pattern.search(self.complete_response)
        
        if think_match:
            thought_chain = think_match.group(1).strip()
            minimind = self.gui.miniminds[self.gui.active_minimind]
            minimind.store_thought_chain(thought_chain)
    
    def extract_command_from_buffer(self, buffer):
        """Check if the buffer contains a valid command and extract it"""
        if not buffer:
            return None
        
        # Only process buffer if it contains at least one complete line
        # or if we've reached the end of the response
        buffer_ends_with_newline = buffer.endswith('\n')
        contains_newline = '\n' in buffer
        
        # If no complete line and buffer doesn't end with newline, wait for more content
        if not contains_newline and not buffer_ends_with_newline:
            return None
            
        # Split into lines
        lines = buffer.split('\n')
        
        # Process all complete lines (all lines except last if buffer doesn't end with newline)
        processable_lines = lines[:-1] if not buffer_ends_with_newline else lines
        
        for line in processable_lines:
            line = line.strip()
            if not line:
                continue
                
            # Skip lines that look like formatting or explanations
            if line.startswith(('*', '#', '-', '>', '"')) or "command" in line.lower():
                continue
            
            # Check if this looks like a known command type
            cmd_lower = line.lower()
            if any(cmd_lower.startswith(prefix) for prefix in ['go to', 'say', 'note', 'recall', 'shout']):
                # Extract reason if present
                if '|' in line:
                    parts = line.split('|', 1)
                    command = parts[0].strip()
                    reason = parts[1].strip() if len(parts) > 1 else None
                    
                    # Store reason
                    if reason:
                        minimind = self.gui.miniminds[self.gui.active_minimind]
                        minimind.last_command_reason = reason
                    
                    return command
                else:
                    return line
            
            # Check if line matches a proper command but ignoring case and excess whitespace
            command_prefixes = [
                (r'^\s*GO\s+TO\s+', 'go to'),
                (r'^\s*SAY\s+', 'say'),
                (r'^\s*SHOUT\s+', 'shout'),
                (r'^\s*NOTE\s+', 'note'),
                (r'^\s*RECALL\s+', 'recall')
            ]
            
            for pattern, prefix in command_prefixes:
                match = re.match(pattern, line, re.IGNORECASE)
                if match:
                    # This is a command, extract content and fix formatting
                    content = line[match.end():].strip()
                    
                    # Handle special case for NOTE command which should have a title and content
                    if prefix == 'note' and ':' in content:
                        title, body = content.split(':', 1)
                        return f"{prefix} {title.strip()}: {body.strip()}"
                    
                    return f"{prefix} {content}"
        
        # No valid command found in this buffer yet
        return None

    def clean_llm_response(self, response):
        """Clean the LLM response to extract just the command"""
        # If we've already detected a command during streaming, return it
        if self.detected_command:
            return self.detected_command
            
        # First, check if there's a <think>...</think> block - this should already be stored
        think_pattern = re.compile(r'<think>.*?</think>', re.DOTALL)
        response_cleaned = think_pattern.sub('', response).strip()
        
        # Process the response line by line
        lines = response_cleaned.split('\n')
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            # Skip lines that look like formatting or explanations
            if line.startswith(('*', '#', '-', '>', '"')) or "command" in line.lower():
                continue
            
            # Check if line has a pipe symbol for reasoning
            if '|' in line:
                parts = line.split('|', 1)
                command = parts[0].strip()
                reason = parts[1].strip() if len(parts) > 1 else None
                
                # Check if command is valid
                cmd_lower = command.lower()
                if any(cmd_lower.startswith(prefix) for prefix in ['go to', 'say', 'note', 'recall', 'shout']):
                    # Store reason if provided
                    if reason:
                        minimind = self.gui.miniminds[self.gui.active_minimind]
                        minimind.last_command_reason = reason
                    return command
            
            # Check if line is a valid command without reasoning
            cmd_lower = line.lower()
            if any(cmd_lower.startswith(prefix) for prefix in ['go to', 'say', 'note', 'recall', 'shout']):
                return line
        
        # Fallback to first non-empty line
        for line in lines:
            line = line.strip()
            if line and not line.startswith(('*', '#', '-', '>')):
                return line
        
        # If all else fails, return the cleaned response
        return response_cleaned
