"""Live free-model compatibility probe. Reads the authorized key from Keychain."""
import json,subprocess,time,urllib.request,urllib.error
key=subprocess.check_output(['/usr/bin/security','find-generic-password','-s','app.plam.learning','-a','model-openrouter','-w'],text=True).strip()
models=['thinkingmachines/inkling:free','thinkingmachines/inkling-small:free','nvidia/nemotron-3.5-lightning:free','minimax/minimax-m3:free']
for model in models:
    assert model.endswith(':free')
    body={'model':model,'messages':[{'role':'user','content':'Return only JSON: {"closure":"a one-sentence accurate definition of a Python closure"}'}],'max_tokens':350,'reasoning':{'effort':'low','exclude':True}}
    req=urllib.request.Request('https://openrouter.ai/api/v1/chat/completions',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+key,'Content-Type':'application/json','X-OpenRouter-Title':'Palm'})
    start=time.time()
    try:
        with urllib.request.urlopen(req,timeout=60) as response: result=json.load(response)
        print(json.dumps({'model':model,'seconds':round(time.time()-start,2),'result':result.get('choices'),'usage':result.get('usage')}).replace(key,'[redacted]'),flush=True)
    except urllib.error.HTTPError as error:
        detail=error.read().decode().replace(key,'[redacted]')
        print(json.dumps({'model':model,'status':error.code,'detail':detail[:2000]}),flush=True)
    except Exception as error: print(model,type(error).__name__,flush=True)
