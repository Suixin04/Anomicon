// 随机数类，用于生成每日推荐SCP项目
@ObservedV2
export class RandomNum {
  // 随机索引值，初始化默认0，由页面在加载数据后设定上限范围
  @Trace randomIdx: number = 0;

  // 设置随机索引值
  setNum(Num: number) {
    this.randomIdx = Num
  }

  // 获取随机索引值
  getNum() {
    return this.randomIdx
  }
}