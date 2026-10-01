from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import subprocess,json
repo=Path('/data/sunyunbo/www/stg-rl-train');root=Path('/tmp/sunyunbo/stg-laser-batch3')
def task(t):
 i,h=t;cid=f'laser_sp_corridor_{i:02}';log=root/f'horizon-{cid}-h{h}.log'
 with log.open('w') as f:r=subprocess.run([str(repo/'.venv/bin/python'),str(root/'check_corridor_horizon.py'),str(root/cid),'--horizon',str(h)],cwd=repo,stdout=f,stderr=subprocess.STDOUT)
 return {'card':cid,'horizon':h,'exit':r.returncode,'log':str(log)}
with ThreadPoolExecutor(max_workers=6) as pool:
 for f in as_completed([pool.submit(task,(i,h)) for i in [1,2,3] for h in [45,90]]):print(json.dumps(f.result()),flush=True)
