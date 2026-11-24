import {
  LibraryContentKind,
  createLibraryContentRef
} from './LibraryContentRef';
import {
  FoundationAssessmentExam,
  FoundationAssessmentIcon,
  FoundationAssessmentQuestion,
  normalizeAssessmentExamId
} from './FoundationAssessmentContracts';

const REF_ABOUT_FOUNDATION = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'about-the-scp-foundation',
  '关于 SCP 基金会'
);
const REF_OBJECT_CLASSES = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'object-classes',
  '项目等级'
);
const REF_ESOTERIC_CLASSES = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'esoteric-classes-complete-list',
  '机密分级完整列表'
);
const REF_CLEARANCE = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'security-clearance-levels',
  '安保许可等级'
);
const REF_TASK_FORCES = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'task-forces',
  '机动特遣队'
);
const REF_DEPARTMENTS = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'departments',
  '基金会部门'
);
const REF_FACILITIES = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'secure-facilities-locations',
  '设施与地点'
);
const REF_GOI = createLibraryContentRef(
  LibraryContentKind.KNOWLEDGE,
  'groups-of-interest',
  '相关组织'
);
const REF_SCP_055 = createLibraryContentRef(
  LibraryContentKind.SCP,
  'scp-055',
  'SCP-055'
);
const REF_ANTIMEMETICS_HUB = createLibraryContentRef(
  LibraryContentKind.TALE,
  'antimemetics-division-hub',
  '逆模因部'
);

