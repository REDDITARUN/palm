"""Explicit live verification against free OpenRouter models; credentials never enter files."""
import os,pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parent.parent
model=sys.argv[1] if len(sys.argv)>1 else 'thinkingmachines/inkling:free'
assert model.endswith(':free'), 'This verification script accepts only free models.'
key=subprocess.check_output(['/usr/bin/security','find-generic-password','-s','app.plam.learning','-a','model-openrouter','-w'],text=True).strip()
runtime_base=root/'.test-data/live-agent-runtime';runtime_base.mkdir(parents=True,exist_ok=True)
if not (runtime_base/'Runtime').exists(): (runtime_base/'Runtime').symlink_to(root/'.runtime',target_is_directory=True)
env=dict(os.environ,PALM_LIVE_NOTES="1" if "--notes" in sys.argv else "0",PALM_LIVE_UX="1" if "--ux" in sys.argv else "0",PALM_LIVE_LIFECYCLE='1' if '--lifecycle' in sys.argv else '0',PALM_LIVE_REPO=str(root/".test-data/runtime-repo"),PALM_LIVE_RUNTIME=str(runtime_base),PALM_LIVE_KEY=key,PALM_LIVE_MODEL=model,PALM_LIVE_OUTPUT=str(root/'.test-data/live-api'/model.replace('/','_')),DISABLE_SWIFTLINT='1')
result=subprocess.run(['swift','test','--filter', 'LiveProviderTests/testRealFlashcards' if '--cards' in sys.argv else 'LiveProviderTests/testRealRefinedRecap' if '--notes' in sys.argv else 'LiveProviderTests/testRealChoiceDiagnosticAndSemanticShortAnswers' if '--ux' in sys.argv else 'LiveProviderTests/testRealRepositoryCourseLifecycle' if '--lifecycle' in sys.argv else ('LiveProviderTests/testRealRepositoryExploration' if '--repo' in sys.argv else 'LiveProviderTests/testRealFreeModelLearningPipeline')],cwd=root,env=env)
sys.exit(result.returncode)
