import customtkinter as ctk
import json
import requests
from threading import Thread, Event
import tkinter as tk
from tkinter import messagebox, filedialog
import re
import time
import subprocess
import csv
import os
from datetime import datetime

class OllamaUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Ollama Interface")
        self.root.geometry("1600x900")
        
        # Configure dark theme
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")
        
        # State management
        self.stop_event = Event()
        self.current_response = None
        
        # Create main layout
        self.create_layout()
        
        # Configure default values
        self.model_var.set("gemma3:27b")
        self.temperature_var.set("0.7")
        self.top_p_var.set("0.9")
        self.top_k_var.set("40")
        self.repeat_penalty_var.set("1.1")
        self.num_ctx_var.set("32768")
        
        # Default system prompt
        default_system = "You are a helpful assistant that provides clear, accurate information."
        self.system_text.insert("1.0", default_system)
        
        # Start GPU monitoring
        self.monitor_gpu()
    
    def create_layout(self):
        # Configure grid layout with 2 columns
        self.root.grid_columnconfigure(0, weight=2)  # Left: Settings & Inputs
        self.root.grid_columnconfigure(1, weight=3)  # Right: Response
        self.root.grid_rowconfigure(0, weight=1)
        
        # Create main frames
        self.left_column = ctk.CTkFrame(self.root)
        self.right_column = ctk.CTkFrame(self.root)
        
        self.left_column.grid(row=0, column=0, sticky="nsew", padx=5, pady=5)
        self.right_column.grid(row=0, column=1, sticky="nsew", padx=5, pady=5)
        
        # Set up the left column (settings & inputs)
        self.setup_left_column()
        
        # Set up the right column (response)
        self.setup_right_column()
    
    def setup_left_column(self):
        # Create a tabview for the left column (Settings, Inputs)
        self.left_tabview = ctk.CTkTabview(self.left_column)
        self.left_tabview.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Add tabs for the left column
        self.left_tabview.add("Prompt")
        self.left_tabview.add("Settings")
        
        # Setup the Prompt tab
        self.setup_prompt_tab()
        
        # Setup the Settings tab (model, parameters)
        self.setup_settings_tab()
    
    def setup_prompt_tab(self):
        # Configure the Prompt tab to expand properly
        prompt_tab = self.left_tabview.tab("Prompt")
        prompt_tab.grid_columnconfigure(0, weight=1)
        prompt_tab.grid_rowconfigure(0, weight=1)
        
        # Create a frame that will contain all prompt elements
        prompt_frame = ctk.CTkFrame(prompt_tab)
        prompt_frame.grid(row=0, column=0, sticky="nsew", padx=5, pady=5)
        prompt_frame.grid_columnconfigure(0, weight=1)
        prompt_frame.grid_rowconfigure(0, weight=1)
        prompt_frame.grid_rowconfigure(1, weight=2)  # User prompt gets more space
        prompt_frame.grid_rowconfigure(2, weight=0)  # Controls don't expand
        
        # System prompt area - set to expand vertically
        system_frame = ctk.CTkFrame(prompt_frame)
        system_frame.grid(row=0, column=0, sticky="nsew", padx=10, pady=(10, 5))
        system_frame.grid_columnconfigure(0, weight=1)
        system_frame.grid_rowconfigure(1, weight=1)
        
        ctk.CTkLabel(system_frame, text="System Prompt:", anchor="w", font=("Verdana", 12, "bold")).grid(row=0, column=0, sticky="ew", padx=5, pady=5)
        
        self.system_text = ctk.CTkTextbox(system_frame, wrap="word", font=("Verdana", 12))
        self.system_text.grid(row=1, column=0, sticky="nsew", padx=5, pady=5)
        
        # User prompt area - set to expand vertically
        user_frame = ctk.CTkFrame(prompt_frame)
        user_frame.grid(row=1, column=0, sticky="nsew", padx=10, pady=(5, 5))
        user_frame.grid_columnconfigure(0, weight=1)
        user_frame.grid_rowconfigure(1, weight=1)
        
        ctk.CTkLabel(user_frame, text="User Prompt:", anchor="w", font=("Verdana", 12, "bold")).grid(row=0, column=0, sticky="ew", padx=5, pady=5)
        
        self.user_text = ctk.CTkTextbox(user_frame, wrap="word", font=("Verdana", 12))
        self.user_text.grid(row=1, column=0, sticky="nsew", padx=5, pady=5)
        
        # Controls - fixed height
        controls_frame = ctk.CTkFrame(prompt_frame)
        controls_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=(5, 10))
        
        # Add batch mode toggle
        batch_frame = ctk.CTkFrame(controls_frame)
        batch_frame.pack(fill="x", pady=10)
        
        self.batch_mode_var = ctk.BooleanVar(value=False)
        batch_checkbox = ctk.CTkCheckBox(
            batch_frame, 
            text="Batch Mode (process each line separately)", 
            variable=self.batch_mode_var,
            command=self.toggle_batch_mode,
            font=("Verdana", 12)
        )
        batch_checkbox.pack(side="left", padx=10)
        
        # CSV file selection (only shown in batch mode)
        self.csv_frame = ctk.CTkFrame(controls_frame)
        
        ctk.CTkLabel(self.csv_frame, text="Output CSV File:", font=("Verdana", 12)).pack(side="left", padx=5)
        
        self.csv_path_var = ctk.StringVar()
        self.csv_entry = ctk.CTkEntry(self.csv_frame, textvariable=self.csv_path_var, width=300, font=("Verdana", 11))
        self.csv_entry.pack(side="left", padx=5)
        
        self.csv_browse_btn = ctk.CTkButton(
            self.csv_frame,
            text="Browse",
            command=self.browse_csv,
            font=("Verdana", 11),
            width=80
        )
        self.csv_browse_btn.pack(side="left", padx=5)
        
        # CSV format options
        self.csv_format_frame = ctk.CTkFrame(controls_frame)
        
        ctk.CTkLabel(self.csv_format_frame, text="CSV Format:", font=("Verdana", 12)).pack(side="left", padx=5)
        
        self.csv_format_var = ctk.StringVar(value="preserve")
        preserve_radio = ctk.CTkRadioButton(
            self.csv_format_frame, 
            text="Preserve Lines", 
            variable=self.csv_format_var, 
            value="preserve",
            font=("Verdana", 11)
        )
        preserve_radio.pack(side="left", padx=5)
        
        flatten_radio = ctk.CTkRadioButton(
            self.csv_format_frame, 
            text="Flatten to Single Line", 
            variable=self.csv_format_var, 
            value="flatten",
            font=("Verdana", 11)
        )
        flatten_radio.pack(side="left", padx=5)
        
        # Run and Stop buttons
        buttons_frame = ctk.CTkFrame(controls_frame)
        buttons_frame.pack(fill="x", pady=10)
        
        self.run_btn = ctk.CTkButton(
            buttons_frame,
            text="Run Prompt",
            command=self.run_prompt,
            font=("Verdana", 12)
        )
        self.run_btn.pack(side="left", padx=10)
        
        self.stop_btn = ctk.CTkButton(
            buttons_frame,
            text="Stop",
            command=self.stop_generation,
            fg_color="darkred",
            font=("Verdana", 12)
        )
        self.stop_btn.pack(side="right", padx=10)
        
        # Quick actions
        quick_frame = ctk.CTkFrame(controls_frame)
        quick_frame.pack(fill="x", pady=10)
        
        ctk.CTkLabel(quick_frame, text="Quick Actions:", font=("Verdana", 12, "bold")).pack(anchor="w", padx=5, pady=5)
        
        quick_buttons = ctk.CTkFrame(quick_frame)
        quick_buttons.pack(fill="x", padx=5, pady=5)
        
        # Clear buttons
        clear_user_btn = ctk.CTkButton(
            quick_buttons,
            text="Clear User Prompt",
            command=lambda: self.user_text.delete("1.0", "end"),
            font=("Verdana", 11)
        )
        clear_user_btn.pack(side="left", padx=5, pady=5)
        
        clear_system_btn = ctk.CTkButton(
            quick_buttons,
            text="Clear System Prompt",
            command=lambda: self.system_text.delete("1.0", "end"),
            font=("Verdana", 11)
        )
        clear_system_btn.pack(side="left", padx=5, pady=5)
        
        clear_response_btn = ctk.CTkButton(
            quick_buttons,
            text="Clear Response",
            command=lambda: self.response_text.delete("1.0", "end"),
            font=("Verdana", 11)
        )
        clear_response_btn.pack(side="left", padx=5, pady=5)
    
    def setup_settings_tab(self):
        # Create a scrollable frame for settings
        settings_frame = ctk.CTkScrollableFrame(self.left_tabview.tab("Settings"))
        settings_frame.pack(fill="both", expand=True, padx=5, pady=5)
        
        # Model selection
        model_frame = ctk.CTkFrame(settings_frame)
        model_frame.pack(fill="x", pady=10)
        
        ctk.CTkLabel(model_frame, text="Model:", anchor="w", font=("Verdana", 12, "bold")).pack(side="left", padx=10)
        self.model_var = ctk.StringVar()
        self.model_entry = ctk.CTkEntry(model_frame, textvariable=self.model_var, width=200, font=("Verdana", 12))
        self.model_entry.pack(side="left", padx=10, fill="x", expand=True)
        
        # Generate parameters section
        gen_params_frame = ctk.CTkFrame(settings_frame)
        gen_params_frame.pack(fill="x", pady=10, padx=5)
        
        ctk.CTkLabel(gen_params_frame, text="Generation Parameters", font=("Verdana", 12, "bold")).pack(pady=5)
        
        # Create a grid for parameters
        params_grid = ctk.CTkFrame(gen_params_frame)
        params_grid.pack(fill="x", padx=10, pady=5, expand=True)
        
        # Temperature
        ctk.CTkLabel(params_grid, text="Temperature:", font=("Verdana", 11)).grid(row=0, column=0, padx=10, pady=5, sticky="w")
        self.temperature_var = ctk.StringVar()
        self.temperature_entry = ctk.CTkEntry(params_grid, textvariable=self.temperature_var, width=60, font=("Verdana", 11))
        self.temperature_entry.grid(row=0, column=1, padx=10, pady=5, sticky="w")
        
        # Top P
        ctk.CTkLabel(params_grid, text="Top P:", font=("Verdana", 11)).grid(row=1, column=0, padx=10, pady=5, sticky="w")
        self.top_p_var = ctk.StringVar()
        self.top_p_entry = ctk.CTkEntry(params_grid, textvariable=self.top_p_var, width=60, font=("Verdana", 11))
        self.top_p_entry.grid(row=1, column=1, padx=10, pady=5, sticky="w")
        
        # Top K
        ctk.CTkLabel(params_grid, text="Top K:", font=("Verdana", 11)).grid(row=2, column=0, padx=10, pady=5, sticky="w")
        self.top_k_var = ctk.StringVar()
        self.top_k_entry = ctk.CTkEntry(params_grid, textvariable=self.top_k_var, width=60, font=("Verdana", 11))
        self.top_k_entry.grid(row=2, column=1, padx=10, pady=5, sticky="w")
        
        # Repeat Penalty
        ctk.CTkLabel(params_grid, text="Repeat Penalty:", font=("Verdana", 11)).grid(row=0, column=2, padx=10, pady=5, sticky="w")
        self.repeat_penalty_var = ctk.StringVar()
        self.repeat_penalty_entry = ctk.CTkEntry(params_grid, textvariable=self.repeat_penalty_var, width=60, font=("Verdana", 11))
        self.repeat_penalty_entry.grid(row=0, column=3, padx=10, pady=5, sticky="w")
        
        # Context Window
        ctk.CTkLabel(params_grid, text="Context Window:", font=("Verdana", 11)).grid(row=1, column=2, padx=10, pady=5, sticky="w")
        self.num_ctx_var = ctk.StringVar()
        self.num_ctx_entry = ctk.CTkEntry(params_grid, textvariable=self.num_ctx_var, width=60, font=("Verdana", 11))
        self.num_ctx_entry.grid(row=1, column=3, padx=10, pady=5, sticky="w")
        
        # Seed
        ctk.CTkLabel(params_grid, text="Seed (optional):", font=("Verdana", 11)).grid(row=2, column=2, padx=10, pady=5, sticky="w")
        self.seed_var = ctk.StringVar()
        self.seed_entry = ctk.CTkEntry(params_grid, textvariable=self.seed_var, width=60, font=("Verdana", 11))
        self.seed_entry.grid(row=2, column=3, padx=10, pady=5, sticky="w")
        
        # Format options (raw, json)
        format_frame = ctk.CTkFrame(settings_frame)
        format_frame.pack(fill="x", pady=10, padx=5)
        
        ctk.CTkLabel(format_frame, text="Output Format", font=("Verdana", 12, "bold")).pack(pady=5)
        
        format_options = ctk.CTkFrame(format_frame)
        format_options.pack(fill="x", padx=10, pady=5)
        
        # Raw option
        self.raw_var = ctk.BooleanVar(value=False)
        raw_checkbox = ctk.CTkCheckBox(format_options, text="Raw Mode", variable=self.raw_var, font=("Verdana", 11))
        raw_checkbox.pack(side="left", padx=10, pady=5)
        
        # JSON option
        self.json_var = ctk.BooleanVar(value=False)
        json_checkbox = ctk.CTkCheckBox(format_options, text="JSON Mode", variable=self.json_var, font=("Verdana", 11))
        json_checkbox.pack(side="left", padx=10, pady=5)
        
        # Stream option
        self.stream_var = ctk.BooleanVar(value=True)
        stream_checkbox = ctk.CTkCheckBox(format_options, text="Stream Response", variable=self.stream_var, font=("Verdana", 11))
        stream_checkbox.pack(side="left", padx=10, pady=5)
        
        # API mode section (Generate vs Chat)
        api_frame = ctk.CTkFrame(settings_frame)
        api_frame.pack(fill="x", pady=10, padx=5)
        
        ctk.CTkLabel(api_frame, text="API Mode", font=("Verdana", 12, "bold")).pack(pady=5)
        
        api_options = ctk.CTkFrame(api_frame)
        api_options.pack(fill="x", padx=10, pady=5)
        
        self.api_mode_var = ctk.StringVar(value="generate")
        generate_radio = ctk.CTkRadioButton(api_options, text="Generate API", variable=self.api_mode_var, value="generate", font=("Verdana", 11))
        generate_radio.pack(side="left", padx=10, pady=5)
        
        chat_radio = ctk.CTkRadioButton(api_options, text="Chat API", variable=self.api_mode_var, value="chat", font=("Verdana", 11))
        chat_radio.pack(side="left", padx=10, pady=5)
        
        # GPU stats
        gpu_frame = ctk.CTkFrame(settings_frame)
        gpu_frame.pack(fill="x", pady=10, padx=5)
        
        ctk.CTkLabel(gpu_frame, text="System Stats", font=("Verdana", 12, "bold")).pack(pady=5)
        
        stats_display = ctk.CTkFrame(gpu_frame)
        stats_display.pack(fill="x", padx=10, pady=5)
        
        self.gpu_var = ctk.StringVar(value="GPU: --")
        self.vram_var = ctk.StringVar(value="VRAM: --")
        
        ctk.CTkLabel(stats_display, textvariable=self.gpu_var, font=("Verdana", 11)).pack(side="left", padx=10, pady=5)
        ctk.CTkLabel(stats_display, textvariable=self.vram_var, font=("Verdana", 11)).pack(side="left", padx=10, pady=5)
    
    def setup_right_column(self):
        # Configure right column for response only
        self.right_column.grid_rowconfigure(0, weight=1)
        self.right_column.grid_columnconfigure(0, weight=1)
        
        # Response frame
        response_frame = ctk.CTkFrame(self.right_column)
        response_frame.grid(row=0, column=0, sticky="nsew", padx=10, pady=10)
        
        response_frame.grid_rowconfigure(1, weight=1)
        response_frame.grid_columnconfigure(0, weight=1)
        
        # Response header with info display
        header_frame = ctk.CTkFrame(response_frame)
        header_frame.grid(row=0, column=0, sticky="ew", padx=5, pady=5)
        
        ctk.CTkLabel(header_frame, text="Response", font=("Verdana", 14, "bold")).pack(side="left", padx=10, pady=5)
        
        self.status_var = ctk.StringVar(value="Ready")
        status_label = ctk.CTkLabel(header_frame, textvariable=self.status_var, font=("Verdana", 11))
        status_label.pack(side="right", padx=10, pady=5)
        
        self.token_count_var = ctk.StringVar(value="Tokens: 0")
        token_label = ctk.CTkLabel(header_frame, textvariable=self.token_count_var, font=("Verdana", 11))
        token_label.pack(side="right", padx=10, pady=5)
        
        # Response text area
        self.response_text = ctk.CTkTextbox(response_frame, wrap="word", font=("Verdana", 12))
        self.response_text.grid(row=1, column=0, padx=10, pady=10, sticky="nsew")
    
    def get_gpu_stats(self):
        try:
            result = subprocess.run(
                ['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,memory.total', '--format=csv,noheader,nounits'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                gpu_util, mem_used, mem_total = map(int, result.stdout.strip().split(','))
                return f"GPU: {gpu_util}%", f"VRAM: {mem_used}/{mem_total}MB"
            else:
                return "GPU: N/A", "VRAM: N/A"
        except:
            return "GPU: N/A", "VRAM: N/A"
    
    def monitor_gpu(self):
        gpu_stat, vram_stat = self.get_gpu_stats()
        self.gpu_var.set(gpu_stat)
        self.vram_var.set(vram_stat)
        self.root.after(1000, self.monitor_gpu)
    
    def toggle_batch_mode(self):
        """Show/hide CSV file selection based on batch mode"""
        if self.batch_mode_var.get():
            self.csv_frame.pack(fill="x", pady=10)
            self.csv_format_frame.pack(fill="x", pady=5)
        else:
            self.csv_frame.pack_forget()
            self.csv_format_frame.pack_forget()
    
    def browse_csv(self):
        """Browse for CSV output file"""
        file_path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")],
            title="Choose output CSV file"
        )
        
        if file_path:
            self.csv_path_var.set(file_path)
    
    def run_prompt(self):
        """Run the prompt in either single or batch mode"""
        self.stop_event.clear()
        
        # Check if we're in batch mode
        if self.batch_mode_var.get():
            self.run_batch_mode()
        else:
            self.run_single_mode()
    
    def run_single_mode(self):
        """Run in single mode (existing behavior)"""
        # Get system and user prompts
        system_prompt = self.system_text.get("1.0", "end-1c").strip()
        user_prompt = self.user_text.get("1.0", "end-1c").strip()
        
        if not user_prompt:
            messagebox.showerror("Error", "Please enter a user prompt.")
            return
        
        # Clear previous response
        self.response_text.delete("1.0", "end")
        
        # Set status
        self.status_var.set("Generating...")
        self.token_count_var.set("Tokens: 0")
        
        # Disable run button during generation
        self.run_btn.configure(state="disabled")
        
        # Start generation thread
        Thread(target=self.generate_response, args=(system_prompt, user_prompt), daemon=True).start()
    
    def run_batch_mode(self):
        """Run in batch mode - process each line separately"""
        system_prompt = self.system_text.get("1.0", "end-1c").strip()
        user_prompts = self.user_text.get("1.0", "end-1c").strip()
        
        if not user_prompts:
            messagebox.showerror("Error", "Please enter user prompts (one per line).")
            return
        
        # Check CSV file path
        csv_path = self.csv_path_var.get()
        if not csv_path:
            messagebox.showerror("Error", "Please select a CSV output file.")
            return
        
        # Clear previous response
        self.response_text.delete("1.0", "end")
        
        # Split user prompts by lines and filter out empty lines
        prompt_lines = [line.strip() for line in user_prompts.split('\n') if line.strip()]
        
        if not prompt_lines:
            messagebox.showerror("Error", "No valid prompts found (empty or whitespace lines).")
            return
        
        # Set status
        self.status_var.set(f"Batch processing: 0/{len(prompt_lines)} complete")
        self.token_count_var.set("Tokens: 0")
        
        # Disable run button during generation
        self.run_btn.configure(state="disabled")
        
        # Start batch processing thread
        Thread(target=self.batch_process, args=(system_prompt, prompt_lines, csv_path), daemon=True).start()
    
    def batch_process(self, system_prompt, prompt_lines, csv_path):
        """Process multiple prompts in batch mode"""
        # Initialize CSV file with headers - use QUOTE_ALL to handle multi-line content
        try:
            with open(csv_path, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.writer(csvfile, quoting=csv.QUOTE_ALL, escapechar='\\')
                writer.writerow(['Timestamp', 'Line_Number', 'Prompt', 'Response', 'Tokens', 'Duration'])
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("Error", f"Could not create CSV file: {str(e)}"))
            self.root.after(0, lambda: self.run_btn.configure(state="normal"))
            return
        
        total_tokens = 0
        completed = 0
        
        # Process each line
        for i, prompt_line in enumerate(prompt_lines, 1):
            if self.stop_event.is_set():
                break
            
            # Update status
            self.root.after(0, lambda i=i, total=len(prompt_lines): 
                            self.status_var.set(f"Processing line {i}/{total}"))
            
            # Add separator before each new prompt
            if i > 1:
                separator = f"\n{'='*50}\n"
                self.root.after(0, lambda sep=separator: 
                              self.response_text.insert("end", sep))
            
            # Show which prompt we're processing
            prompt_header = f"[Line {i}] Prompt: {prompt_line}\n{'─'*30}\n"
            self.root.after(0, lambda header=prompt_header: 
                          self.response_text.insert("end", header))
            
            # Generate response for this line
            start_time = time.time()
            response, tokens = self.generate_batch_response(system_prompt, prompt_line, i)
            duration = time.time() - start_time
            
            # Add line break after response
            self.root.after(0, lambda: self.response_text.insert("end", "\n"))
            
            # Update total tokens
            total_tokens += tokens
            completed += 1
            
            # Update token count display
            self.root.after(0, lambda tokens=total_tokens: 
                          self.token_count_var.set(f"Tokens: {tokens}"))
            
            # Append to CSV - use QUOTE_ALL and proper escaping
            try:
                with open(csv_path, 'a', newline='', encoding='utf-8') as csvfile:
                    writer = csv.writer(csvfile, quoting=csv.QUOTE_ALL, escapechar='\\')
                    
                    # Process response based on chosen format
                    if self.csv_format_var.get() == "flatten":
                        # Replace newlines with spaces and normalize whitespace
                        clean_response = ' '.join(response.split())
                    else:
                        # Preserve newlines but normalize line endings
                        clean_response = response.replace('\r\n', '\n')
                    
                    writer.writerow([
                        datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                        i,
                        prompt_line,
                        clean_response,
                        tokens,
                        f"{duration:.2f}"
                    ])
            except Exception as e:
                self.root.after(0, lambda: messagebox.showerror("Error", f"Could not write to CSV: {str(e)}"))
        
        # Final status update
        final_status = f"Batch complete: {completed}/{len(prompt_lines)} processed"
        if self.stop_event.is_set():
            final_status += " (stopped by user)"
        
        self.root.after(0, lambda: self.status_var.set(final_status))
        self.root.after(0, lambda: self.run_btn.configure(state="normal"))
    
    def generate_batch_response(self, system_prompt, user_prompt, line_number):
        """Generate a single response for batch processing and return it with token count"""
        # Get model and parameters (same as regular generate_response)
        model = self.model_var.get()
        
        try:
            temperature = float(self.temperature_var.get())
            top_p = float(self.top_p_var.get())
            top_k = int(self.top_k_var.get())
            repeat_penalty = float(self.repeat_penalty_var.get())
            num_ctx = int(self.num_ctx_var.get())
        except ValueError:
            temperature = 0.7
            top_p = 0.9
            top_k = 40
            repeat_penalty = 1.1
            num_ctx = 4096
        
        options = {
            "temperature": temperature,
            "top_p": top_p,
            "top_k": top_k,
            "repeat_penalty": repeat_penalty,
            "num_ctx": num_ctx
        }
        
        if self.seed_var.get():
            try:
                options["seed"] = int(self.seed_var.get())
            except ValueError:
                pass
        
        # Determine API endpoint and prepare payload
        if self.api_mode_var.get() == "chat":
            endpoint = "http://localhost:11434/api/chat"
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            messages.append({"role": "user", "content": user_prompt})
            
            payload = {
                "model": model,
                "messages": messages,
                "stream": self.stream_var.get(),
                "options": options
            }
            
            if self.json_var.get():
                payload["format"] = "json"
        else:
            endpoint = "http://localhost:11434/api/generate"
            payload = {
                "model": model,
                "prompt": user_prompt,
                "stream": self.stream_var.get(),
                "options": options
            }
            
            if system_prompt:
                payload["system"] = system_prompt
            
            if self.raw_var.get():
                payload["raw"] = True
            
            if self.json_var.get():
                payload["format"] = "json"
        
        # Make the API call
        full_response = ""
        token_count = 0
        
        try:
            response = requests.post(endpoint, json=payload, stream=self.stream_var.get())
            
            if response.status_code != 200:
                error_message = f"API Error {response.status_code}: {response.text}"
                self.root.after(0, lambda msg=error_message: 
                              self.response_text.insert("end", msg + "\n"))
                return error_message, 0
            
            if self.stream_var.get():
                for line in response.iter_lines():
                    if self.stop_event.is_set():
                        break
                    
                    if line:
                        try:
                            data = json.loads(line)
                            
                            # Handle different response formats
                            if self.api_mode_var.get() == "chat":
                                if 'message' in data and 'content' in data['message']:
                                    response_text = data['message']['content']
                                    full_response += response_text
                                    token_count += 1
                            else:
                                if 'response' in data:
                                    response_text = data['response']
                                    full_response += response_text
                                    token_count += 1
                            
                            # Stream update to response display
                            self.root.after(0, lambda txt=response_text: 
                                          self.response_text.insert("end", txt))
                            self.root.after(0, lambda: self.response_text.see("end"))
                            
                            # Get final token count if available
                            if data.get('done', False) and 'eval_count' in data:
                                token_count = data['eval_count']
                        
                        except json.JSONDecodeError:
                            pass
            else:
                # Non-streaming response
                try:
                    data = response.json()
                    
                    if self.api_mode_var.get() == "chat":
                        if 'message' in data and 'content' in data['message']:
                            full_response = data['message']['content']
                    else:
                        if 'response' in data:
                            full_response = data['response']
                    
                    # Get token count
                    if 'eval_count' in data:
                        token_count = data['eval_count']
                    
                    # Update display
                    self.root.after(0, lambda txt=full_response: 
                                  self.response_text.insert("end", txt))
                    self.root.after(0, lambda: self.response_text.see("end"))
                    
                except json.JSONDecodeError:
                    pass
        
        except Exception as e:
            error_message = f"Error: {str(e)}"
            self.root.after(0, lambda msg=error_message: 
                          self.response_text.insert("end", msg + "\n"))
            return error_message, 0
        
        return full_response, token_count
    
    def generate_response(self, system_prompt, user_prompt):
        """Generate a response based on current settings"""
        # Get model and parameters
        model = self.model_var.get()
        
        try:
            temperature = float(self.temperature_var.get())
            top_p = float(self.top_p_var.get())
            top_k = int(self.top_k_var.get())
            repeat_penalty = float(self.repeat_penalty_var.get())
            num_ctx = int(self.num_ctx_var.get())
        except ValueError:
            # Default values if parsing fails
            temperature = 0.7
            top_p = 0.9
            top_k = 40
            repeat_penalty = 1.1
            num_ctx = 4096
        
        # Options dictionary
        options = {
            "temperature": temperature,
            "top_p": top_p,
            "top_k": top_k,
            "repeat_penalty": repeat_penalty,
            "num_ctx": num_ctx
        }
        
        # Add seed if provided
        if self.seed_var.get():
            try:
                options["seed"] = int(self.seed_var.get())
            except ValueError:
                pass
        
        # Determine API endpoint and prepare payload
        if self.api_mode_var.get() == "chat":
            # Chat API
            endpoint = "http://localhost:11434/api/chat"
            
            messages = []
            if system_prompt:
                messages.append({"role": "system", "content": system_prompt})
            
            messages.append({"role": "user", "content": user_prompt})
            
            payload = {
                "model": model,
                "messages": messages,
                "stream": self.stream_var.get(),
                "options": options
            }
            
            # Add format if JSON mode is selected
            if self.json_var.get():
                payload["format"] = "json"
            
        else:
            # Generate API
            endpoint = "http://localhost:11434/api/generate"
            
            payload = {
                "model": model,
                "prompt": user_prompt,
                "stream": self.stream_var.get(),
                "options": options
            }
            
            # Add system prompt if provided
            if system_prompt:
                payload["system"] = system_prompt
            
            # Add raw mode if selected
            if self.raw_var.get():
                payload["raw"] = True
            
            # Add format if JSON mode is selected
            if self.json_var.get():
                payload["format"] = "json"
        
        # Make the API call
        try:
            self.current_response = requests.post(
                endpoint,
                json=payload,
                stream=self.stream_var.get()
            )
            
            if self.current_response.status_code != 200:
                self.root.after(0, lambda: self.status_var.set(f"Error: {self.current_response.status_code}"))
                self.root.after(0, lambda: messagebox.showerror("API Error", 
                                                            f"Status: {self.current_response.status_code}\nResponse: {self.current_response.text}"))
                return
            
            # Handle streaming vs non-streaming responses
            if self.stream_var.get():
                self.handle_streaming_response()
            else:
                self.handle_non_streaming_response()
                
        except Exception as e:
            self.root.after(0, lambda: self.status_var.set(f"Error: {str(e)[:50]}"))
            self.root.after(0, lambda: messagebox.showerror("Error", f"Exception: {str(e)}"))
        finally:
            self.current_response = None
            # Re-enable run button
            self.root.after(0, lambda: self.run_btn.configure(state="normal"))
    
    def handle_streaming_response(self):
        """Handle streaming API responses"""
        full_response = ""
        token_count = 0
        
        for line in self.current_response.iter_lines():
            if self.stop_event.is_set():
                break
                
            if line:
                try:
                    data = json.loads(line)
                    
                    # Handle different response formats based on API mode
                    if self.api_mode_var.get() == "chat":
                        if 'message' in data and 'content' in data['message']:
                            response_text = data['message']['content']
                            full_response += response_text
                            token_count += 1
                    else:  # generate API
                        if 'response' in data:
                            response_text = data['response']
                            full_response += response_text
                            token_count += 1
                    
                    # Update token count
                    self.root.after(0, lambda count=token_count: self.token_count_var.set(f"Tokens: {count}"))
                    
                    # Update the response display
                    self.root.after(0, lambda r=full_response: self.update_response(r))
                    
                    # Check for completion and stats
                    if data.get('done', False):
                        if 'eval_count' in data:
                            token_count = data['eval_count']
                            duration = data['eval_duration'] / 1e9
                            speed = token_count / duration if duration > 0 else 0
                            self.root.after(0, lambda: self.status_var.set(
                                f"Done. {token_count} tokens in {duration:.1f}s ({speed:.1f} t/s)"))
                            self.root.after(0, lambda count=token_count: self.token_count_var.set(f"Tokens: {count}"))
                        else:
                            self.root.after(0, lambda: self.status_var.set("Done"))
                
                except json.JSONDecodeError:
                    self.root.after(0, lambda: self.status_var.set("Error: JSON decode failed"))
                
    def handle_non_streaming_response(self):
        """Handle non-streaming API responses"""
        try:
            data = self.current_response.json()
            
            # Handle different response formats based on API mode
            if self.api_mode_var.get() == "chat":
                if 'message' in data and 'content' in data['message']:
                    response_text = data['message']['content']
                    self.update_response(response_text)
            else:  # generate API
                if 'response' in data:
                    response_text = data['response']
                    self.update_response(response_text)
            
            # Update token count and stats
            if 'eval_count' in data:
                token_count = data['eval_count']
                duration = data['eval_duration'] / 1e9
                speed = token_count / duration if duration > 0 else 0
                self.root.after(0, lambda: self.status_var.set(
                    f"Done. {token_count} tokens in {duration:.1f}s ({speed:.1f} t/s)"))
                self.root.after(0, lambda count=token_count: self.token_count_var.set(f"Tokens: {token}"))
            else:
                self.root.after(0, lambda: self.status_var.set("Done"))
                
        except json.JSONDecodeError:
            self.root.after(0, lambda: self.status_var.set("Error: JSON decode failed"))
            
    def update_response(self, response):
        """Update the response text display"""
        # Get scroll position to determine if we should auto-scroll
        current_position = self.response_text.yview()
        at_bottom = (current_position[1] >= 0.99)
        
        # Update the text
        self.response_text.delete("1.0", "end")
        self.response_text.insert("1.0", response)
        
        # If we were at the bottom, scroll back to the bottom after the update
        if at_bottom:
            self.response_text.see("end")
            self.response_text.yview_moveto(1.0)
    
    def stop_generation(self):
        """Stop the current generation process"""
        self.stop_event.set()
        if self.current_response:
            try:
                self.current_response.close()
            except:
                pass
        
        self.status_var.set("Stopped")
        self.run_btn.configure(state="normal")

def main():
    root = ctk.CTk()
    app = OllamaUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()