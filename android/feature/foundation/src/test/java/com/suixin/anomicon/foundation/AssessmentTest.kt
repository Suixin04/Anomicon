package com.suixin.anomicon.foundation

import org.junit.Assert.*
import org.junit.Test

class AssessmentTest {
    @Test fun originalExamsAwardSixtyXpAndPassAtFour() {
        assertEquals(listOf("cert-01", "cert-02", "cert-03"), exams.map { it.id })
        assertEquals(60, exams.sumOf { it.xp })
        exams.forEach { exam ->
            val answers = exam.questions.map { it.correct }.toMutableList()
            assertEquals(5, exam.score(answers))
            answers[0] = (answers[0] + 1) % 4
            assertEquals(exam.cutoff, exam.score(answers))
            answers[1] = (answers[1] + 1) % 4
            assertTrue(exam.score(answers) < exam.cutoff)
        }
        assertEquals(9, manuals.map { it.slug }.distinct().size)
        assertEquals(2, exams.last().questions.count { it.secret.isNotEmpty() })
    }
}
