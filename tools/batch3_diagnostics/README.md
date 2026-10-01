# batch3 verification scripts

These are the exact controller/orchestration sources used for the recorded checks. They are offline diagnostics, not training policy, observations, or reward. Source hashes match the reports.

The scripts preserve their original staging/report paths under `/tmp/sunyunbo/stg-laser-batch3` and this workspace. To replay after staging cleanup, copy the corresponding frozen dataset card back to its recorded staging directory, use the reported stg_rl version and engine source identity, then run the recorded command. `check_corridor_horizon.py` explicitly selects horizon45/90; it must not be described as the canonical18-frame controller.

Final traces are retained in ignored `runs/laser-specialist-batch3-validation/`. Older temporary trajectories may have been overwritten during revision; historical reports are not acceptance for current files.
