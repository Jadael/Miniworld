import random
import re

def perturb_chain_of_thought(text):
    # Split text into words
    words = text.split()
    
    if not words:
        return ""
        
    # Create chunks with random lengths between 3-7 words
    chunks = []
    i = 0
    while i < len(words):
        chunk_size = min(random.randint(2, 7), len(words) - i)
        chunk = words[i:i+chunk_size]
        chunks.append(chunk)
        i += chunk_size
        
    # Remove duplicate chunks by converting to a set of tuples and back
    unique_chunks = [list(c) for c in {tuple(chunk) for chunk in chunks}]
    
    # Shuffle the order of chunks
    random.shuffle(unique_chunks)
    
    # Flatten the chunks and join into one line
    return ' '.join(word for chunk in unique_chunks for word in chunk)

# def perturb_chain_of_thought(cot_text):
#     """
#     Perturbs a chain of thought to maintain semantic content while breaking repetition patterns.
#     Uses a combination of paragraph sampling, shuffling, and selective token masking.
    
#     Args:
#         cot_text (str): The original chain of thought text
        
#     Returns:
#         str: A perturbed version of the chain of thought
#     """
#     if not cot_text or len(cot_text) < 20:
#         return cot_text
        
#     # Split into paragraphs (preserving any line breaks)
#     paragraphs = [p for p in re.split(r'\n\s*\n', cot_text) if p.strip()]
    
#     if len(paragraphs) <= 1:
#         # If there's only one paragraph, split by sentences instead
#         sentences = [s.strip() for s in re.split(r'(?<=[.!?])\s+', cot_text) if s.strip()]
        
#         if len(sentences) <= 3:
#             # For very short content, just do light masking
#             return mask_tokens(cot_text)
            
#         # Sample 70-90% of sentences
#         sampling_ratio = random.uniform(0.7, 0.9)
#         num_to_keep = max(3, int(len(sentences) * sampling_ratio))
#         kept_sentences = random.sample(sentences, num_to_keep)
        
#         # Shuffle the order slightly (not completely)
#         if len(kept_sentences) > 3:
#             segments = chunk_list(kept_sentences, max(2, len(kept_sentences) // 3))
#             random.shuffle(segments)
#             kept_sentences = [sent for segment in segments for sent in segment]
        
#         # Apply light token masking
#         for i in range(len(kept_sentences)):
#             kept_sentences[i] = mask_tokens(kept_sentences[i], mask_probability=0.08)
        
#         return ' '.join(kept_sentences)
#     else:
#         # For multi-paragraph text
#         # Sample 60-80% of paragraphs
#         sampling_ratio = random.uniform(0.6, 0.8)
#         num_to_keep = max(2, int(len(paragraphs) * sampling_ratio))
#         kept_paragraphs = random.sample(paragraphs, num_to_keep)
        
#         # Shuffle the order slightly (keeping some logical flow)
#         if len(kept_paragraphs) > 3:
#             segments = chunk_list(kept_paragraphs, max(2, len(kept_paragraphs) // 3))
#             random.shuffle(segments)
#             kept_paragraphs = [para for segment in segments for para in segment]
        
#         # Apply token masking and return
#         perturbed_paragraphs = [mask_tokens(p, mask_probability=0.05) for p in kept_paragraphs]
#         return '\n\n'.join(perturbed_paragraphs)

def mask_tokens(text, mask_probability=0.1):
    """Mask random tokens/words in text, focusing on adjectives and adverbs"""
    # Skip very short texts
    if len(text) < 15:
        return text
    
    # Split into words, preserving spaces and punctuation
    tokens = re.findall(r'\b\w+\b|[^\w\s]|\s+', text)
    
    # Define adjective/adverb ending patterns (higher chance of masking these)
    adj_adv_patterns = [r'ly$', r'ous$', r'ful$', r'ish$', r'ive$', r'est$']
    
    for i, token in enumerate(tokens):
        if not re.match(r'\w+', token):  # Skip punctuation and whitespace
            continue
            
        # Higher probability for longer words and adjectives/adverbs
        token_probability = mask_probability
        
        # Increase probability for longer words
        if len(token) > 6:
            token_probability *= 1.5
            
        # Increase probability for likely adjectives/adverbs
        if any(re.search(pattern, token.lower()) for pattern in adj_adv_patterns):
            token_probability *= 2
            
        # Lower probability for important structural words
        if token.lower() in ['i', 'me', 'my', 'mine', 'is', 'are', 'was', 'were', 
                            'the', 'a', 'an', 'this', 'that', 'these', 'those',
                            'not', 'no', 'yes']:
            token_probability *= 0.3
        
        # Apply masking based on calculated probability
        if random.random() < token_probability:
            # Use varying mask styles
            mask_styles = ['[...]', '[•••]', '[---]', '[___]']
            tokens[i] = random.choice(mask_styles)
    
    return ''.join(tokens)

def chunk_list(lst, chunk_size):
    """Split a list into chunks of approximately equal size, preserving order within chunks"""
    return [lst[i:i + chunk_size] for i in range(0, len(lst), chunk_size)]
