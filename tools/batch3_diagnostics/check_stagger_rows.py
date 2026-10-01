from pathlib import Path
import json,math,hashlib
import torch,stg_rl
from stgtrain import specialist_feasibility as sf
from stgtrain.envwrap import EnvWrapper
from stgtrain.registry import load_builtins
load_builtins();torch.set_num_threads(1)
card=Path('/tmp/sunyunbo/stg-laser-batch3/laser_sp_stagger_01');before=sf._card_files_sha(card);image=stg_rl.compile_dir(card)
root=Path('/data/sunyunbo/www/stg-rl-train/runs/laser-specialist-batch3-validation/laser_sp_stagger_01/round3/edge-row-probe');root.mkdir(parents=True,exist_ok=True);runs=[]
for rank in range(4):
 for seed in [1,7]:
  for target in [(0.,10.),(0.,438.)]:
   env=EnvWrapper(sf._make_cfg(3600),{card.name:image},[stg_rl.Start(card.name,0,rank)],torch.device('cpu'),seed=seed,num_envs=1,mirror=False);obs=env.reset();rows=[];arrived=None;dwell=0;best=0;maxdrift=0
   for f in range(3602):
    xy=[float(x) for x in obs.player_xy[0]];hit_r=float(obs.player_hit_r[0]);focus=bool(obs.player_focus[0]);dist=math.dist(xy,target)
    if arrived is None and dist<=4:arrived=f
    want=0 if arrived is not None else sf._move_toward(*xy,*target)
    if arrived is None and dist>60:want&=~1
    nxt,info=env.step(torch.tensor([want],dtype=torch.int64));done=int(info.done[0]);buttons=int(info.buttons[0])
    if arrived is not None:
     maxdrift=max(maxdrift,dist);dwell=dwell+1 if (buttons&sf.actions.DIR_MASK)==0 and dist<=4 else 0;best=max(best,dwell)
    rows.append(json.dumps({'f':f,'xy':xy,'want':want,'buttons':buttons,'hit_r':hit_r,'focus':focus,'done':done},separators=(',',':')));obs=nxt
    if done:break
   path=root/f'r{rank}-s{seed}-y{int(target[1])}.jsonl';payload=('\n'.join(rows)+'\n').encode();path.write_bytes(payload)
   row={'rank':rank,'seed':seed,'target':target,'status':sf.done_status(done),'done':done,'steps':len(rows),'arrival_step':arrived,'stationary_frames_max':best,'max_target_drift':maxdrift,'stationary_qualified':best>=120 and maxdrift<=4,'trajectory':str(path),'trajectory_sha256':hashlib.sha256(payload).hexdigest()};runs.append(row);print(json.dumps(row),flush=True)
assert before==sf._card_files_sha(card)
r={'schema_version':1,'checker':'targeted row diagnostic; fast approach when farther than60px then slow approach then requeststop; actual motor applied','card_file_sha256':before,'driver_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'canonical_module_sha256':hashlib.sha256(Path(sf.__file__).read_bytes()).hexdigest(),'stg_rl_build_info':stg_rl.build_info(),'config':{'hit_extra':[2,2],'motor':{'hold':[2,6],'delay':[0,2],'slow':True},'frame_skip':1,'threads':1,'mirror':False,'max_frames':3600,'targets':[[0,10],[0,438]],'rank':[0,1,2,3],'seeds':[1,7]},'runs':runs,'reproduction':'.venv/bin/python /tmp/sunyunbo/stg-laser-batch3/check_stagger_rows.py','limitations':['A missed target is not proof it is unsafe','Finite samples, no universal solvability/pressure claim']}
p=Path('/data/sunyunbo/www/stg-rl-train/docs/practice-cards/reports/batch3/final-round3/laser_sp_stagger_01/edge-row-probe.json');p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
