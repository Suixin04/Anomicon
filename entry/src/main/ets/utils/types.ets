import { HashMap } from "@kit.ArkTS";
import { mockSCPs } from "../data/mockData";

export interface TabClass {
  icon: ResourceStr,
  icon_em: ResourceStr,
  text: string
}
/** SCP项目分类标准 */
export type SCPClass =
  'Safe' |     // 需最低限度监管
  'Euclid' |   // 需特定收容措施
  'Keter' |    // 极度危险需最高优先级收容
  'Thaumiel' | // 用于收容其他SCP
  'Apollyon' | // 无法被完全收容
  'Explained'; // 已解明异常特性

export const colorHash = new HashMap<string, string>();
colorHash.set('Safe', '#FF10B981');
colorHash.set('Euclid', '#FFEAB308');
colorHash.set('Keter', '#FFEF4444');
colorHash.set('Thaumiel', '#FF3B82F6');
colorHash.set('Apollyon', '#FF8B5CF6');
colorHash.set('Explained', '#FF6B7280');

export const iconHash = new HashMap<string, string>();
iconHash.set('Safe', '🟢');
iconHash.set('Euclid', '🟡');
iconHash.set('Keter', '🔴');
iconHash.set('Thaumiel', '🔵');
iconHash.set('Apollyon', '🟣');
iconHash.set('Explained', '⚪');

export interface SCP {
  id: string;
  number: string;
  title: string;
  objectClass: SCPClass;
  image?: string;
  description: string;
  containmentProcedures: string;
  addendum?: string;
  interviews?: string;
  series: number;
  dateAdded: string;
  tags: string[];
  isFavorited?: boolean;
}

export interface Tale {
  id: string;
  title: string;
  author: string;
  content: string;
  datePublished: string;
  tags: string[];
  relatedSCPs: string[];
  isFavorited?: boolean;
}

@ObservedV2
export class RandomNum {
  @Trace randomIdx: number = Math.floor(Math.random() * mockSCPs.length)
  setNum(Num: number) {
    this.randomIdx = Num
  }
  getNum() {
    return this.randomIdx
  }
}