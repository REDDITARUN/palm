"""Plam's derived memory index. Secrets arrive over stdin, never command arguments."""
import contextlib
import fcntl
import json
import os
import sys

def main():
    payload = json.load(sys.stdin)
    os.environ["MEM0_TELEMETRY"] = "false"
    os.environ["OPENAI_API_KEY"] = "unused-inference-disabled"
    directory = payload["directory"]
    os.makedirs(directory, exist_ok=True)
    os.environ["FASTEMBED_CACHE_PATH"] = os.path.join(directory, "models")
    lock = open(os.path.join(directory, "index.lock"), "a")
    fcntl.flock(lock, fcntl.LOCK_EX)
    # Keep dependency diagnostics away from the machine-readable output.
    with contextlib.redirect_stdout(sys.stderr):
        from mem0 import Memory
        memory = Memory.from_config({
            "version": "v1.1",
            "vector_store": {"provider": "qdrant", "config": {"collection_name": "plam-local-bge", "path": os.path.join(directory, "vectors-bge"), "on_disk": True, "embedding_model_dims": 384}},
            "embedder": {"provider": "fastembed", "config": {"model": "BAAI/bge-small-en-v1.5", "embedding_dims": 384}},
            "llm": {"provider": "openai", "config": {"model": "gpt-4.1-mini"}},
            "history_db_path": os.path.join(directory, "history.sqlite")
        })
        operation = payload["operation"]
        if operation == "add":
            result = memory.add(payload["text"], user_id="plam-local", infer=False, metadata={"canonical_id": payload["id"]})
        elif operation == "search":
            result = memory.search(payload["text"], user_id="plam-local", limit=8)
        elif operation == "delete":
            result = memory.delete(payload["id"])
        else:
            raise ValueError("Unknown operation")
    print(json.dumps(result if isinstance(result, dict) else {"result": result}))

if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Avoid accidentally exposing a credential through provider exception text.
        print("Memory operation failed; the canonical learning record is unchanged.", file=sys.stderr)
        sys.exit(1)