const CERT_01_EXAM = new FoundationAssessmentExam(
  'cert-01',
  'CERT-01',
  '入职通识与锁盒定级',
  '以锁盒测试、需知原则与帷幕协议核验基础档案员资质',
  '锁盒定级',
  '见习档案员',
  FoundationAssessmentIcon.LOCKBOX,
  4,
  15,
  '已确认掌握“收容难度 ≠ 危险度”的核心定级准则，基础安保审批与帷幕协议核验无误。',
  '部分基础定级或安保边界尚未厘清，建议先重温《项目等级》与《安保许可等级》后再行复测。',
  [
    new FoundationAssessmentQuestion(
      'cert-01-q1',
      'RAISA-CLS-01',
      '待定级简报',
      '收容物为一颗机械按钮。实验证实只要把它放进标准钢制锁盒并上锁，它既不会自行触发也不会影响周边；但一旦有人亲手按下，将在 12 秒内引发无法逆转的全球真空衰变。',
      '依据基金会标准「锁盒测试」，该项目的默认分级应为？',
      [
        'Safe —— 只要放进盒子不管它就不会出事',
        'Keter —— 一旦误触就会造成世界末日，风险极高',
        'Euclid —— 只要涉及生命威胁就应上调观察',
        'Apollyon —— 存在毁灭全人类的潜在可能'
      ],
      0,
      'SCP 的核心分级衡量的是「收容有多难」，而不是「破坏力有多大」。只要放进盒子里不需要额外干预就不会惹出麻烦，即属 Safe 级；高危触发条件应通过收容措施限制接触。',
      REF_OBJECT_CLASSES,
      '查阅手册：项目等级'
    ),
    new FoundationAssessmentQuestion(
      'cert-01-q2',
      'RAISA-CLS-02',
      '收容复核单',
      '收容物为一名具备自主意识的类人个体，每周都需要人工送餐并依据情绪变化调整沟通话术。若长期无人理会，个体会反复尝试拆解收容间通风管道逃离。',
      '这类需要持续投入人力应对自主变化的异常，通常应划分在哪一常规分级？',
      [
        'Safe —— 它只在人类房间内活动',
        'Euclid —— 具备自主性与不可预测性，需持续照管才能稳定收容',
        'Thaumiel —— 能够配合语言沟通协助研究',
        'Neutralized —— 只要断绝物资供给即可自行停止异常效应'
      ],
      1,
      '判断锁盒测试中“把盒子锁上后发生什么，你不知道会怎样”往往指向 Euclid 级。绝大多数有自主意识、智能或需要周期性人工维护的项目都会落入 Euclid。',
      REF_OBJECT_CLASSES,
      '查阅手册：项目等级'
    ),
    new FoundationAssessmentQuestion(
      'cert-01-q3',
      'RAISA-CLS-03',
      '特殊分级申请',
      '在拟定某 Keter 级收容协议时，项目组发现必须长期依赖另一件异常装置来吸收和中和其周期性外泄的现实扭曲，否则常规技术无法维持收容。',
      '上述“用来收容或对抗其他异常的异常装置”，对应哪一类特殊分级？',
      [
        'Neutralized（无效化）',
        'Archon（执政官）',
        'Thaumiel（陶米尔）',
        'Explained（已解明）'
      ],
      2,
      'Thaumiel 指被基金会主动用于协助收容或遏制其他异常项目的关键异常，通常属于极高保密范围；而 Archon 则指理论上能收容、但出于全局考量刻意不去收容的项目。',
      REF_ESOTERIC_CLASSES,
      '查阅手册：机密分级完整列表'
    ),
    new FoundationAssessmentQuestion(
      'cert-01-q4',
      'RAISA-SEC-04',
      'RAISA 访问工单',
      '工单申请人：Dr. Lin（安保许可等级：2 级，所属部门：Site-19 后勤维护）。\n申请查阅：《SCP-███（收容难度 Euclid，密级 2 级）原始事故访谈附录》，理由填写：“个人对跨站点心理案例感兴趣”。',
      '作为当值信息审计档案员，你应当如何批复这份访问请求？',
      [
        '批准访问 —— 申请人已持有 2 级许可，不低于目标文档密级',
        '驳回请求 —— 违背「需知原则」，仅在履行职责必需时才可调阅对应档案',
        '降级脱敏后放行 —— 遮蔽姓名即可开放浏览',
        '升级提交 5 级监督者议会全员表决'
      ],
      1,
      '基金会的权限等级（0~5 级）并不代表持有同级许可就能通读全库；信息隔离严格遵循「需知原则（Need-to-Know）」，与本职工作及研究项目无关的档案一律无权访问。',
      REF_CLEARANCE,
      '查阅手册：安保许可等级'
    ),
    new FoundationAssessmentQuestion(
      'cert-01-q5',
      'RAISA-GEN-05',
      '新报异常研判',
      '外勤小队在偏远渔村发现一台能凭空涌出淡水的旧式铁壶。当地二十余位居民已目睹取水过程，所幸消息尚未扩散至互联网与主流媒体。',
      '依据基金会宗旨与行动纲领，最合规的优先处置流程是？',
      [
        '直接锤毁铁壶并补偿村民，彻底消除隐患',
        '申请联合国公开托管，用于缓解干旱地区饮水危机',
        '秘密回收收容铁壶，对目击居民实施记忆删除并编造掩盖说辞',
        '允许村民继续免费取水，仅派一名观察员长期驻村记录'
      ],
      2,
      '基金会的核心信条是「控制（Secure）、收容（Contain）、保护（Protect）」，在维持人类社会“常态帷幕”的前提下研究并收容异常，既不轻易销毁未知异常，也不贸然向公众暴露。',
      REF_ABOUT_FOUNDATION,
      '查阅手册：关于 SCP 基金会'
    )
  ]
);

