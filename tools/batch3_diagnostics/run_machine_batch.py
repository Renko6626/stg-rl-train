from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import subprocess,os,json
repo=Path('/data/sunyunbo/www/stg-rl-train');root=Path('/tmp/sunyunbo/stg-laser-batch3');out=repo/'docs/practice-cards/reports/batch3'
ids=[f'laser_sp_{f}_{i:02}' for f in ['stagger','corridor','sweep','aimed','bars'] for i in range(1,5)]
def task(cid):
 p=out/(cid+'.machine.json');proc=subprocess.run([str(repo/'.venv/bin/python'),'-m','stgtrain.specialist_validate',str(root/cid),'--json',str(p)],cwd=repo,capture_output=True,text=True)
 r=json.loads(p.read_text()) if p.exists() else {};return {'card':cid,'exit':proc.returncode,'ok':r.get('ok'),'errors':r.get('errors',[])[:40],'report':str(p),'output':proc.stdout[-1500:],'stderr':proc.stderr[-1000:]}
results=[]
with ThreadPoolExecutor(max_workers=4) as pool:
 for future in as_completed([pool.submit(task,c) for c in ids]):
  x=future.result();results.append(x);print(json.dumps(x,ensure_ascii=False),flush=True)
  (out/'machine-batch-index.json').write_text(json.dumps({'completed':results,'expected_cards':ids},ensure_ascii=False,indent=2)+'\n')
print('Machine batch finished:',len(results),flush=True)
