import { HashMap } from "@kit.ArkUI";
import { mockSCPs } from "../data/mockData";

// 底部标签栏配置接口
export interface TabClass {
  icon: ResourceStr,      // 未选中时的图标
  icon_em: ResourceStr,   // 选中时的图标
  text: string            // 标签文字
}

// SCP项目分类标准
export type SCPClass =
  'Safe' |     // 安全 - 需最低限度监管
  'Euclid' |   // 欧几里得 - 需特定收容措施
  'Keter' |    // 克特级 - 极度危险需最高优先级收容
  'Thaumiel' | // 瑟姆级 - 用于收容其他SCP
  'Apollyon' | // 阿波罗级 - 无法被完全收容
  'Explained'; // 已解明 - 已解明异常特性

// SCP项目等级对应的颜色映射表
export const colorHash = new HashMap<string, string>();
colorHash.set('Safe', '#FF10B981');
colorHash.set('Euclid', '#FFEAB308');
colorHash.set('Keter', '#FFEF4444');
colorHash.set('Thaumiel', '#FF3B82F6');
colorHash.set('Apollyon', '#FF8B5CF6');
colorHash.set('Explained', '#FF6B7280');

// SCP项目等级对应的图标映射表
export const iconHash = new HashMap<string, string>();
iconHash.set('Safe', '🟢');
iconHash.set('Euclid', '🟡');
iconHash.set('Keter', '🔴');
iconHash.set('Thaumiel', '🔵');
iconHash.set('Apollyon', '🟣');
iconHash.set('Explained', '⚪');

// SCP项目接口定义
export interface SCP {
  id: string;                           // 项目唯一标识
  number: string;                       // SCP编号
  title: string;                        // 项目标题
  objectClass: SCPClass;                // 项目等级
  image?: string;                       // 项目图片URL
  description: string;                  // 项目描述
  containmentProcedures: string;        // 特殊收容措施
  addendum?: string;                    // 附录
  interviews?: string;                  // 访谈记录
  series: number;                       // 系列编号
  dateAdded: string;                    // 添加日期
  tags: string[];                       // 标签列表
  isFavorited?: boolean;                // 是否已收藏
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
  // 随机索引值
  @Trace randomIdx: number = Math.floor(Math.random() * mockSCPs.length)
  
  // 设置随机索引值
  setNum(Num: number) {
    this.randomIdx = Num
  }
  
  // 获取随机索引值
  getNum() {
    return this.randomIdx
  }
}