import os
import json
import numpy as np
from datetime import datetime

class NoteVectorStore:
    """A simple vector store for Minimind notes"""
    
    def __init__(self, minimind_name):
        """Initialize the vector store for a specific minimind"""
        self.minimind_name = minimind_name
        self.minimind_path = os.path.join("miniminds", minimind_name)
        self.vector_db_path = os.path.join(self.minimind_path, "note_vectors.json")
        self.vectors = self._load_vectors()
        
    def _load_vectors(self):
        """Load vectors from the store file"""
        if os.path.exists(self.vector_db_path):
            try:
                with open(self.vector_db_path, 'r', encoding="utf-8") as f:
                    return json.load(f)
            except:
                return {}
        return {}
    
    def _save_vectors(self):
        """Save vectors to the store file"""
        os.makedirs(os.path.dirname(self.vector_db_path), exist_ok=True)
        with open(self.vector_db_path, 'w', encoding="utf-8") as f:
            json.dump(self.vectors, f, indent=2)
            
    def add_vector(self, note_id, title_vector, content_vector, combined_vector, metadata=None):
        """Add a vector to the store"""
        if metadata is None:
            metadata = {}
            
        # Add timestamp
        metadata["timestamp"] = datetime.now().isoformat()
        
        self.vectors[note_id] = {
            "title_vector": title_vector,
            "content_vector": content_vector,
            "combined_vector": combined_vector,
            "metadata": metadata
        }
        self._save_vectors()
        
    def update_vector(self, note_id, title_vector, content_vector, combined_vector, metadata=None):
        """Update a vector in the store"""
        if note_id not in self.vectors:
            self.add_vector(note_id, title_vector, content_vector, combined_vector, metadata)
            return
            
        if metadata:
            # Update metadata, preserving existing metadata
            self.vectors[note_id]["metadata"].update(metadata)
        
        # Update vectors
        self.vectors[note_id]["title_vector"] = title_vector
        self.vectors[note_id]["content_vector"] = content_vector
        self.vectors[note_id]["combined_vector"] = combined_vector
        
        # Update timestamp
        self.vectors[note_id]["metadata"]["updated_at"] = datetime.now().isoformat()
        
        self._save_vectors()
        
    def remove_vector(self, note_id):
        """Remove a vector from the store"""
        if note_id in self.vectors:
            del self.vectors[note_id]
            self._save_vectors()
            

    def get_similar_notes(self, query_vector, vector_type="combined", top_n=5, min_similarity=0.0):
        """Get the top N similar notes by cosine similarity
        
        Args:
            query_vector: The query vector to compare against
            vector_type: Which vector to use (title_vector, content_vector, or combined_vector)
            top_n: Number of notes to return
            min_similarity: Minimum similarity threshold (default 0.0 - no threshold)
        
        Returns:
            List of tuples [(note_id, similarity_score), ...]
        """
        if not self.vectors:
            return []
            
        # Calculate similarities
        results = []
        for note_id, data in self.vectors.items():
            if vector_type in data:
                note_vector = data[vector_type]
                similarity = self._cosine_similarity(query_vector, note_vector)
                
                # Only include results above minimum similarity if specified
                if similarity >= min_similarity:
                    results.append((note_id, similarity))
        
        # Sort by similarity (highest first)
        results.sort(key=lambda x: x[1], reverse=True)
        
        # Return top N results
        return results[:top_n]
    
    def _cosine_similarity(self, vec_a, vec_b):
        """Calculate cosine similarity between two vectors"""
        vec_a = np.array(vec_a)
        vec_b = np.array(vec_b)
        
        dot_product = np.dot(vec_a, vec_b)
        norm_a = np.linalg.norm(vec_a)
        norm_b = np.linalg.norm(vec_b)
        
        if norm_a == 0 or norm_b == 0:
            return 0
            
        return dot_product / (norm_a * norm_b)
