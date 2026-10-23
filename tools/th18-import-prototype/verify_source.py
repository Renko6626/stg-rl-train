#!/usr/bin/env python3
"""Execute emitted ECL, checking source recovery against independent outcomes.

Generated game-derived files remain in the ignored workspace. The runner reads
the generated .ecl itself; this check does not substitute the old bytecode image.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess

from compile import REPO, THECL, WORK, decode
from emit_source import emit_source
from verify import SCENES, RUNNER, first_value, image_run, rows


EXTRA = {
    'while_loop': '''void while_loop() {
        ins_40(4); ins_42(0); ins_43([0]);
        head:
        ins_42([0]); ins_42(3); ins_63(); ins_13(done, 0);
        ins_42([0]); ins_42(1); ins_50(); ins_43([0]);
        ins_23(2); ins_12(head, 0);
        done: ins_10();
    }''',
    'if_else': '''void if_else() {
        ins_40(4); ins_42(1); ins_13(other, 0);
        ins_42(11); ins_43([0]); ins_12(done, 0);
        other: ins_42(22); ins_43([0]);
        done: ins_23(3); ins_10();
    }''',
    'if_else_false': '''void if_else_false() {
        ins_40(4); ins_42(0); ins_13(other, 0);
        ins_42(11); ins_43([0]); ins_12(done, 0);
        other: ins_42(22); ins_43([0]);
        done: ins_23(3); ins_10();
    }''',
}


def source_run(sub, rank, name, demo=False, structured=True, frames=20):
    text = emit_source(sub, rank, demo=demo, structured=structured)
    path = WORK / f'{name}.generated.ecl'
    path.write_text(text)
    allocated = max((i.args[0].value for i in sub.instructions if i.op == 40), default=0)//4
    config = {'ecl':path.name, 'frames':frames, 'seed':1,
              'watch_globals':[16,17,19,*range(64,64+allocated)]}
    return image_run(config, name)


def observations(row):
    # Task locals/layout and their checksum legitimately differ between the
    # source and raw-bytecode backends; compare actual exported behaviour.
    return {k:row[k] for k in ('frame','vm_frame','bullets','globals','faults','contract_viol','pool_full','player')}


def synthetic():
    result = {}
    for name, text in (SCENES | EXTRA).items():
        if name == 'unsupported':
            continue  # The existing strict-rejection check owns this case.
        raw, binary = WORK / f'{name}.raw.ecl', WORK / f'{name}.ecl'
        raw.write_text(text)
        subprocess.run([str(THECL), '-s', '-c', '18', str(raw), str(binary)], check=True)
        sub = decode(binary)[0][name]
        demo = name in ('stack_wait','float_condition','float_threshold')
        structured = list(rows(source_run(sub,0,f'source-{name}',demo=demo)))
        fallback = list(rows(source_run(sub,0,f'goto-{name}',demo=demo,structured=False)))
        assert [observations(r) for r in structured] == [observations(r) for r in fallback], name
        end = next(r for r in structured if r['g'][19])
        end_at = end['vm_frame']-end['g'][16]
        if name == 'clock':
            assert first_value(structured,64,2)==3 and first_value(structured,64,3)==7
            assert end_at==7
        elif name == 'stack_wait':
            assert first_value(structured,64,65536)==5 and end_at==5
        elif name == 'countdown':
            assert [first_value(structured,65,v) for v in (1,2,3)] == [0,2,4]
            assert end['g'][64]==-1 and end_at==6
        elif name == 'float_condition':
            assert end['g'][64]==1 and end_at==0
        elif name == 'float_threshold':
            assert end['g'][64]==2 and end_at==0  # Explicit demo limitation, native would give 1.
        elif name == 'masked_time':
            assert first_value(structured,64,7)==10 and end_at==10
        elif name == 'while_loop':
            assert [first_value(structured,64,v) for v in (1,2,3)] == [0,2,4]
            assert end_at==6
        else:
            assert end['g'][64] == (11 if name=='if_else' else 22)
            assert end_at==3
        result[name]={'end_source_frame':end_at,'structured_matches_goto':True}
    return result


def real_sample(asset):
    sub=decode(asset)[0]['GirlD01_at2']
    result={}
    for rank,(ways,volleys,interval) in enumerate([(20,10,60),(40,20,30),(55,20,30),(65,20,30)]):
        trace=source_run(sub,rank,f'source-girl-r{rank}',demo=True,frames=610)
        seen=set(); births=Counter(); first_volley={}
        for row in rows(trace):
            epoch=row['g'][16]
            for b in row['bullets']:
                key=(b['index'],b['generation'])
                if key not in seen:
                    births[b['born_frame']]+=1; seen.add(key)
                if epoch and b['born_frame']==epoch:
                    first_volley.setdefault(key,[]).append(b)
            final=row
        assert births==Counter({epoch+n*interval:ways for n in range(volleys)}), (rank,births)
        assert final['g'][17]==volleys and final['g'][19]==1
        long=next(v for v in first_volley.values() if len(v)>=122)
        deltas=[((b['angle']-a['angle']+32768)%65536)-32768 for a,b in zip(long,long[1:])]
        assert deltas[:119]==[-109]*119 and deltas[119:121]==[0,0], (rank,deltas[:125])
        if rank==1:
            fallback=source_run(sub,rank,'goto-girl-r1',demo=True,structured=False,frames=610)
            assert all(observations(a)==observations(b) for a,b in zip(rows(trace),rows(fallback),strict=True))
            # Existing first-prototype trace is an optional additional comparison;
            # independently specified counts/timing above are always checked.
            original=WORK/'girl-r1.trace.jsonl'
            if original.exists():
                assert all(observations(a)==observations(b) for a,b in zip(rows(trace),rows(original),strict=True))
        result[str(rank)]={'volleys':volleys,'ways':ways,'interval':interval,'births':sum(births.values())}
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--synthetic-only',action='store_true')
    p.add_argument('--asset',type=Path,default=REPO.parent/'renkolab/local/th18.v1.00a/dat/st04.ecl')
    args=p.parse_args()
    WORK.mkdir(parents=True,exist_ok=True)
    result={'synthetic':synthetic()}
    if not args.synthetic_only:
        result['real_demo']=real_sample(args.asset)
    (WORK/'source-verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
