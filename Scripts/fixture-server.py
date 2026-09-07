"""Local test provider only. Not bundled with the app. Never contacts a real model."""
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

def outline(topic):
    return {"title": "Understanding closures", "summary": "Build a mental model of lexical scope, retained state, and real callbacks.", "outcomes": ["Trace independent closure state", "Explain why captured variables survive", "Apply the idea to a changed example"], "modules": [{"id": "foundations", "title": "01 · A function with a memory", "lessons": [{"id": "closure-state", "title": "Where does the state live?", "objective": "Explain how separate function calls create separate captured environments.", "minutes": 12, "prerequisites": []}]}]}

def lesson():
    def q(id, kind, prompt, answer, options=[], code="", skill="recall"):
        return {"id": id, "kind": kind, "skill": skill, "prompt": prompt, "code": code, "options": options, "answer": answer, "acceptedAnswers": [], "explanation": "Each invocation of makeCounter creates its own lexical environment. The returned function retains access to that environment.", "hints": ["How many times did we call makeCounter?", "Each call creates a new n."], "sourceIDs": []}
    code = "function makeCounter() {\n  let n = 0;\n  return () => ++n;\n}\nconst a = makeCounter();\nconst b = makeCounter();\nconsole.log(a(), a(), b());"
    return {"title": "Where does the state live?", "introduction": "Follow a small function and discover the state it carries with it.", "material": "## A function can remember its surroundings\n\nA **closure** is a function together with access to its lexical environment. When the outer function returns, the inner function can still use variables from that particular invocation.\n\n### One call, one environment\n\nCalling `makeCounter()` twice creates two separate environments. The counters do not share `n`.\n\n> Think about which invocation created a variable, and which function still refers to it.", "workedExample": "### Trace one counter\n\n1. `makeCounter()` creates `n = 0`.\n2. It returns a function that increments that `n`.\n3. The first call returns **1**; the next returns **2**.\n\nA second call to `makeCounter()` starts a different counter at zero.", "takeaways": ["Closures retain access to their lexical environment.", "Separate calls can create independent state.", "Reason about the environment, not just the function text."], "questions": [q("q1", "choice", "Two calls to makeCounter create…", "Two independent environments", ["One shared environment", "Two independent environments", "No retained environment"]), q("q2", "trace", "What three values are printed?", "1, 2, 1", code=code, skill="trace"), q("q3", "explain", "Why can the returned function still access n?", "It retains access to the lexical environment from the outer invocation.", skill="explain"), q("q4", "trueFalse", "Changing a's counter also changes b's counter.", "False", ["True", "False"], skill="transfer")], "sources": []}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def send_json(self, obj, status=200):
        data = json.dumps(obj).encode(); self.send_response(status); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
    def do_GET(self): self.send_json({"data": [{"id": "test-model"}]})
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        prompt = "\n".join(m.get("content", "") for m in body.get("messages", []))
        if "HTTP_429_TEST" in prompt: self.send_json({"error": {"message": "test rate limit"}}, 429); return
        if "Propose a revised version of the complete current note" in prompt: result = "## Scope, with an example\n\nA name is resolved where the function was defined.\n\n```python\ndef outer():\n    value = 3\n    return lambda: value\n```\n\nThe returned function can read `value`.\n\n==The binding stays accessible.=="
        elif "Create a complete learning path" in prompt: result = outline(prompt)
        elif "Generate a complete" in prompt:
            result = lesson()
            result["prediction"] = {"prompt": "A function returns another function that reads `n`. Can the inner function still read `n` after the outer function returns?", "options": ["Yes, it retains access", "No, the name disappears"], "explanation": "**Yes.** A closure retains access to its lexical environment. We can follow the variable through successive calls."}
            for question in result["questions"]: question["language"] = "javascript"
        elif "focused flashcards" in prompt: result = {"cards": [{"front": "What does a **closure** retain?", "back": "Access to its lexical environment, including referenced variables."}, {"front": "Two calls to `makeCounter()` create how many environments?", "back": "**Two** separate environments. Each counter has its own `n`."}, {"front": "Why can a returned function read an outer variable?", "back": "It retains access through its closure.\n\n```mermaid\nflowchart LR\n A[\"Outer call\"] --> B[\"Environment\"]\n C[\"Returned function\"] --> B\n```"}, {"front": "What changes between successive calls to one counter?", "back": "The value in the same retained environment changes; a new environment is not created by each counter call."}]}
        elif "Grade technical reasoning" in prompt: result = {"correct": True, "feedback": "Yes. The returned function retains access to the lexical environment created by the outer call.", "misconception": "", "uncertain": False}
        elif "diagnostic questions" in prompt: result = {"questions": [{"id": "d1", "prompt": "Where can a function use a local variable?", "options": ["Within its lexical scope", "Anywhere in the program", "Only before its first use"]}, {"id": "d2", "prompt": "What happens when a function returns another function?", "options": ["The returned function can be called later", "Both functions run immediately", "The returned function loses all access to variables"]}, {"id": "d3", "prompt": "Two calls to a counter factory create…", "options": ["Independent captured state", "One shared counter", "No state"]}]}
        else: result = "Each call creates a separate environment. Follow which invocation created `n`, then which returned function refers to it. What do you expect to happen on the second call?"
        content = json.dumps(result) if isinstance(result, dict) else result
        if body.get("stream"):
            self.send_response(200); self.send_header("Content-Type", "text/event-stream"); self.end_headers()
            try:
                for chunk in [content[i:i+12] for i in range(0,len(content),12)]:
                    event = {"choices":[{"delta":{"content":chunk}}]}
                    self.wfile.write(("data: " + json.dumps(event) + "\n\n").encode()); self.wfile.flush(); time.sleep(0.04)
                self.wfile.write(b"data: [DONE]\n\n"); self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError): pass
            return
        self.send_json({"id": "test-response", "object": "chat.completion", "created": 1788500000, "model": "test-model", "choices": [{"index": 0, "message": {"role": "assistant", "content": content}, "finish_reason": "stop"}]})

if __name__ == "__main__":
    print("Plam test provider on http://127.0.0.1:49160/v1", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 49160), Handler).serve_forever()
