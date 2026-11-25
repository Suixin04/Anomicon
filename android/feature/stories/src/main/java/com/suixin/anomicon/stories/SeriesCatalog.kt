package com.suixin.anomicon.stories

internal data class Tale(val slug: String, val title: String)
internal data class Group(val title: String, val mainline: Boolean, val entries: List<Tale>)
internal const val SERIES_ID = "antimemetics-division"
internal val groups = listOf(
    Group("核心背景读物", true, listOf(
        Tale("scp-055", "SCP-055"),
    )),
    Group("这里没有逆模因部", true, listOf(
        Tale("we-need-to-talk-about-fifty-five", "谈谈055"),
        Tale("introductory-antimemetics", "逆模因学入门"),
        Tale("unforgettable-that-s-what-you-are", "难忘的你"),
        Tale("case-colourless-green", "无色之绿事件"),
        Tale("your-last-first-day", "你最后一个第一天"),
    )),
    Group("幕间休息", true, listOf(
        Tale("scp-2256", "SCP-2256"),
    )),
    Group("五-五-五-五-五", true, listOf(
        Tale("scp-3125", "SCP-3125"),
        Tale("where-have-you-been-all-my-life", "我一生里，你在何处"),
        Tale("fresh-hell", "活地狱"),
        Tale("ojai", "奥哈伊"),
        Tale("immemorial", "忘念碑"),
        Tale("case-hate-red", "憎恨之红事件"),
        Tale("ara-orun", "Ará Orún"),
        Tale("unthreaded", "了无牵挂"),
        Tale("the-wild-light", "狂光"),
        Tale("blood-brain", "血/脑"),
        Tale("tombstone", "墓碑"),
        Tale("champions-of-nothing", "尾声：胜冠徒然"),
    )),
    Group("逝者所知", false, listOf(
        Tale("scp-2111", "SCP-2111"),
        Tale("in-the-trenches-with-the-dead", "与亡者共战"),
        Tale("a-thin-dangerous-line", "生死一息间"),
    )),
    Group("以供参阅", false, listOf(
        Tale("antimemetics-division-timeline", "逆模因部系列时间线"),
    )),
    Group("先驱创作", false, listOf(
        Tale("scp-033", "SCP-033"),
        Tale("revenants", "归来者"),
        Tale("scp-1425", "SCP-1425"),
        Tale("scp-2828", "SCP-2828"),
        Tale("scp-2358", "SCP-2358"),
    )),
    Group("进一步阅读", false, listOf(
        Tale("scp-scp-033", "SCP-SCP-033"),
        Tale("numbers-lie", "数字会说谎"),
        Tale("scp-3393", "SCP-3393"),
        Tale("scp-3211", "SCP-3211"),
        Tale("scp-4773", "SCP-4773"),
        Tale("note-your-name-is-nobody", "速记：你的名字是“Nobody”"),
    )),
    Group("中国分部原创的相关故事", false, listOf(
        Tale("memory-maze", "记忆迷宫"),
        Tale("tell-you-tales", "说个故事吧"),
        Tale("diary", "不，这不是你第一天上班。还有：记得写日记"),
        Tale("rainy-stars-with-the-thunderstorm", "霆霓飘霖，星陨如雨"),
        Tale("antimeme-guide", "简单易懂的逆模因识别指南（节选）"),
        Tale("antimemetic-speech", "ONXY的逆模因讲座：认识，假设与对抗"),
        Tale("who-is-the-knife-who-is-the-fish", "谁为刀俎，谁为鱼肉？"),
        Tale("black-hairs-black-eyes", "黑发，黑眸"),
        Tale("through-calamity", "跨越末日"),
        Tale("train", "失忆症"),
        Tale("going-downward-and-pasting-through-translation", "螺旋而下，迭代前行"),
        Tale("the-spirit-is-shining-among-us", "有黄金从裂缝中渗出"),
        Tale("wandering-ghost", "游魂"),
        Tale("arememnber", "也许你能铭记一切，但你仍不能战胜遗忘"),
        Tale("endro-reversi", "勇者与魔王"),
        Tale("for-forgotten-memories", "东方忘却碑 ～ For Forgotten Memories."),
        Tale("the-self-help-guide-of-antimemetics-division", "逆模因部自救指南"),
        Tale("therefore-the-red-flood-arose", "熄梦之网"),
        Tale("nimoyinburenzhenshicanhhh", "于逆模因囹圄之下"),
        Tale("anon-unknown-nobody", "无人知晓千早爱音"),
        Tale("scp-cn-3215", "SCP-CN-3215 - 虚构扩大器"),
        Tale("locked-room-mystery", "个人梦盒站点：「无隙困室」事件（23.1.17留档）"),
        Tale("unknown-and-rana", "乐奈救赎乌有之人"),
        Tale("the-wind-up-bird-chihaya-anon-i", "深红色的拧发条鸟"),
        Tale("gharfa-ruh", "如是点燃千早爱音"),
        Tale("welcome-to-vanguard-threshold-must-die", "惊天秘密！为什么你应该成为现实扭曲者或逆模因"),
    )),
)
internal val mainline = groups.filter { it.mainline }.flatMap { it.entries }
