"""Exercise real local Serena and Mem0 plumbing without sending code to an LLM."""
import asyncio, json, os, pathlib, subprocess, sys, tempfile
ROOT = pathlib.Path(__file__).resolve().parent.parent
RUNTIME = ROOT / '.runtime'

async def check_serena():
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
    env = dict(os.environ, SERENA_HOME=str(ROOT/'.test-data/serena'))
    args = ['start-mcp-server', '--context', 'ide', '--mode', 'planning', '--project', str(ROOT/'.test-data/runtime-repo'), '--open-web-dashboard', 'false', '--enable-web-dashboard', 'false', '--enable-gui-log-window', 'false']
    with open(ROOT/'.test-data/serena-test.log', 'w') as log:
        async with stdio_client(StdioServerParameters(command=str(RUNTIME/'venv/bin/serena'), args=args, env=env), errlog=log) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                names = [t.name for t in (await session.list_tools()).tools]
                assert 'get_symbols_overview' in names and 'find_symbol' in names
                result = await session.call_tool('get_symbols_overview', {'relative_path': 'main.py', 'depth': 1})
                text = '\n'.join(c.text for c in result.content if hasattr(c,'text'))
                assert not result.isError and 'make_counter' in text, text
                print('PASS Serena: initialized MCP and retrieved real Python symbols.')

# Replace only the remote embedding transport. Actual Mem0 and local Qdrant run normally.
PRELUDE = '''
import hashlib, runpy
from types import SimpleNamespace
from mem0.utils.factory import EmbedderFactory
class LocalTestEmbedding:
    config = SimpleNamespace(embedding_dims=384, model="local-test")
    def embed(self, text, *args, **kwargs):
        data=hashlib.sha256(text.encode()).digest()
        return [(data[i %% 32] / 255.0) for i in range(384)]
EmbedderFactory.create = staticmethod(lambda *a, **k: LocalTestEmbedding())
runpy.run_path(%r)['main']()
''' % str(ROOT/'Sources/PalmCore/Resources/memory.py')
def check_memory():
    with tempfile.TemporaryDirectory(prefix='palm-memory-') as directory:
        def operation(name, text='', id=''):
            payload = dict(operation=name, text=text, id=id, key='local-test-only', directory=directory)
            completed = subprocess.run([str(RUNTIME/'venv/bin/python'), '-c', PRELUDE], input=json.dumps(payload), text=True, capture_output=True, timeout=45)
            assert completed.returncode == 0, completed.stderr[-2000:]
            return json.loads(completed.stdout)
        added = operation('add', 'Prefer concise worked examples.', 'canonical-test-id')
        vector_id = added['results'][0]['id']
        found = operation('search', 'Prefer concise worked examples.')
        assert found['results'][0]['metadata']['canonical_id'] == 'canonical-test-id', found
        operation('delete', id=vector_id)
        assert operation('search', 'Prefer concise worked examples.')['results'] == []
        print('PASS Mem0/Qdrant: add, retrieve canonical identity, delete, verify forgotten.')

if __name__ == '__main__':
    asyncio.run(asyncio.wait_for(check_serena(), timeout=120))
    check_memory()
