"""Temporary causal-observation diagnostic: same physics, explicit horizon override."""
from pathlib import Path
import argparse,json,hashlib
import torch,stg_rl
from stgtrain import specialist_feasibility as sf
from stgtrain.envwrap import EnvWrapper
from stgtrain.registry import load_builtins
p=argparse.ArgumentParser();p.add_argument('card');p.add_argument('--horizon',type=int,choices=[45,90],required=True);a=p.parse_args()
torch.set_num_threads(1);load_builtins();card=Path(a.card);before=sf._card_files_sha(card);image=stg_rl.compile_dir(card);digest=hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest()[:12]
out=Path('/data/sunyunbo/www/stg-rl-train/docs/practice-cards/reports/batch3/feasibility')/card.name/digest
out.mkdir(parents=True,exist_ok=True);tr=Path('/tmp/sunyunbo/stg-laser-batch3/horizon-trajectories')/card.name/digest/f'h{a.horizon}';tr.mkdir(parents=True,exist_ok=True)
runs=[]
for rank in range(4):
 for seed in [1,7]:
  env=EnvWrapper(sf._make_cfg(3600),{card.name:image},[stg_rl.Start(card.name,0,rank)],torch.device('cpu'),seed=seed,num_envs=1,mirror=False)
  obs=env.reset();rows=[]
  for step in range(3602):
   want=sf.choose_action(obs,horizon=a.horizon);xy=obs.player_xy[0].tolist();radius=float(obs.player_hit_r[0]);nxt,info=env.step(torch.tensor([want],dtype=torch.int64));done=int(info.done[0])
   rows.append(json.dumps({'f':step,'x':xy[0],'y':xy[1],'want':want,'buttons':int(info.buttons[0]),'hit_r':radius,'done':done},separators=(',',':')));obs=nxt
   if done:break
  file=tr/f'r{rank}-s{seed}.jsonl';payload=('\n'.join(rows)+'\n').encode();file.write_bytes(payload)
  r={'rank':rank,'seed':seed,'done':done,'status':sf.done_status(done),'steps':len(rows),'ep_frames':int(info.ep_frames[0]),'trajectory':str(file),'trajectory_sha256':hashlib.sha256(payload).hexdigest()};runs.append(r);print(json.dumps({'card':card.name,'horizon':a.horizon,**{k:r[k] for k in ['rank','seed','status','steps']}}),flush=True)
assert before==sf._card_files_sha(card),'card snapshot changed during diagnostic'
report={'schema_version':1,'checker':'supplementary causal-observation longer-horizon diagnostic; not canonical18f; not trainedpolicy','card':str(card),'card_file_sha256':before,'driver_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'choose_action_module_sha256':hashlib.sha256(Path(sf.__file__).read_bytes()).hexdigest(),'stg_rl_build_info':stg_rl.build_info(),'config':{'horizon':a.horizon,'max_frames':3600,'frame_skip':1,'num_envs':1,'threads':1,'device':'cpu','hit_extra':[2,2],'motor':{'hold':[2,6],'delay':[0,2],'slow':True},'ranks':[0,1,2,3],'seeds':[1,7],'mirror':False},'runs':runs,'limitations':['Same current-observation velocity/warning extrapolation with longer window; no new-spawn or hidden-RNG knowledge','No ECL future execution used in controller; physics unchanged','Failure NOT_PROVEN; success finite witness only'],'reproduction':f'.venv/bin/python /tmp/sunyunbo/stg-laser-batch3/check_corridor_horizon.py {card} --horizon {a.horizon}'}
file=out/f'{card.name}.h{a.horizon}.json';file.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print('REPORT',file,flush=True)
