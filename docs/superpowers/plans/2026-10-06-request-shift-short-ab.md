# 请求惩罚与 Shift 惩罚短轮 A/B 执行计划

用户已授权并行训练两组，暂不改变运动层。两组均 T7/K8、player15、v8/v3/图6、同一 T7 u3500 权重、seed1、新优化器、学习率1e-4、1000更新。A 请求key_press=-0.001/quick_change=-0.003/shift_toggle=0；B只将shift_toggle改为-0.003。250/500/1000评测。两组同用等价排序优化的stg_rl0.4.2。

## 全局约束

- 在main工作，未获commit/push授权，不执行这些操作。
- 权重初始化是新实验，不能恢复旧optimizer、学习率状态、RNG、计数、best或reward配置。
- 运动层hold=[2,6]/delay=[0,2]/slow=true不动，输入不加请求/执行维度。
- 已有检查通过后停止扩展验证；仅为关键权重初始化行为补紧凑真实测试。
- Magnus用B2，提交前看CPU/GPU空闲，每组1GPU/32CPU/64G；新API先测旧CPU栈，Job内严格GPUcheck。
- 文件通过既有File Custody源码覆盖机制传送，固定main基底与归档、逐文件SHA验证，上传包含初始化权重；不发布Release。

## 任务与文件责任

1. 子代理warmstart_entry：仅train.py/ppo.py/test_checkpoint.py/test_smoke.py，实现--init-from及来源记录；相关本地/旧CPU检查。不得修改配置、运动层或提交Job。
2. 主代理：两份实验配置、既有Magnus runner复用、覆盖归档/权重校验、两条Job提交和监控，更新实验记录。
3. 主代理检查实际diff与证据，再派既有review_request_reward只读审阅新增初始化逻辑和配置。发现关键问题回交原实现者。

任务1提供--init-from接口，任务2消费它；其他文件职责不重叠。接口参数、配置一致性和初始化权重SHA在提交前核验。已有排序优化接入验证完成，不重复运行。

## 进度

- 适配层接入：完成。本地/旧CPU相关53+53通过，引擎Python15通过，Rust相关测试通过，六组旧新回放一致，锁文件和wheel同哈希。
- 初始化入口：完成，相关本地/旧CPU栈各20通过，四项紧凑新增行为覆盖。只读审阅无Critical/Important问题。
- 两组配置与上传：完成，完整配置只差shift项，motor不变，同一T7权重严格加载检查通过。固定base+14文件覆盖包，上传下载同SHA。
- 提交：完成，A9436bd073b636c2b/Bb3ef72c1ca44515d，均B2/1GPU/32CPU/64G。后台Python监控已启动。
- GPUcheck/真实训练确认：完成，两条均PASS，15:16均已u9，本轮SPS66.7k/66.4k。实际32核/旧CUDA栈/0.4.2版本和来源SHA已日志确认。两个Python后台监视进程存活，任务正常结束或提前退出均处理。
