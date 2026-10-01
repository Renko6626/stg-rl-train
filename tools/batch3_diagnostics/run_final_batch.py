from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import subprocess,hashlib,json,os
repo=Path('/data/sunyunbo/www/stg-rl-train');root=Path('/tmp/sunyunbo/stg-laser-batch3');out=repo/'docs/practice-cards/reports/batch3/final';out.mkdir(parents=True,exist_ok=True)
ids=[f'laser_sp_{f}_{i:02}' for f in ['stagger','corridor','sweep','aimed','bars'] for i in range(1,5)]
def hashes(p):return {n:hashlib.sha256((p/n).read_bytes()).hexdigest() for n in ['main.ecl','meta.toml','TASK.md','machine-spec.json']}
manifest={cid:hashes(root/cid) for cid in ids};(out/'frozen-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
def task(cid):
 p=root/cid;shas=manifest[cid];snapshot=hashlib.sha256(json.dumps(shas,sort_keys=True).encode()).hexdigest()[:12]
 reports=out/cid;reports.mkdir(exist_ok=True);logs=repo/'runs/laser-specialist-batch3-validation'/cid/snapshot;logs.mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update(OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',STG_SPECIALIST_TRAJECTORY_DIR=str(logs/'trajectories'))
 machine=reports/(cid+'.machine.json');flog=logs/'machine.log'
 with flog.open('w') as f:m=subprocess.run([str(repo/'.venv/bin/python'),'-m','stgtrain.specialist_validate',str(p),'--json',str(machine)],cwd=repo,env=env,stdout=f,stderr=subprocess.STDOUT)
 if hashes(p)!=shas:raise RuntimeError(cid+' changed during mechanical matrix')
 with (logs/'feasibility.log').open('w') as f:v=subprocess.run([str(repo/'.venv/bin/python'),'-m','stgtrain.specialist_feasibility',str(p),'--ranks','0','1','2','3','--seeds','1','7','--baselines','--json',str(reports/'feasibility')],cwd=repo,env=env,stdout=f,stderr=subprocess.STDOUT)
 if hashes(p)!=shas:raise RuntimeError(cid+' changed during player matrix')
 mr=json.loads(machine.read_text()) if machine.exists() else {};fp=reports/'feasibility'/(cid+'.json');fr=json.loads(fp.read_text()) if fp.exists() else {}
 hs=[x for x in fr.get('runs',[]) if x['mode']=='heuristic'];bs=[x for x in fr.get('runs',[]) if x['mode']!='heuristic' and x.get('stationary_qualified') and x['status']=='SUCCESS']
 return {'card':cid,'file_sha256':shas,'mechanical_exit':m.returncode,'mechanical_ok':mr.get('ok'),'mechanical_errors':mr.get('errors',[]),'machine_report':str(machine),'player_exit':v.returncode,'heuristic_success':sum(x['status']=='SUCCESS' for x in hs),'heuristic_trials':len(hs),'stationary_success':len(bs),'player_report':str(fp),'logs':str(logs)}
results=[]
with ThreadPoolExecutor(max_workers=8) as pool:
 for future in as_completed([pool.submit(task,cid) for cid in ids]):
  x=future.result();results.append(x);print(json.dumps(x,ensure_ascii=False),flush=True);(out/'batch-index.json').write_text(json.dumps({'completed':results,'expected_cards':ids},ensure_ascii=False,indent=2)+'\n')
print('Final frozen20 matrix finished',flush=True)
