## VectorStoreComponent: Manages vector embeddings for semantic search
##
## Stores embeddings as JSON in agent vault, performs cosine similarity search.
## Pure GDScript implementation (no external dependencies).
##
## Storage: user://markdown_vault/agents/<agent_name>/notes_vectors.json

extends ComponentBase
class_name VectorStoreComponent


## Dictionary mapping note_id → {title_vector, content_vector, combined_vector, metadata}
var vectors: Dictionary = {}

## Agent name for file paths
var agent_name: String = ""


func _on_added(obj: WorldObject) -> void:
	"""Initialize and load vectors from vault."""
	super._on_added(obj)
	agent_name = obj.name
	load_vectors()


func load_vectors() -> void:
	"""Load vectors from JSON file in agent vault."""
	var path: String = _get_vector_path()
	var content: String = MarkdownVault.read_file(path)

	if content.is_empty():
		vectors = {}
		return

	var json = JSON.new()
	var error = json.parse(content)
	if error == OK:
		vectors = json.data
	else:
		push_warning("VectorStore: Failed to parse vectors for %s" % agent_name)
		vectors = {}


func save_vectors() -> void:
	"""Save vectors to JSON file in agent vault."""
	var path: String = _get_vector_path()
	var json_string: String = JSON.stringify(vectors, "\t")
	MarkdownVault.write_file(path, json_string)


func upsert_vector(note_id: String, title_vec: Array, content_vec: Array, combined_vec: Array, metadata: Dictionary) -> void:
	"""Add or update vector entry."""
	vectors[note_id] = {
		"title_vector": title_vec,
		"content_vector": content_vec,
		"combined_vector": combined_vec,
		"metadata": metadata
	}
	save_vectors()


func remove_vector(note_id: String) -> void:
	"""Remove vector entry."""
	if vectors.has(note_id):
		vectors.erase(note_id)
		save_vectors()


func find_similar(query_vector: Array, vector_type: String = "combined_vector", top_n: int = 5, min_similarity: float = 0.0) -> Array[Dictionary]:
	"""Find top N similar vectors by cosine similarity.

	Args:
		query_vector: Embedding to compare
		vector_type: "title_vector", "content_vector", or "combined_vector"
		top_n: Number of results
		min_similarity: Threshold (0.0-1.0)

	Returns:
		Array of {note_id: String, similarity: float} sorted by similarity desc
	"""
	var results: Array[Dictionary] = []

	for note_id in vectors.keys():
		var entry: Dictionary = vectors[note_id]
		if not entry.has(vector_type):
			continue

		var note_vector: Array = entry[vector_type]
		var similarity: float = _cosine_similarity(query_vector, note_vector)

		if similarity >= min_similarity:
			results.append({"note_id": note_id, "similarity": similarity})

	# Sort by similarity descending
	results.sort_custom(func(a, b): return a.similarity > b.similarity)

	# Return top N
	return results.slice(0, min(top_n, results.size()))


func _cosine_similarity(vec_a: Array, vec_b: Array) -> float:
	"""Calculate cosine similarity between two vectors."""
	if vec_a.size() != vec_b.size() or vec_a.size() == 0:
		return 0.0

	var dot_product: float = 0.0
	var norm_a: float = 0.0
	var norm_b: float = 0.0

	for i in range(vec_a.size()):
		var a: float = float(vec_a[i])
		var b: float = float(vec_b[i])
		dot_product += a * b
		norm_a += a * a
		norm_b += b * b

	norm_a = sqrt(norm_a)
	norm_b = sqrt(norm_b)

	if norm_a == 0.0 or norm_b == 0.0:
		return 0.0

	return dot_product / (norm_a * norm_b)


func _get_vector_path() -> String:
	"""Get path to vector JSON file."""
	var sanitized: String = MarkdownVault.sanitize_filename(agent_name)
	return MarkdownVault.AGENTS_PATH + "/" + sanitized + "/notes_vectors.json"
