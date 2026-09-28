import pytest
from stgtrain.practice_validate import (
    diagnostic_errors,
    expiry_errors,
    frame_spec_errors,
    metadata_errors,
    source_ranges_overlap,
    strict_json_loads,
)


def test_positive_count_key_frame_requires_all_geometry_fields():
    errors = frame_spec_errors({'frame': 10, 'count': 1})
    assert {'state', 'width', 'x', 'y', 'angle', 'start', 'end'} <= set(errors)


def test_machine_spec_json_rejects_duplicate_keys_and_frames():
    with pytest.raises(ValueError, match='重复键'):
        strict_json_loads('{"count": 1, "count": 2}')
    with pytest.raises(ValueError, match='重复关键帧'):
        strict_json_loads('{"key_frames": [{"frame": 10}, {"frame": 10}]}')


def test_last_natural_expiry_must_be_within_time_limit():
    assert expiry_errors({'last_expiry_frame': 100}, 100) == []
    assert expiry_errors({'last_expiry_frame': 101}, 100)
    assert expiry_errors({'last_spawn_before': 100}, 100) == []
    assert expiry_errors({'last_spawn_frame': 110, 'last_expiry_frame': 109}, 200)
    assert expiry_errors({'last_spawn_frame': 10, 'last_expiry_frame': 10.5}, 200)


def test_synthetic_metadata_inherits_base_and_declares_provenance():
    base = {
        'title': '底卡', 'origin': 'origin text', 'source': 'th06',
        'source_ref': 'ecl:1-2', 'ranks': [0, 3], 'marks': [0],
        'time_limit': 100, 'original_time_limit': 100,
    }
    valid = {
        **base, 'title': '底卡 — synthetic laser', 'source': 'synthetic',
        'data_kind': 'synthetic', 'tags': ['laser'], 'base_card': 'base',
        'mutation_id': 'm1', 'provenance': {
            'base_source': 'th06', 'base_source_ref': 'ecl:1-2',
            'base_files_sha256': {'main.ecl': 'abc'},
        },
    }
    assert metadata_errors(valid, base, {'main.ecl': 'abc'}) == []
    assert metadata_errors({**valid, 'tags': []}, base, {'main.ecl': 'abc'})
    assert metadata_errors({**valid, 'origin': 'changed'}, base, {'main.ecl': 'abc'})


def test_strict_diagnostic_gate_requires_fields_and_zeroes():
    assert diagnostic_errors('诊断：task_faults 0 · contract_viol 0 · pool_full 0 · hits_ovf 0 · events_ovf 0 · reqs_dropped 0') == []
    assert any('contract_viol' in e for e in diagnostic_errors('诊断：task_faults 0 · contract_viol 2 · pool_full 0 · hits_ovf 0 · events_ovf 0 · reqs_dropped 0'))
    assert diagnostic_errors('')
    assert diagnostic_errors('诊断：task_faults 0')
    assert diagnostic_errors('诊断：task_faults 0 · contract_viol 2 · contract_viol 0 · pool_full 0 · hits_ovf 0 · events_ovf 0 · reqs_dropped 0')


def test_source_overlap_includes_shared_helpers_and_endpoints():
    assert source_ranges_overlap('ecldata3.ecl.txt:843-848, 276-288', 'ecldata3.ecl.txt:748-785, 276-288')
    assert source_ranges_overlap('f:10-20', 'f:20-30')
    assert not source_ranges_overlap('f:10-20', 'g:10-20')
    assert not source_ranges_overlap('f:10-20', 'f:21-30')


def test_machine_spec_checks_count_state_and_geometry():
    from stgtrain.practice_validate import frame_errors
    expected = {'frame': 124, 'count': 1, 'state': 0, 'width': 8, 'x_min': -80, 'x_max': 80, 'end_min': 3.99, 'end_max': 4.01}
    rows = [{'color': 15, 'state': 0, 'width': 8, 'ox': -80, 'end': 4}]
    assert frame_errors(expected, rows, 1) == []
    assert frame_errors(expected, [], 1)
    assert frame_errors(expected, [{**rows[0], 'state': 1}], 1)
    assert frame_errors(expected, [{**rows[0], 'end': 200}], 1)


def test_frame_errors_maps_angle_alias_to_observed_degree_field():
    from stgtrain.practice_validate import frame_errors
    expected = {'frame': 10, 'count': 1, 'angle': 45}
    assert frame_errors(expected, [{'color': 15, 'deg': 45}], 1) == []