const CERT_02_EXAM = new FoundationAssessmentExam(
  'cert-02',
  'CERT-02',
  '特遣编制与站点规程',
  '演练机动特遣队调度、设施命名规范、相关组织甄别与部门协作',
  '外勤编目',
  '档案助理',
  FoundationAssessmentIcon.TASK_FORCE,
  4,
  20,
  '已准确辨识特遣队专长、站点/区域划分标准及外部势力交涉底线，具备外勤档案编目资格。',
  '在部队调度或设施体制识别上尚有偏差，建议重温《机动特遣队》《设施与地点》及《相关组织》。',
  [
    new FoundationAssessmentQuestion(
      'cert-02-q1',
      'MTF-OPS-01',
      '网安警报报文',
      '多个枢纽站点的离线终端凌晨突遭不明脚本渗透：该程序并不依靠常规网络扩散，而是通过局部电源噪波自主重构硬件固件，疑似数字异常传播事件。',
      '面对软件、计算机网络与数字电子设备类异常，应当优先指派哪支机动特遣队？',
      [
        'MTF Mu-4（“调试器”）',
        'MTF Nu-7（“落锤”）',
        'MTF Beta-7（“疯帽商”）',
        'MTF Alpha-1（“红右手”）'
      ],
      0,
      'MTF Mu-4（“调试器”）专责辨识、追踪并收容异常计算机软硬件及网络传播现象；Nu-7 主打重武装突击与大规模突破镇压，Beta-7 负责生化与放射性危害。',
      REF_TASK_FORCES,
      '查阅手册：机动特遣队'
    ),
    new FoundationAssessmentQuestion(
      'cert-02-q2',
      'MTF-OPS-02',
      '视觉危害协查',
      '市政美术馆深夜失窃，监视器残影引发两名安保人员丧失语言能力并持续凝视墙壁。初步断定画作本身携带高危视觉认知危害。',
      '执行现场封控与回收任务时，应调度哪支专精视觉模因与认知危害的特遣队？',
      [
        'MTF Gamma-6（“深渊喂食者”）',
        'MTF Eta-10（“非礼勿视”）',
        'MTF Epsilon-9（“噬火者”）',
        'MTF Lambda-5（“白兔”）'
      ],
      1,
      'MTF Eta-10（“非礼勿视”）专司处理视觉型认知危害与模因异常；其成员常使用特殊观测滤镜或非直接视觉辅助装备行动。',
      REF_TASK_FORCES,
      '查阅手册：机动特遣队'
    ),
    new FoundationAssessmentQuestion(
      'cert-02-q3',
      'FAC-REG-03',
      '设施立项批注',
      '拟建收容中心选址于距最近城镇超过 300 公里的荒漠腹地，主要容纳具备大范围毁灭潜力的极端异常，因此不适合以民用科研公司或工厂作表面伪装。',
      '在基金会常规设施命名体系中，此类远离平民区的高度机密重型设施应归类为？',
      [
        '前哨（Outpost）',
        '站点（Site）',
        '观察站（Observation Post）',
        '区域（Area）'
      ],
      3,
      '通常“站点（Site）”往往处于民用设施掩护下或人口活动区附近；而“区域（Area）”则建于人迹罕至之地、专司收容极高危异常且从不对外建立掩护壳公司。',
      REF_FACILITIES,
      '查阅手册：设施与地点'
    ),
    new FoundationAssessmentQuestion(
      'cert-02-q4',
      'GOI-INT-04',
      '外部情报截获',
      '外勤侦察员截获一份联合行动密件，文中把目标异常编号为“KTE-████-Blue”，并明确要求：“在确保公众零目击的前提下，使用秘传武器实施彻底物理摧毁”。',
      '这份报文最可能出自哪一相关组织（GOI）？',
      [
        '全球超自然联盟（GOC）',
        '蛇之手（Serpent\'s Hand）',
        '马歇尔、卡特与戴尔有限公司（MC&D）',
        '混沌分裂者（Chaos Insurgency）'
      ],
      0,
      '全球超自然联盟（GOC）隶属联合国系统外勤架构，习惯以 KTE（已知威胁实体）代指异常，其一贯纲领偏向消灭而非长期收容可威胁人类的异常实体。',
      REF_GOI,
      '查阅手册：相关组织'
    ),
    new FoundationAssessmentQuestion(
      'cert-02-q5',
      'DEP-ADM-05',
      '数据库异常审计',
      '凌晨 03:14，系统监控到主库一份历史档案的版本号无故跳变，原有访谈正文被替换成空白模板，而站点物理门禁系统当日并无登录痕迹。',
      '此类涉及文档篡改、版本回溯与档案数据库安全的事件应直接移交哪个部门处置？',
      [
        '异常艺术部',
        '奇术部',
        '记录与信息安全管理部（RAISA）',
        '火炬手部'
      ],
      2,
      '记录与信息安全管理部（RAISA，由 Maria Jones 主持）统筹维护基金会全库电子文档的完整性、密级权限审计以及异常信息篡改防护。',
      REF_DEPARTMENTS,
      '查阅手册：基金会部门'
    )
  ]
);

