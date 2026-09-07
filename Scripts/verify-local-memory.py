"""Real Mem0 + FastEmbed + Qdrant test. No cloud credentials or inference calls."""
import json,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parent.parent
memorydir=root/'.test-data/local-memory'
python=root/'.runtime/venv/bin/python'
def run(operation,text='',id=''):
    payload=dict(operation=operation,text=text,id=id,directory=str(memorydir))
    result=subprocess.run([str(python),str(root/'Sources/PalmCore/Resources/memory.py')],input=json.dumps(payload),text=True,capture_output=True,timeout=180)
    assert result.returncode==0,result.stderr[-3000:]
    return json.loads(result.stdout)
added=run('add','I prefer small worked examples before independent code tracing.','real-local-embedding-test')
vectorid=added['results'][0]['id']
hits=run('search','Show a worked code example first.')
assert any(h['id']==vectorid for h in hits['results']),hits
run('delete',id=vectorid)
assert all(h['id']!=vectorid for h in run('search','Show a worked code example first.')['results'])
print('PASS: real local BGE embeddings, Mem0 add/search/delete, and Qdrant persistence; no cloud key used.')
