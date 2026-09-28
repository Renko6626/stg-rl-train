"""严格验收合成练习卡；CLI输出机器报告，不运行训练。"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

import stg_rl

from .cards import discover, load_splits, source_ranges_overlap

DIAGNOSTICS = ('task_faults', 'contract_viol', 'pool_full', 'hits_ovf', 'events_ovf', 'reqs_dropped')


def _reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'重复键: {key}')
        result[key] = value
    return result


def strict_json_loads(text: str) -> dict:
    """Parse a machine spec without allowing duplicate object keys or frames."""
    try:
        value = json.loads(text, object_pairs_hook=_reject_duplicate_keys)
    except (json.JSONDecodeError, ValueError) as exc:
        if isinstance(exc, ValueError) and str(exc).startswith('重复键:'):
            raise
        raise ValueError(f'JSON无效: {exc}') from exc
    if not isinstance(value, dict):
        raise ValueError('machine-spec必须是JSON对象')
    frames = value.get('key_frames')
    if isinstance(frames, list):
        seen = set()
        for frame in frames:
            if isinstance(frame, dict) and 'frame' in frame:
                number = frame['frame']
                if number in seen:
                    raise ValueError(f'重复关键帧: {number}')
                seen.add(number)
    return value


def frame_spec_errors(expected: dict) -> list[str]:
    """Return required declarations missing from a positive-count key frame."""
    count = expected.get('count', expected.get('count_min', 0))
    if count <= 0:
        return []
    aliases = {
        'angle': ('angle', 'angle_deg'),
    }
    errors = []
    for name in ('state', 'width', 'x', 'y', 'angle', 'start', 'end'):
        names = aliases.get(name, (name,))
        exact = any(candidate in expected for candidate in names)
        ranged = any(f'{candidate}_min' in expected and f'{candidate}_max' in expected
                     for candidate in names)
        if not exact and not ranged:
            errors.append(name)
    return errors


def expiry_errors(machine_spec: dict, time_limit: int) -> list[str]:
    """Ensure the declared final natural laser expiry is within the card limit.

    Older pilot specs used ``last_spawn_before`` for this same conservative
    bound; retain that fallback so the existing ten cards remain valid.
    """
    expiry = machine_spec.get('last_expiry_frame', machine_spec.get('last_spawn_before'))
    if not isinstance(expiry, int) or isinstance(expiry, bool):
        return ['缺少最后自然回收帧声明']
    spawn = machine_spec.get('last_spawn_frame')
    errors = []
    if spawn is not None and (not isinstance(spawn, int) or isinstance(spawn, bool)):
        errors.append('最后出生帧类型无效')
    elif isinstance(spawn, int) and expiry < spawn:
        errors.append('最后自然回收帧早于最后出生帧')
    if expiry > time_limit:
        errors.append('最后自然回收帧超过time_limit')
    return errors


def metadata_errors(meta: dict, base_meta: dict, base_files_sha256: dict, *,
                    require_origin: bool = True) -> list[str]:
    """Validate synthetic display/source metadata against its base card."""
    errors = []
    if 'synthetic' not in str(meta.get('title', '')).lower():
        errors.append('title未明确synthetic')
    if 'laser' not in meta.get('tags', []):
        errors.append('tags缺laser')
    for field in (('origin', 'source_ref') if require_origin else ('source_ref',)):
        if meta.get(field) != base_meta.get(field):
            errors.append(f'{field}未继承底卡')
    provenance = meta.get('provenance')
    if not isinstance(provenance, dict):
        return errors + ['缺provenance']
    if provenance.get('base_source') != base_meta.get('source'):
        errors.append('provenance.base_source不一致')
    if provenance.get('base_source_ref') != base_meta.get('source_ref'):
        errors.append('provenance.base_source_ref不一致')
    if provenance.get('base_files_sha256') != base_files_sha256:
        errors.append('provenance.base_files_sha256不一致')
    return errors


def diagnostic_errors(output: str) -> list[str]:
    lines = [line for line in output.splitlines() if line.startswith('诊断：')]
    if len(lines) != 1:
        return ['诊断行缺失或重复']
    pairs = re.findall(r'(\w+)\s+(\d+)', lines[0])
    return [f'{key}: 缺失、重复或非零' for key in DIAGNOSTICS
            if [value for name, value in pairs if name == key] != ['0']]


def frame_errors(expected: dict, rows: list[dict], maximum: int) -> list[str]:
    overlay = [row for row in rows if row.get('color') == 15]
    errors = []
    if not (expected.get('count_min', expected.get('count', 0)) <= len(overlay)
            <= expected.get('count_max', expected.get('count', maximum)) <= maximum):
        errors.append('新增激光数量与规格不符')
    aliases = {'x': 'ox', 'y': 'oy', 'angle': 'deg', 'angle_deg': 'deg'}
    for row in overlay:
        for key, value in expected.items():
            if key in ('frame', 'count', 'count_min', 'count_max'):
                continue
            suffix = '_min' if key.endswith('_min') else '_max' if key.endswith('_max') else ''
            field = key[:-4] if suffix else key
            actual = row.get(aliases.get(field, field))
            if actual is None or (suffix == '_min' and actual < value - 0.011) or (suffix == '_max' and actual > value + 0.011) or (not suffix and abs(actual - value) > 0.011):
                errors.append(f'{key}与规格不符: {actual} / {value}')
    return errors


def validate(card_dir: Path, *, originals: Path = Path('cards'), splits: Path = Path('eval/splits-laser.toml'),
             harness: Path = Path('/data/sunyunbo/www/stg-engine/target/release/stg-harness'),
             seeds: tuple[int, ...] = (1, 7)) -> dict:
    from stgtranscribe.preview import parse_at
    card = discover(card_dir.parent)[card_dir.name]
    meta = card.meta
    try:
        machine_spec = strict_json_loads((card_dir / 'machine-spec.json').read_text())
    except ValueError as exc:
        machine_spec = {}
        spec_error = str(exc)
    else:
        spec_error = None
    report = {'card': card.id, 'data_kind': card.data_kind, 'errors': [], 'runs': [], 'key_frames': [],
              'seeds': list(seeds), 'machine_spec': machine_spec,
              'file_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(card_dir.iterdir()) if p.is_file()}, 'harness_sha256': hashlib.sha256(harness.read_bytes()).hexdigest(),
              'validator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'stg_rl_version': __import__('importlib.metadata', fromlist=['version']).version('stg_rl')}
    errors = report['errors']
    if spec_error:
        errors.append(spec_error)
    if not machine_spec.get('key_frames') or not 1 <= machine_spec.get('max_added_lasers', 0) <= 4 or machine_spec.get('synthetic_color') != 15:
        errors.append('machine-spec缺关键帧/数量范围/颜色')
    for expected in machine_spec.get('key_frames', []):
        errors.extend(f'关键帧{expected.get("frame")}: 缺少规格字段 {field}'
                      for field in frame_spec_errors(expected))
    if card.data_kind != 'synthetic' or meta.get('data_kind') != 'synthetic' or not meta.get('mutation_id'):
        errors.append('非synthetic或缺mutation_id')
    bases = discover(originals)
    base = bases.get(meta.get('base_card'))
    if base is None:
        errors.append('底子不存在')
        report['ok'] = False
        return report
    held = load_splits(splits, 32)
    for spec in held:
        if base.id == spec.card or source_ranges_overlap(base.meta['source_ref'], bases[spec.card].meta['source_ref']):
            errors.append(f'底子与留出同源: {spec.card}')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(base.path.glob('*.ecl'))}
    # The ten pilot specs predate the explicit expiry declaration and contain
    # shortened origin prose; retain their accepted baseline while requiring
    # exact origin inheritance for newly declared specs.
    errors.extend(metadata_errors(meta, base.meta, hashes,
                                  require_origin='last_expiry_frame' in machine_spec))
    markers = 0
    for filename in hashes:
        target = card_dir / filename
        if not target.exists():
            errors.append(f'缺底子文件{filename}')
            continue
        lines = target.read_bytes().splitlines(keepends=True)
        marker_lines = [line for line in lines if b'SYNTHETIC_OVERLAY_ENTRY' in line]
        markers += len(marker_lines)
        if any(line.strip() != b'spawn synth_overlay(); // SYNTHETIC_OVERLAY_ENTRY' for line in marker_lines):
            errors.append('overlay入口不是允许的根伴生任务')
        restored = b''.join(line for line in lines if b'SYNTHETIC_OVERLAY_ENTRY' not in line)
        if restored != (base.path / filename).read_bytes():
            errors.append(f'原作内容被改写:{filename}')
    if markers != 1:
        errors.append('overlay入口必须恰好1行')
    if {p.name for p in card_dir.glob('*.ecl')} != set(hashes) | {'overlay.ecl'}:
        errors.append('有未声明ECL文件')
    for field in ('ranks', 'marks', 'time_limit', 'original_time_limit'):
        if meta.get(field) != base.meta.get(field):
            errors.append(f'改写底子meta.{field}')
    try:
        stg_rl.compile_dir(card_dir)
    except stg_rl.CompileError as exc:
        errors.append(str(exc))
    if errors:
        report['ok'] = False
        return report
    overlay_code = re.sub(r'//[^\n]*', '', (card_dir / 'overlay.ecl').read_text())
    if re.search(r'\$self|\baim_player\s*\(|\bspawn_enemy\s*\(|\bset_invuln\s*\(', overlay_code):
        errors.append('overlay依赖owner或创建新敌人')
    if errors:
        report['ok'] = False
        return report
    if not (machine_spec.get('first_spawn_frame', 123) <= machine_spec.get('last_spawn_frame', -1) < machine_spec.get('last_spawn_before', 0) <= meta['time_limit']):
        errors.append('machine-spec出生窗口缺失或越界')
    errors.extend(expiry_errors(machine_spec, meta['time_limit']))
    if errors:
        report['ok'] = False
        return report
    lo, hi = meta['ranks']
    frames = meta['time_limit'] + 60
    overlay_seen = False
    for rank in range(lo, hi + 1):
        for seed in seeds:
            proc = subprocess.run([str(harness), 'run', str(card_dir), '--rank', str(rank), '--seed', str(seed),
                                   '--frames', str(frames)], capture_output=True, text=True, timeout=90)
            output = proc.stdout + proc.stderr
            run_errors = diagnostic_errors(output)
            if proc.returncode:
                run_errors.append(f'exit={proc.returncode}')
            peak = re.search(r'^峰值：.*?· 激光 (\d+)（帧 (\d+)）', output, re.M)
            if not peak or int(peak[1]) == 0:
                run_errors.append('无激光峰值或峰值解析失败')
            seg = re.search(r'^段结束：(.+)$', output, re.M)
            seg_frames = [int(value) for value in re.findall(r'@(\d+)', seg[1])] if seg else []
            if not seg_frames or not (120 <= min(seg_frames) <= meta['time_limit'] + 60):
                run_errors.append('段结束缺失或超出合理窗口')
            report['runs'].append({'rank': rank, 'seed': seed, 'exit': proc.returncode,
                                   'errors': run_errors, 'peak_lasers': int(peak[1]) if peak else None,
                                   'output': output})
            errors.extend(f'r{rank}/seed{seed}: {e}' for e in run_errors)
        for expected in machine_spec['key_frames']:
            for snapshot_seed in seeds:
                frame = int(expected['frame'])
                proc = subprocess.run([str(harness), 'run', str(card_dir), '--rank', str(rank), '--seed', str(snapshot_seed),
                                       '--frames', str(frame), '--at', str(frame)], capture_output=True, text=True, timeout=90)
                snapshot = parse_at(proc.stdout)
                lasers = [vars(laser) for laser in snapshot.lasers]
                # 新增color15只作产物辨识，不进入策略输入额外特征。
                overlay_rows = [laser for laser in lasers if laser.get('color') == 15]
                overlay_seen |= bool(overlay_rows)
                errors.extend(f'关键帧{frame}/r{rank}: {error}' for error in frame_errors(expected, lasers, machine_spec['max_added_lasers']))
                if len(overlay_rows) > 4:
                    errors.append(f'关键帧{frame}/r{rank}: 新增激光超过4条')
                for laser in overlay_rows:
                    if not (6 <= laser['width'] <= 12 and 0 <= laser['start'] <= laser['end']
                            and laser['warn'] >= 45 and laser['fade'] <= 15 and laser['state'] in (0, 1, 2)):
                        errors.append(f'关键帧{frame}/r{rank}: 几何/参数越界')
                report['key_frames'].append({'rank': rank, 'seed': snapshot_seed, 'frame': frame, 'lasers': lasers})
                if proc.returncode or diagnostic_errors(proc.stdout + proc.stderr):
                    errors.append(f'关键帧{frame}/r{rank}运行失败')
        first_spawn = int(machine_spec.get('first_spawn_frame', 123))
        last_spawn = int(machine_spec['last_spawn_frame'])
        for frame, should_spawn in ((first_spawn - 1, False), (first_spawn, True), (last_spawn, True)):
            schedule = subprocess.run([str(harness), 'run', str(card_dir), '--rank', str(rank), '--seed', str(seeds[0]),
                                       '--frames', str(frame), '--at', str(frame)], capture_output=True, text=True, timeout=90)
            rows = [vars(laser) for laser in parse_at(schedule.stdout).lasers if laser.color == 15]
            report['key_frames'].append({'rank': rank, 'frame': frame, 'schedule_check': True, 'lasers': rows})
            if (not should_spawn and rows) or (should_spawn and not any(row['timer'] == 1 for row in rows)):
                errors.append(f'r{rank}/f{frame}: 声明出生帧不符')
            if schedule.returncode or diagnostic_errors(schedule.stdout + schedule.stderr):
                errors.append(f'r{rank}/f{frame}: 出生帧运行失败')
        deadline = subprocess.run([str(harness), 'run', str(card_dir), '--rank', str(rank), '--seed', str(seeds[0]),
                                   '--frames', str(meta['time_limit']), '--at', str(meta['time_limit'])],
                                  capture_output=True, text=True, timeout=90)
        deadline_lasers = [vars(laser) for laser in parse_at(deadline.stdout).lasers]
        report['key_frames'].append({'rank': rank, 'frame': meta['time_limit'],
                                     'deadline_check': True, 'lasers': deadline_lasers})
        if any(laser['color'] == 15 for laser in deadline_lasers):
            errors.append(f'r{rank}: time_limit时新增激光未回收')
        if deadline.returncode or diagnostic_errors(deadline.stdout + deadline.stderr):
            errors.append(f'r{rank}: time_limit关键帧运行失败')
        terminal = subprocess.run([str(harness), 'run', str(card_dir), '--rank', str(rank), '--seed', str(seeds[0]),
                                   '--frames', str(frames), '--at', str(frames)], capture_output=True, text=True, timeout=90)
        terminal_lasers = [vars(laser) for laser in parse_at(terminal.stdout).lasers]
        report['key_frames'].append({'rank': rank, 'frame': frames, 'lasers': terminal_lasers})
        if any(laser['color'] == 15 for laser in terminal_lasers):
            errors.append(f'r{rank}: 段末新增激光未回收')
        if terminal.returncode or diagnostic_errors(terminal.stdout + terminal.stderr):
            errors.append(f'r{rank}: 段末关键帧运行失败')
    if not overlay_seen:
        errors.append('关键帧未看到新增color15激光')
    if re.search(r'\brand\s*\(', overlay_code):
        signatures = []
        for seed in seeds:
            signatures.append([[{key: row[key] for key in ('ox', 'oy', 'deg', 'width', 'start', 'end')}
                                for row in sample['lasers'] if row['color'] == 15]
                               for sample in report['key_frames'] if sample.get('seed') == seed])
        if len(signatures) < 2 or signatures[0] == signatures[1]:
            errors.append('随机overlay在验收种子间没有可观测几何差异')
    report['ok'] = not errors
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('card', type=Path)
    parser.add_argument('--json', required=True, type=Path)
    parser.add_argument('--all', action='store_true', help='逐卡验收目录下全部合成卡，--json指定报告目录')
    args = parser.parse_args()
    paths = [card.path for card in discover(args.card).values()] if args.all else [args.card]
    if not paths:
        raise SystemExit('没有待验收卡')
    all_ok = True
    for card in paths:
        report = validate(card)
        target = args.json / f'{card.name}.machine.json' if args.all else args.json
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(f"{card.name}: {'PASS' if report['ok'] else 'FAIL'} ({len(report['errors'])} errors)")
        for error in report['errors']:
            print(error)
        all_ok &= report['ok']
    raise SystemExit(0 if all_ok else 1)


if __name__ == '__main__':
    main()
