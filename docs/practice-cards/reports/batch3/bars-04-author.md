# bars_04 作者交接报告（返工第2轮）

状态：**READY/FROZEN（作者阶段）**。布局`laser_sp_bars_04`，split=`held-out`。卡片快照位于`/tmp/sunyunbo/stg-laser-batch3/laser_sp_bars_04/`。本轮依据heldout source review修正joint overlap算式，并回应旧SHA实机基线暴露的固定空间绕行；没有读训练卡/训练反馈，没有改共享工具、其他卡或引擎。

## 冻结文件 SHA256

- `main.ecl`: `dee59177160d8e750765d8c52924ae615c8860f26e30f307833730ffeda122bf`
- `meta.toml`: `1414ab1f9dd7e462d25934da226a4555a29069b50099358e707aff015eff195b`
- `TASK.md`: `874e10ab298399c2ed940dd8937ca8ca19c6bd87e50effb61b1803081ebf177b`
- `machine-spec.json`: `eb981b8a01bc50705ba1983b357e98c30a989e5ff49e51cfb795147ed8026c88`

## 本轮修订依据与几何响应

heldout review指出旧方案把同一个`joint`同时用于`active=150+20j`和`interval=180+2j`，所以rank3实际重叠应为`15+18j`帧（15..69），而不是把joint0活动和joint3间隔拼成9帧。TASK现按每rank的共享joint列明：rank0 `158+18j`，rank1 `143+18j`，rank2 `128+18j`，rank3 `113+18j`。本轮16波的等待已改为`82+2j`，所以当前每rank重叠公式相应为158/143/128/113加18j；并没有为了复现9帧而改配置。

协调者给出的旧SHA玩家检查为8/8启发式成功、23/80静止基线成功。该检查报告绑定旧卡SHA前缀`263f3f80a4b5`，记录的静止成功集中在`(-128/128,80/392)`和少量实际出生点；heldout review也指出旧源码只在外侧/中间三带放水平线、垂直线仅放边界/中心，留下大间距带。当前源码改为16组，每组4根：水平与垂直轴各用32个等距lane覆盖完整玩家坐标轴；joint在有限lane上施加-3/-1/+1/+3px固定偏移，不瞄准玩家。水平origin从±180向内推进，竖直origin从上下边界推进，交接方向保持右/下/左/上循环。

此响应消除了旧源码里整片未布置lane的结构；离散射线、短活动位移和碰撞宽度仍不构成所有位置/所有随机实例均不可站桩的证明。当前SHA的实际玩家检查和非作者审查仍待协调者执行。

## 实现与时序

每波4根、共16波；方向四轮轮换。warning期间几何静止，active开始才平移origin，near=0、far=随机长度40..120px。rank档width=6/8/10/12、warning=90/75/60/45、active=150/170/190/210、fade12。`joint=rand(4)`联合决定82/84/86/88帧波间等待、活动时长、lane偏移和逐rank正速度；前三根长度独立取`40+rand(81)`，第四根由前三个raw抽值相加模81得到，同样位于40..120。

实测首生帧95；seed1/7最后出生分别为1365/1363；理论最晚出生上界1415、最晚自然回收上界1727。实际最后fade/回收帧分别为：rank0 seed1 1616/1617、seed7 1674/1675；rank1 1601/1602、1659/1660；rank2 1586/1587、1644/1645；rank3 1571/1572、1629/1630。帧1800全矩阵均无激光，phase事件在帧1803结束。完整矩阵峰值激光16、峰值任务19；最大组生命周期312帧，最短组间隔82帧，最多4组同时存在，内段无空档。

## 最终快照验证

- 编译：`/data/sunyunbo/www/stg-engine/target/release/stg-harness check /tmp/sunyunbo/stg-laser-batch3/laser_sp_bars_04`，输出`OK`，日志`/tmp/sunyunbo/stg-laser-batch3/logs/bars_04/r2-final-check.log`。
- 完整矩阵：rank0..3 × seed1/7，各运行`stg-harness run <目录> --rank R --seed S --frames 1860`。8次退出码均0；六个诊断项`task_faults`、`contract_viol`、`pool_full`、`hits_ovf`、`events_ovf`、`reqs_dropped`均为0；每次报告`PHASE_ENDED@1803`、峰值激光16、1860帧末激光0。日志为`/tmp/sunyunbo/stg-laser-batch3/logs/bars_04/r2-final-rankR-seedS.log`。
- machine-spec含56个唯一rank/frame关键帧、每rank14帧：首生、预警边界、生效首帧、交接、两seed的高并发帧、两个实际末出生帧、两seed逐rank最后fade及回收帧、time_limit帧1800和phase结束帧1803。每点都重采了seed1/7，并逐条校验count/state及x/y/angle/near/far/width范围；相关日志前缀为`/tmp/sunyunbo/stg-laser-batch3/logs/bars_04/r2-final-at-`。

上述通过仅属作者harness和machine-spec自检，不代替协调者正式机器门。当前SHA的玩家避让、静止站点结果和source复审仍待独立复测；没有训练收益结论。
