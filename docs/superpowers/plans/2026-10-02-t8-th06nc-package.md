# T8四根激光模型与TH06NC包

用户明确要求适配并打包模型与mod；执行已确认的图版本6接口，不再等待路线审批。

- [x] 导出T8 best=u3500为640弹／256敌／64原始激光行的版本6ONNX；图内挑4根、联合序列68，torch/ORT对拍。
- [x] 在stg-agent-proto的sa_model/sa_onnx接入原始激光12列、mask和start_len，共12输入，兼容图2–5；保持wire协议、动作表和既有TH06NC地址／hook不变。
- [x] TH06NC共享接口重编译，host测试及真实ORT会话／C填表对拍；检查目标exe地址绑定。
- [x] T8专用包默认t8-laser-k4-best.onnx，沿用现有运动层、锚点和压力切换，包含DLL、ORT与许可证、模型manifest、来源／安装说明和SHA256SUMS。
- [x] 独立审查、解包检查。能验证Windows加载／运行则验证；没有游戏操作证据时明确不声称实机验收。不提交、不推送、不发布Release。

约束：main工作，不建worktree；各仓已有改动与:memory:.ses保留。无新依赖选择、无游戏exe／资产入包。shared C worker只负责共享C文件和精简行为覆盖，发现新架构问题报告主agent。主agent负责导出、包、跨运行时验证与说明。
