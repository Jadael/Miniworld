# Shoggoth LLM Configuration

Settings for the Shoggoth daemon (LLM interface).

Most core settings (model, temperature, host) are managed via `user://shoggoth_config.cfg`
for backward compatibility. These settings extend that configuration.

---

## Retry Behavior

**max_retries**: 3
_Maximum number of retry attempts for failed LLM requests_

**retry_delay**: 1.0
_Seconds to wait between retry attempts_

---

## Models

**embedding_model**: embeddinggemma
_Model used for generating text embeddings (semantic search)_

---

## Notes

- The primary generation model, temperature, and host are configured via the Godot UI
- These settings affect error recovery and semantic search functionality
- Changes to embedding_model require restart to take effect
