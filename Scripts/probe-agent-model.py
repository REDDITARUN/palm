"""Use the actual OpenCode harness with a free model; no spoofed application headers."""
import json,os,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parent.parent
key=subprocess.check_output(['/usr/bin/security','find-generic-password','-s','app.plam.learning','-a','model-openrouter','-w'],text=True).strip()
work=root/'.test-data/agent-probe';work.mkdir(parents=True,exist_ok=True)
config=work/'opencode.json';config.write_text(json.dumps({'$schema':'https://opencode.ai/config.json','permission':{'*':'deny'},'share':'disabled','autoupdate':False,'agent':{'plam':{'mode':'primary','prompt':'You are a technical learning content generator. Return the final answer directly to the user. Never attempt to invoke tools, use shell commands, or print tool markup. When requested, return one well-formed JSON object with no prose or fences.','tools':{'*':False},'permission':{'*':'deny'}}}}))
env=dict(os.environ,OPENROUTER_API_KEY=key,OPENCODE_CONFIG=str(config),XDG_DATA_HOME=str(work/'data'),XDG_CONFIG_HOME=str(work/'config'))
result=subprocess.run([str(root/'.runtime/opencode'),'run','--agent','plam','--model','openrouter/thinkingmachines/inkling:free','--format','json'],input='Return a JSON object with key closure and a concise correct definition of a Python closure. Return only the JSON object.',env=env,cwd=work,capture_output=True,text=True,timeout=150)
print('exit',result.returncode)
print(result.stdout.replace(key,'[redacted]')[-7000:]);print(result.stderr.replace(key,'[redacted]')[-1000:])
