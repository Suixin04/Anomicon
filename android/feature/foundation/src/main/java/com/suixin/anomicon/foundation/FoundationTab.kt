package com.suixin.anomicon.foundation

import com.suixin.anomicon.designsystem.*
import androidx.compose.ui.text.font.FontFamily
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.ui.res.painterResource
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.suixin.anomicon.core.data.NativeData
import kotlinx.coroutines.launch

@Composable
fun FoundationTab(onEntry: (String) -> Unit, onWorkOrder: () -> Unit) {
    val context = LocalContext.current
    val data = remember(context) { NativeData.open(context) }
    val results by data.assessmentResults.collectAsState(initial = emptyMap())
    var activeId by rememberSaveable { mutableStateOf<String?>(null) }
    val active = exams.find { it.id == activeId }
    ArchiveSecondaryPage(active != null)
    BackHandler(active != null) { activeId = null }
    if (active != null) {
        ExamScreen(active, results[active.id]?.passed == true, onEntry, { activeId = null }) { score -> data.saveAssessment(active.id, score, score >= active.cutoff) }
        return
    }
    ArchiveLargePage("基金会") {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Heading("档案资质考核")
            Caption("模拟 RAISA 编目工单与认知勘验，不阻断日常阅读，通过后签发工牌印章")
            val passed = exams.filter { results[it.id]?.passed == true }
            Panel {
                BadgeHeader("badge") {
                    Text("RAISA 终端核验 · 已签发 ${passed.size}/3 枚印章", fontWeight = FontWeight.Bold)
                    Caption("每科首次通过可获一次性阅历奖励 · 已累计 ${passed.sumOf { it.xp }} / 60 XP")
                }
            }
            exams.forEach { exam ->
                val record = results[exam.id]
                Panel(onClick = { activeId = exam.id }) {
                    val badge = when (exam.id) {
                        "cert-01" -> "lock"
                        "cert-02" -> "assignment"
                        else -> "visibility"
                    }
                    BadgeHeader(badge) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(exam.code, Modifier.background(MaterialTheme.colorScheme.primaryContainer, RoundedCornerShape(8.dp)).padding(horizontal = 6.dp), style = MaterialTheme.typography.labelSmall, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onPrimaryContainer)
                            Caption("建议 · ${exam.rank}" + if (exam.id == "cert-03") "  含透视勘验" else "")
                        }
                        Text(exam.title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    }
                    Caption(exam.subtitle)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(if (record?.passed == true) "已签章 · ${record.score}/5" else "首次通过 +${exam.xp} XP", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodySmall)
                            Caption("印章：${exam.seal}")
                        }
                        Button(onClick = { activeId = exam.id }) { Text(if (record?.passed == true) "再次演练" else "开始核验") }
                    }
                }
            }
            Panel(onClick = onWorkOrder) { Heading("RAISA 工单"); Caption("提交反馈及查看处理记录") }
            Heading("基金会手册")
            manuals.take(1).forEach { ManualCard(it, Modifier.fillMaxWidth(), onEntry) }
            manuals.drop(1).chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { row.forEach { ManualCard(it, Modifier.weight(1f), onEntry) } }
            }
            Spacer(Modifier.height(LocalArchiveBottomInset.current + 16.dp))
        }
    }
}

@Composable private fun BadgeHeader(icon: String, content: @Composable ColumnScope.() -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(42.dp).background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) {
            ArchiveGlyph(icon, Modifier.size(24.dp))
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp), content = content)
    }
}

@Composable private fun ManualCard(item: Manual, modifier: Modifier, open: (String) -> Unit) {
    Panel(modifier, onClick = { open(item.slug) }) { Caption(item.label); Text(item.title, fontWeight = FontWeight.Bold); Caption(item.subtitle) }
}
@Composable private fun Panel(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val body: @Composable ColumnScope.() -> Unit = {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp), content = content)
    }
    if (onClick == null) ArchiveCard(modifier.fillMaxWidth(), content = body)
    else ArchiveCard(onClick = onClick, modifier = modifier.fillMaxWidth(), content = body)
}
@Composable private fun Heading(text: String) = Text(text, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
@Composable private fun Caption(text: String) = Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)

@Composable private fun ExamScreen(exam: Exam, passedBefore: Boolean, open: (String) -> Unit, back: () -> Unit, save: suspend (Int) -> Unit) {
    var answers by rememberSaveable(exam.id) { mutableStateOf(intArrayOf()) }
    var index by rememberSaveable(exam.id) { mutableIntStateOf(0) }
    var reward by rememberSaveable(exam.id) { mutableIntStateOf(0) }
    var finished by rememberSaveable(exam.id) { mutableStateOf(false) }
    var revealed by rememberSaveable(index) { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val question = exam.questions[index]
    val scroll = key(index, finished) { rememberScrollState() }
    Column(Modifier.fillMaxSize()) {
        ArchiveDetailBar(exam.title, back)
        Column(Modifier.verticalScroll(scroll).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(exam.code, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.labelMedium)
        if (!finished && passedBefore) Caption("已持章复核")
        if (finished) {
            val score = exam.score(answers.toList())
            Heading(if (score >= exam.cutoff) "核验通过 · ${exam.seal}" else "待复核")
            Caption(if (reward > 0) "首次签发 ${exam.seal} · +$reward XP" else if (passedBefore) "已持有 ${exam.seal} · 本次未重复发放奖励" else "尚未签发印章")
            Text("得分 $score / ${exam.questions.size}"); Text(if (score >= exam.cutoff) exam.success else exam.failure)
            exam.questions.forEachIndexed { i, q ->
                Panel { Text("${i + 1} · ${if (answers[i] == q.correct) "正确" else "需复习"} · ${q.label}"); Caption(q.explanation); TextButton(onClick = { open(q.reference) }) { Text(q.link) } }
            }
            Button(onClick = back) { Text("返回基金会") }
        } else {
            Caption("第 ${index + 1} / ${exam.questions.size} 题 · ${question.code}")
            Panel { Heading(question.label); Text(question.case) }
            if (question.secret.isNotEmpty()) {
                TextButton(onClick = { revealed = !revealed }) { Text(if (revealed) "收起透视" else "反白透视") }; Caption(if (revealed) question.secret else question.hint)
            }
            Text(question.prompt, fontWeight = FontWeight.Bold)
            question.choices.forEachIndexed { i, choice ->
                OutlinedButton(enabled = answers.size == index, onClick = { answers = answers + i }, modifier = Modifier.fillMaxWidth()) {
                    ArchiveGlyph(if (answers.getOrNull(index) == i) "radio_button_checked" else "radio_button_unchecked", Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                    Text(choice, modifier = Modifier.weight(1f))
                }
            }
            if (answers.size > index) {
                Panel {
                    Heading(if (answers[index] == question.correct) "核验通过" else "规程偏差")
                    Text(question.explanation)
                    TextButton(onClick = { open(question.reference) }) { Text(question.link) }
                }
            }
            Button(enabled = answers.size > index && !saving, onClick = {
                if (index < exam.questions.lastIndex) index++ else {
                    saving = true
                    val score = exam.score(answers.toList())
                    val earned = if (score >= exam.cutoff && !passedBefore) exam.xp else 0
                    scope.launch { save(score); reward = earned; finished = true; saving = false }
                }
            }) { Text(if (index == exam.questions.lastIndex) "提交核验" else "下一题") }
        }
        Spacer(Modifier.height(88.dp))
    }
    }
}
