import { mockSCPs } from "../data/Data";

// 底部标签栏配置接口
export interface TabClass {
  icon: ResourceStr,      // 未选中时的图标
  icon_em: ResourceStr,   // 选中时的图标
  text: string            // 标签文字
}

// SCP项目分类标准
// export type SCPClass =
//   '无' |
//   'Unknown' |
//   'Safe' |     // 安全 - 需最低限度监管
//   'Euclid' |   // 欧几里得 - 需特定收容措施
//   'Keter' |    // 克特级 - 极度危险需最高优先级收容
//   'Thaumiel' | // 瑟姆级 - 用于收容其他SCP
//   'Apollyon' | // 阿波罗级 - 无法被完全收容
//   'Explained'; // 已解明 - 已解明异常特性

// SCP项目接口定义
export interface SCP {
  id: string;                           // 项目唯一标识
  number: string;                       // SCP编号
  title: string;                        // 项目标题
  objectClass: string;                // 项目等级
  image?: string;                       // 项目图片URL
  description: string;                  // 项目描述
  containmentProcedures: string;        // 特殊收容措施
  addendum?: string;                    // 附录
  interviews?: string;                  // 访谈记录
  series: number;                       // 系列编号
  dateAdded: string;                    // 添加日期
  tags: string[];                       // 标签列表
  isFavorited?: boolean;                // 是否已收藏
  dynamicFields?: Record<string, string>; // 动态字段，用于存储API返回的额外内容
}

// 折叠卡片数据接口
export interface CollapsibleCardData {
  title: string;                        // 卡片标题
  content: string | Array<string>;     // 卡片内容
  priority: number;                     // 显示优先级，数字越小优先级越高
}

// SCP故事接口定义
export interface Tale {
  id: string;                           // 故事唯一标识
  title: string;                        // 故事标题
  author: string;                       // 作者
  content: string;                      // 故事内容
  datePublished: string;                // 发布日期
  tags: string[];                       // 标签列表
  relatedSCPs: string[];                // 相关SCP项目列表
  isFavorited?: boolean;                // 是否已收藏
}

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

// BasicDataSource实现了IDataSource接口，用于管理listener监听，以及通知LazyForEach数据更新
class BasicDataSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private originDataArray: SCP[] = [];

  // 获取数据总数
  public totalCount(): number {
    return this.originDataArray.length;
  }

  // 根据索引获取数据
  public getData(index: number): SCP {
    return this.originDataArray[index];
  }

  // 该方法为框架侧调用，为LazyForEach组件向其数据源处添加listener监听
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      console.info('add listener');
      this.listeners.push(listener);
    }
  }

  // 该方法为框架侧调用，为对应的LazyForEach组件在数据源处去除listener监听
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      console.info('remove listener');
      this.listeners.splice(pos, 1);
    }
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  // 通知LazyForEach组件需要在index对应索引处添加子组件
  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.ADD, index: index}]);
    });
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.CHANGE, index: index}]);
    });
  }

  // 通知LazyForEach组件需要在index对应索引处删除该子组件
  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
      // 写法2：listener.onDatasetChange([{type: DataOperationType.DELETE, index: index}]);
    });
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
      // 写法2：listener.onDatasetChange(
      //         [{type: DataOperationType.EXCHANGE, index: {start: from, end: to}}]);
    });
  }

  // 通知数据集变化
  notifyDatasetChange(operations: DataOperation[]): void {
    this.listeners.forEach(listener => {
      listener.onDatasetChange(operations);
    });
  }
}

// SCP数据源类，继承自BasicDataSource
@ObservedV2
export class SCPSource extends BasicDataSource {
  @Trace private dataArray: SCP[] = [];

  // 获取数据总数
  public totalCount(): number {
    return this.dataArray.length;
  }

  // 根据索引获取数据
  public getData(index: number): SCP {
    return this.dataArray[index];
  }

  // 向数据数组中添加数据
  public pushData(data: SCP): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

  // 设置数据
  public setData(newData: SCP[]): void {
    this.dataArray = [...newData];
    this.notifyDataReload();
  }
}

// 带加载状态的图片组件
@ComponentV2
export struct ImageWithLoading {
  // 图片的URL，通过@Prop接收
  @Param @Require src: string;
  // 宽度，支持百分比或固定值
  @Param @Require imgWidth: string | number;
  // 高度，支持百分比或固定值
  @Param @Require imgHeight: string | number;
  // 图片圆角
  @Param imgRadius: BorderRadiuses = {topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0};
  // 图片填充模式
  @Param objectFit: ImageFit = ImageFit.Cover;

  // 加载状态，初始为true
  @Local private isLoading: boolean = true;
  // 加载失败状态
  @Local private isError: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 当图片加载中时显示加载动画
      if (this.isLoading) {
        LoadingProgress()
          .width(60)
          .height(60);
      }

      // 当图片加载失败时显示一个占位符
      if (!this.isLoading && this.isError) {
        Image($r('app.media.SCP_icon'))
          .width(this.imgWidth)
          .height(this.imgHeight)
          .borderRadius(this.imgRadius)
          .objectFit(ImageFit.Cover)
          .backgroundColor(Color.Gray);
      }

      // Image组件，绑定src并监听加载完成和失败事件
      Image(this.src)
        .width(this.imgWidth)
        .height(this.imgHeight)
        .borderRadius(this.imgRadius)
        .objectFit(this.objectFit)
        .onComplete(() => {
          this.isLoading = false;
        })
        .onError(() => {
          this.isLoading = false;
          this.isError = true;
          console.error('图片加载失败:', this.src);
        })
          // 在加载中或加载失败时，让图片完全透明
        .opacity(this.isLoading || this.isError ? 0 : 1);
    }
    .width(this.width)
    .height(this.height);
  }
}