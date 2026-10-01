from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import subprocess, hashlib, os, json, time
repo=Path('/data/sunyunbo/www/stg-rl-train'); root=Path('/tmp/sunyunbo/stg-laser-batch3');out=repo/'docs/practice-cards/reports/batch3/feasibility'
ids=[f'laser_sp_{fam}_{i:02}' for fam in ['stagger','corridor','sweep','aimed','bars'] for i in range(1,5) if not(fam=='stagger' and i in [1,2])]
env=os.environ.copy();env.update(OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
def task(cid):
 card=root/cid;sha=hashlib.sha256((card/'main.ecl').read_bytes()).hexdigest();d=out/cid/sha[:12];d.mkdir(parents=True,exist_ok=True)
 log=root/'feasibility-logs'/f'{cid}-{sha[:12]}.log';log.parent.mkdir(exist_ok=True)
 cmd=[str(repo/'.venv/bin/python'),'-m','stgtrain.specialist_feasibility',str(card),'--ranks','0','1','2','3','--seeds','1','7','--baselines','--json',str(d)]
 with log.open('w') as f:p=subprocess.run(cmd,cwd=repo,env=env,stdout=f,stderr=subprocess.STDOUT)
 report=d/f'{cid}.json';r=json.loads(report.read_text()) if report.exists() else {}
 hs=[x for x in r.get('runs',[]) if x['mode']=='heuristic'];bs=[x for x in r.get('runs',[]) if x['mode']!='heuristic' and x.get('stationary_qualified') and x['status']=='SUCCESS']
 return {'card':cid,'exit':p.returncode,'report':str(report),'log':str(log),'heuristic_success':sum(x['status']=='SUCCESS' for x in hs),'heuristic_trials':len(hs),'stationary_successes':len(bs),'tool_sha256':r.get('tool_sha256'),'main_sha256':sha}
results=[]
with ThreadPoolExecutor(max_workers=8) as pool:
 futures=[pool.submit(task,cid) for cid in ids]
 for future in as_completed(futures):
  result=future.result();results.append(result);print(json.dumps(result,ensure_ascii=False),flush=True)
  (out/'batch-index.json').write_text(json.dumps({'completed':results,'expected_cards':ids},ensure_ascii=False,indent=2)+'\n')
print('Feasibility batch finished:',len(results),flush=True)
