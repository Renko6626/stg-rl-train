#!/usr/bin/env python3
"""Small, rerunnable spike checks against the real VM; no native-game oracle.

Authored microprograms have independently specified expected frames/values.
Original-game scripts and all generated files stay in transcribe/work/.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess

from compile import Compiler, HERE, REPO, THECL, WORK, Unsupported, decode

RUNNER = WORK / 'target/debug/th18-prototype-runner'

# Handwritten inputs, not excerpts of ZUN assets. -s prevents automatic prologues.
SCENES = {
    'clock': '''void clock() {
        ins_40(4);
        ins_12(later, 7);
        10:
        later:
        ins_42(1); ins_43([0]);
        ins_23(4);
        0:
        ins_42(2); ins_43([0]);
        10:
        ins_42(3); ins_43([0]); ins_10();
    }''',
    'stack_wait': '''void stack_wait() {
        ins_40(4); ins_44(0.75f);
        5:
        ins_44(0.25f); ins_51(); ins_45([0.0f]); ins_10();
    }''',
    'countdown': '''void countdown() {
        ins_40(8); ins_42(3); ins_43([0]);
        ins_42(0); ins_43([4]); ins_12(check, 0);
        body:
        ins_42([4]); ins_42(1); ins_50(); ins_43([4]); ins_23(2);
        check:
        ins_78([0]); ins_14(body, 0); ins_10();
    }''',
    'float_condition': '''void float_condition() {
        ins_40(4); ins_44(0.5f); ins_14(wrong, 0);
        ins_42(1); ins_43([0]); ins_12(done, 0);
        wrong:
        ins_42(2); ins_43([0]);
        done:
        ins_10();
    }''',
    'float_threshold': '''void float_threshold() {
        ins_40(4); ins_44(0.999999f); ins_14(taken, 0);
        ins_42(1); ins_43([0]); ins_12(done, 0);
        taken:
        ins_42(2); ins_43([0]);
        done:
        ins_10();
    }''',
    'masked_time': '''void masked_time() {
        ins_40(4);
        !N
        10:
        ins_42(9); ins_43([0]);
        !*
        0:
        ins_42(7); ins_43([0]); ins_10();
    }''',
    'unsupported': '''void unsupported() {
        ins_637(2); ins_10();
    }''',
}


def image_run(image, name):
    path = WORK / f'{name}.json'
    path.write_text(json.dumps(image))
    trace = WORK / f'{name}.trace.jsonl'
    with trace.open('w') as out:
        subprocess.run([str(RUNNER), str(path)], stdout=out, check=True)
    return trace


def rows(path):
    with path.open() as stream:
        for line in stream:
            row = json.loads(line)
            row['g'] = {v['slot']:v['value'] for v in row['globals']}
            yield row


def first_value(data, slot, value):
    row = next(r for r in data if r['g'][slot] == value and r['g'][16] != 0)
    return row['vm_frame'] - row['g'][16]


def synthetic():
    summaries = {}
    for name, source in SCENES.items():
        src, binary = WORK / f'{name}.raw.ecl', WORK / f'{name}.ecl'
        src.write_text(source)
        subprocess.run([str(THECL), '-s', '-c', '18', str(src), str(binary)], check=True)
        subs, _ = decode(binary)
        if name == 'unsupported':
            try:
                Compiler(subs[name], 0).build()
            except Unsupported as exc:
                assert '637' in str(exc), exc
                summaries[name] = 'rejected opcode 637'
            else:
                raise AssertionError('unknown native function was accepted')
            continue
        floating = name in ('stack_wait','float_condition','float_threshold')
        if floating:
            try:
                Compiler(subs[name], 0).build()
            except Unsupported as exc:
                assert 'source floats' in str(exc), exc
            else:
                raise AssertionError('strict mode accepted unverified source float semantics')
        image = Compiler(subs[name], 0, demo=floating).build()
        image.update(frames=20)
        data = list(rows(image_run(image, name)))
        end = next(r for r in data if r['g'][19])
        end_at = end['vm_frame'] - end['g'][16]
        if name == 'clock':
            # Jump sets t=7, so t=10 is due in 3 frames. wait(4) reduces
            # t to 6: the following t=0 write runs immediately, t=10 in 4 more.
            assert first_value(data, 64, 2) == 3
            assert first_value(data, 64, 3) == 7
            assert end_at == 7
        elif name == 'stack_wait':
            assert first_value(data, 64, 65536) == 5
            assert end_at == 5
        elif name == 'countdown':
            assert [first_value(data, 65, v) for v in (1,2,3)] == [0,2,4]
            assert end['g'][64] == -1 and end_at == 6
        elif name == 'float_condition':
            assert end['g'][64] == 1 and end_at == 0
        elif name == 'float_threshold':
            # An explicitly exposed limitation: native trunc(f32(.999999))=0;
            # Q16 round produces 1, so the branch differs. Strict mode refused it.
            assert end['g'][64] == 2 and image['approximations']
            summaries[name] = {'native_expected':1,'demo_observed':2,'strict_rejected':True}
            continue
        elif name == 'masked_time':
            assert first_value(data, 64, 7) == 10 and end_at == 10
        summaries[name] = {'end_source_frame':end_at, 'locals':{
            str(k-64):v for k,v in end['g'].items() if k>=64}}
    return summaries


def real_sample(asset):
    subs, binary = decode(asset)
    sub = subs['GirlD01_at2']
    try:
        Compiler(sub, 1).build()
    except Unsupported:
        pass
    else:
        raise AssertionError('real gameplay must require explicit demo opt-in')
    summaries = {}
    for rank, (ways, volleys, interval) in enumerate([(20,10,60),(40,20,30),(55,20,30),(65,20,30)]):
        image = Compiler(sub, rank, demo=True).build()
        image.update(frames=610, seed=1, source_sha256=hashlib.sha256(binary).hexdigest())
        trace = image_run(image, f'girl-r{rank}')
        births, seen, by_bullet = Counter(), set(), {}
        epoch = None
        first_volley = []
        for row in rows(trace):
            if row['g'][16]:
                epoch = row['g'][16]
            for bullet in row['bullets']:
                key = (bullet['index'], bullet['generation'])
                if key not in seen:
                    births[bullet['born_frame']] += 1
                    seen.add(key)
                if bullet['born_frame'] == epoch:
                    by_bullet.setdefault(key, []).append(bullet)
                    if row['vm_frame'] == epoch:
                        first_volley.append(bullet)
            final = row
        assert births == Counter({epoch+n*interval:ways for n in range(volleys)}), births
        assert final['g'][17] == volleys and final['g'][19] == 1
        # Read actual angles, not transform source. A surviving first-volley
        # bullet must turn for 120 integrations, then fly straight.
        long = next(v for v in by_bullet.values() if len(v) >= 122)
        delta = [((b['angle']-a['angle']+32768)%65536)-32768
                 for a,b in zip(long,long[1:])]
        assert delta[:119] == [-109]*119, delta[:125]
        assert delta[119:121] == [0,0], delta[115:125]
        assert len({b['angle'] for b in first_volley}) == ways
        # Exact replay check uses real World checksums, including script state.
        if rank == 1:
            repeated = image_run(image, 'girl-r1-repeat')
            assert trace.read_bytes() == repeated.read_bytes()
        summaries[str(rank)] = {'volleys':volleys,'bullets_per_volley':ways,
                                'interval':interval,'observed_births':sum(births.values()),
                                'turn_updates':120,'delta_bam':-109,
                                'faults':final['faults'],'contract_viol':final['contract_viol'],
                                'pool_full':final['pool_full']}
    return summaries


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--asset', type=Path, default=REPO.parent / 'renkolab/local/th18.v1.00a/dat/st04.ecl')
    args = p.parse_args()
    WORK.mkdir(parents=True, exist_ok=True)
    result = {'synthetic':synthetic(), 'real_demo':real_sample(args.asset),
              'scope':'target VM checks + native-backed control semantics; NOT native trajectory equivalence'}
    (WORK / 'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