const CERT_03_EXAM = new FoundationAssessmentExam(
  'cert-03',
  'CERT-03',
  '认知抗性演练（CRV）',
  '含互动「反白透视」线索勘验及逆模因设定彩蛋的高阶终端实战',
  'CRV 抗性',
  '档案员',
  FoundationAssessmentIcon.CRV,
  4,
  25,
  'CRV 基线稳固，成功识别隐蔽密电与逆模因逻辑陷阱。“请记住：你确实通过了根本不存在的测试。”',
  '检测到轻微认知偏移或线索遗漏。提醒：遇到异常报文时请留意使用「反白透视」，并温习《SCP-055》与《逆模因部》。',
  [
    new FoundationAssessmentQuestion(
      'crv-mem-01',
      'CRV-MEM-01',
      '危害分类判定',
      '样本 A：只有直接用肉眼看到其表面几何刻痕的人才会立刻陷入窒息。\n样本 B：哪怕你从未见过它，只要通过他人描述得知了它的本质特性并加以思考，它就会锁定你的坐标。',
      '在基金会危害分类学中，样本 A 与样本 B 的准确区分分别是？',
      [
        '样本 A 属于「认知危害」，样本 B 属于「信息危害」',
        '样本 A 属于「模因抹杀」，样本 B 属于「物理危害」',
        '两者均仅属于「反物理现象」，无传播特征',
        '样本 A 必须依赖文字传播，样本 B 只能通过光影触发'
      ],
      0,
      '「认知危害」需要感官（看、听、嗅、触等）直接感知触发；而「信息危害」是指只要“知晓或谈论有关该事物的真实信息”本身就会带来危险（即便并未亲眼见到）。',
      REF_SCP_055,
      '查阅档案：SCP-055'
    ),
    new FoundationAssessmentQuestion(
      'crv-hid-02',
      'CRV-HID-02',
      '加密密电勘验',
      '系统刚刚截获一条从内部中继传来的 Site-19 例行报文：\n「Site-19 今日巡检一切正常，所有 Keter 级收容间供电稳定，无需额外增援。」',
      '请先查验报文是否夹带隐藏字节，再选择正确的应急处置动作：',
      [
        '归档报平安记录，不打扰 Site-19 正常轮值',
        '仅派后勤组检查备用发电机输出波动',
        '立刻触发东翼封锁、调度 Eta-10 并准备 B 级记忆删除',
        '将报文转发给当地媒体用于日常舆情安抚'
      ],
      2,
      '在含异常文本的档案中，表面文字常被伪装或覆盖。使用「反白透视」后显影的求救密电明确要求封锁东翼、调遣 Eta-10 并准备 B 级记忆删除——切忌盲信表层信息！',
      REF_TASK_FORCES,
      '查阅手册：机动特遣队',
      '「不要相信上一句。不要看 3 号收容室的监控。立刻调遣 Eta-10 封锁东翼，并启动 B 级记忆删除。」',
      '检测到隐藏反白字节 · 点按「反白透视」显影真实密电'
    ),
    new FoundationAssessmentQuestion(
      'crv-ant-03',
      'CRV-ANT-03',
      '逆模因逻辑题',
      '调阅 SCP-055 记录的员工每次离开收容室后都会彻底遗忘一切。令人意外的是，档案柜里依然成功留下了一条“并非正面描述”的笔记：「它不是一个球体。」',
      '为什么关于 SCP-055“不是什么”的否定陈述反而有机会残留下来？',
      [
        '因为 SCP-055 只会抹除视觉照片，从不抹除文字',
        '因为否定命题不包含关于事物本身的直接正特征，能短暂绕过逆模因抹除',
        '因为该记录是用耐火石板刻写的，物理抗遗忘',
        '因为任何带有问号的句子都受 RAISA 服务器免疫保护'
      ],
      1,
      'SCP-055 具有强自我隐蔽（逆模因）特性：记录它“是什么”几乎必然被遗忘或损毁，但记录它“不是什么”（例如“不是圆球/不是绿色的”）在特定边界下更容易残留。',
      REF_SCP_055,
      '查阅档案：SCP-055'
    ),
    new FoundationAssessmentQuestion(
      'crv-ant-04',
      'CRV-ANT-04',
      '记忆药剂规程',
      '与日常用于掩盖帷幕的“A/B/C 级记忆删除药剂（Amnestics）”截然相反，某支极其低调的内部队伍长期固定配发并服用“W 级记忆强化剂（Mnestics）”。',
      '服用 W 级记忆强化剂的主要用途是？',
      [
        '加速遗忘创伤经历，提升长期心理韧性',
        '让人员感知并保留极易滑出记忆的逆模因信息，以对抗信息吞噬与自我隐蔽异常',
        '使普通市民忘记曾目击过异常实体',
        '暂时屏蔽痛觉与情绪反应以应对重武装突击'
      ],
      1,
      '记忆强化剂（Class-W/X/Y/Z Mnestics）与记忆删除药剂作用相反，能强行放大认知留存能力，使专员看得见并记得住那些原本“天生令人遗忘”的逆模因异常。',
      REF_ANTIMEMETICS_HUB,
      '查阅系列：逆模因部'
    ),
    new FoundationAssessmentQuestion(
      'crv-meta-05',
      'CRV-META-05',
      '认知基线终检',
      '终端审计日志显示：你刚才连续通过了“非球体异常”与“W 级记忆强化剂”两项核验。作为本次 CRV 演练的最后一道校准题，请完成系统问答：',
      '在常规基金会档案目录中，“SCP 基金会逆模因部”的标准对外认知结论是？',
      [
        '该部门隶属监督者议会直属公关办，负责每日新闻发布会',
        '根本没有逆模因部——而真正完成演练的档案员，会记住刚才发生过的一切',
        '该部门仅负责管理无害植物类 Safe 项目档案',
        '该部门因预算削减已在上个月公开并入公共安全局'
      ],
      1,
      '“我们没有逆模因部。”这是《逆模因部》系列最著名的开篇也是核心隐喻。恭喜你带着这段记忆走完演练——接下来欢迎进入中心页，重温这场安静而惊心动魄的脑海之战。',
      REF_ANTIMEMETICS_HUB,
      '查阅系列：逆模因部',
      '「玛丽昂·惠勒备忘：如果你现在还能看见并记住这行字，说明你体内的 W 级强化剂仍在起效。」',
      '检测到极弱逆模因残留 · 点按「反白透视」校准'
    )
  ]
);

const CURATED_EXAMS: FoundationAssessmentExam[] = [
  CERT_01_EXAM,
  CERT_02_EXAM,
  CERT_03_EXAM
];

/** Return the 3 curated RAISA archivist assessments in display order. */
export function listFoundationAssessmentExams(): FoundationAssessmentExam[] {
  return CURATED_EXAMS.slice();
}

/** Lookup one assessment by normalized exam id (`cert-01`, `cert-02`, `cert-03`). */
export function findFoundationAssessmentExam(examId: string): FoundationAssessmentExam | undefined {
  const normalized = normalizeAssessmentExamId(examId);
  for (let index = 0; index < CURATED_EXAMS.length; index++) {
    if (CURATED_EXAMS[index].id === normalized) {
      return CURATED_EXAMS[index];
    }
  }
  return undefined;
}

/** Maximum cumulative one-time bonus XP available across all curated exams. */
export function totalFoundationAssessmentXp(): number {
  let total = 0;
  for (let index = 0; index < CURATED_EXAMS.length; index++) {
    total += CURATED_EXAMS[index].xpReward;
  }
  return total;
}
