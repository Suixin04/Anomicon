import {
  LibraryContentKind,
  LibraryContentRef
} from 'library';

/** 终端知识目录的稳定分区标识。 */
export enum FoundationKnowledgeSectionId {
  OVERVIEW = 'overview',
  SYSTEM = 'system',
  ORGANIZATION = 'organization',
  COMMUNITY = 'community'
}

/**
 * 知识条目的图标语义。
 *
 * 数据模型不持有 ArkUI Resource；界面层据此映射到系统 Symbol Resource。
 */
export enum FoundationKnowledgeIcon {
  FOUNDATION = 'foundation',
  CLASSIFICATION = 'classification',
  CLEARANCE = 'clearance',
  TASK_FORCE = 'task_force',
  DEPARTMENT = 'department',
  FACILITY = 'facility',
  GROUP = 'group',
  HISTORY = 'history'
}

/** 可直接用于 ArkUI ForEach 的静态知识条目。 */
export class FoundationKnowledgeItem {
  readonly key: string;
  readonly content: LibraryContentRef;
  readonly title: string;
  readonly subtitle: string;
  readonly icon: FoundationKnowledgeIcon;
  readonly section: FoundationKnowledgeSectionId;

  constructor(
    id: string,
    title: string,
    subtitle: string,
    icon: FoundationKnowledgeIcon,
    section: FoundationKnowledgeSectionId,
    kind: LibraryContentKind
  ) {
    this.content = new LibraryContentRef(kind, id, title);
    this.key = this.content.key;
    this.title = this.content.title;
    this.subtitle = subtitle;
    this.icon = icon;
    this.section = section;
  }
}

/** 已分组的终端知识目录；items 顺序即界面展示顺序。 */
export class FoundationKnowledgeSection {
  readonly id: FoundationKnowledgeSectionId;
  readonly title: string;
  readonly subtitle: string;
  readonly items: FoundationKnowledgeItem[];

  constructor(
    id: FoundationKnowledgeSectionId,
    title: string,
    subtitle: string,
    items: FoundationKnowledgeItem[]
  ) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.items = items;
  }
}

const FOUNDATION_OVERVIEW = new FoundationKnowledgeItem(
  'about-the-scp-foundation',
  '关于 SCP 基金会',
  '了解基金会的使命、原则与基本设定',
  FoundationKnowledgeIcon.FOUNDATION,
  FoundationKnowledgeSectionId.OVERVIEW,
  LibraryContentKind.KNOWLEDGE
);

const OBJECT_CLASSES = new FoundationKnowledgeItem(
  'object-classes',
  '项目等级',
  '理解收容难度与项目分类体系',
  FoundationKnowledgeIcon.CLASSIFICATION,
  FoundationKnowledgeSectionId.SYSTEM,
  LibraryContentKind.KNOWLEDGE
);

const ESOTERIC_CLASSES = new FoundationKnowledgeItem(
  'esoteric-classes-complete-list',
  '机密分级完整列表',
  '查阅非常规与叙事性项目等级，各分级并无固定高低之分',
  FoundationKnowledgeIcon.CLASSIFICATION,
  FoundationKnowledgeSectionId.SYSTEM,
  LibraryContentKind.KNOWLEDGE
);

const SECURITY_CLEARANCE_LEVELS = new FoundationKnowledgeItem(
  'security-clearance-levels',
  '安保许可等级',
  '了解人员等级、信息访问与权限结构',
  FoundationKnowledgeIcon.CLEARANCE,
  FoundationKnowledgeSectionId.SYSTEM,
  LibraryContentKind.KNOWLEDGE
);

const TASK_FORCES = new FoundationKnowledgeItem(
  'task-forces',
  '机动特遣队',
  '了解特遣队的编制、职责与任务索引',
  FoundationKnowledgeIcon.TASK_FORCE,
  FoundationKnowledgeSectionId.ORGANIZATION,
  LibraryContentKind.KNOWLEDGE
);

const DEPARTMENTS = new FoundationKnowledgeItem(
  'departments',
  '基金会部门',
  '浏览基金会部门及其职能索引',
  FoundationKnowledgeIcon.DEPARTMENT,
  FoundationKnowledgeSectionId.ORGANIZATION,
  LibraryContentKind.KNOWLEDGE
);

const SECURE_FACILITIES = new FoundationKnowledgeItem(
  'secure-facilities-locations',
  '设施与地点',
  '查阅站点、区域与其他设施索引',
  FoundationKnowledgeIcon.FACILITY,
  FoundationKnowledgeSectionId.ORGANIZATION,
  LibraryContentKind.KNOWLEDGE
);

const GROUPS_OF_INTEREST = new FoundationKnowledgeItem(
  'groups-of-interest',
  '相关组织',
  '认识与基金会相关的组织、势力与团体',
  FoundationKnowledgeIcon.GROUP,
  FoundationKnowledgeSectionId.ORGANIZATION,
  LibraryContentKind.KNOWLEDGE
);

const WIKI_COMMUNITY_HISTORY = new FoundationKnowledgeItem(
  'history-of-the-universe-hub',
  'SCP 维基与社群历史',
  '回顾 SCP 维基与创作社群的现实发展历程',
  FoundationKnowledgeIcon.HISTORY,
  FoundationKnowledgeSectionId.COMMUNITY,
  LibraryContentKind.WIKI
);

/** 终端首页的默认知识分组。 */
export const FOUNDATION_KNOWLEDGE_SECTIONS: FoundationKnowledgeSection[] = [
  new FoundationKnowledgeSection(
    FoundationKnowledgeSectionId.OVERVIEW,
    '基金会概览',
    '从使命与基本设定开始',
    [FOUNDATION_OVERVIEW]
  ),
  new FoundationKnowledgeSection(
    FoundationKnowledgeSectionId.SYSTEM,
    '制度与权限',
    '项目分类、特殊分级和信息访问规则',
    [OBJECT_CLASSES, ESOTERIC_CLASSES, SECURITY_CLEARANCE_LEVELS]
  ),
  new FoundationKnowledgeSection(
    FoundationKnowledgeSectionId.ORGANIZATION,
    '组织与行动',
    '人员、设施和相关势力',
    [TASK_FORCES, DEPARTMENTS, SECURE_FACILITIES, GROUPS_OF_INTEREST]
  ),
  new FoundationKnowledgeSection(
    FoundationKnowledgeSectionId.COMMUNITY,
    '维基与社群历史',
    '站点与创作社群的真实发展脉络',
    [WIKI_COMMUNITY_HISTORY]
  )
];
