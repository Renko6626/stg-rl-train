# synth_laser_s5_w05

## 变异几何与时间

- 一次出生1条短段旋转激光，原点(0,80)，width8、color15，`start=80`、`end=240`，实际激光段长160px。
- 初角由随机16-bit BAM决定，旋转方向每局随机正/反；warn45、active120、fade12。rank0/1/2/3角速幅值48/64/96/128 BAM/frame。
- 世界帧123首生，frame300回收；任务wait到333后结束，早于600限时。峰值新增1条。

## 随机数与rank

一次rand选初角、一次rand选旋向，消耗共享engine RNG并改变底子后续随机流；seed1/7应在初角或旋向上不同。rank只改角速幅值，警告窗口、段长和初角分布不变。

## 关键帧预期

- 帧124 warn，start80/end240，角度按初角加一帧signed omega；帧168进入active；帧184/214/254仍active。
- 帧288进入fade、帧300消失；帧334数量0。由于omega三态都生效，所有抽样角度按0..360°回绕范围判定。
