import { describe, expect, it } from '@ohos/hypium';
import {
  findFoundationAssessmentExam,
  listFoundationAssessmentExams,
  totalFoundationAssessmentXp
} from '../main/ets/domain/FoundationAssessmentCatalog';
import {
  FoundationAssessmentRecord,
  FoundationAssessmentRepository
} from '../main/ets/domain/FoundationAssessmentContracts';
import { deriveResearchProgress } from '../main/ets/domain/ResearchProgress';
import { FoundationAssessmentViewModel } from '../main/ets/presentation/viewmodel/FoundationAssessmentViewModel';

class InMemoryAssessmentRepository implements FoundationAssessmentRepository {
  private readonly records: Map<string, FoundationAssessmentRecord> = new Map();

  listRecords(): Promise<FoundationAssessmentRecord[]> {
    const result: FoundationAssessmentRecord[] = [];
    this.records.forEach((value: FoundationAssessmentRecord): void => {
      result.push(value);
    });
    return Promise.resolve(result);
  }

  saveRecord(record: FoundationAssessmentRecord): Promise<FoundationAssessmentRecord> {
    this.records.set(record.examId, record);
    return Promise.resolve(record);
  }

  totalAwardedXp(): Promise<number> {
    let total = 0;
    this.records.forEach((value: FoundationAssessmentRecord): void => {
      total += value.xpAwarded;
    });
    return Promise.resolve(total);
  }
}

export default function foundationAssessmentTest(): void {
  describe('FoundationAssessment', () => {
    it('exposes 3 curated 5-question exams including interactive hidden clues in CERT-03', 0, () => {
      const exams = listFoundationAssessmentExams();
      expect(exams.length).assertEqual(3);
      expect(totalFoundationAssessmentXp()).assertEqual(60);

      for (let i = 0; i < exams.length; i++) {
        const exam = exams[i];
        expect(exam.questions.length).assertEqual(5);
        expect(exam.passScore).assertEqual(4);
        for (let q = 0; q < exam.questions.length; q++) {
          const question = exam.questions[q];
          expect(question.options.length).assertEqual(4);
          expect(question.correctIndex >= 0 && question.correctIndex < 4).assertTrue();
          expect(question.reference.id.length > 0).assertTrue();
        }
      }

      const cert03 = findFoundationAssessmentExam('CERT-03');
      expect(cert03 !== undefined).assertTrue();
      let hiddenCount = 0;
      for (let q = 0; q < cert03!.questions.length; q++) {
        if (cert03!.questions[q].hasHiddenClue()) {
          hiddenCount++;
        }
      }
      expect(hiddenCount).assertEqual(2);
    });

    it('awards one-time XP only on first pass and preserves certification on failed retry', 0, async () => {
      const repo = new InMemoryAssessmentRepository();
      let nowTick = 1000;
      let bonusReloads = 0;
      const viewModel = new FoundationAssessmentViewModel(
        repo,
        async (): Promise<void> => {
          bonusReloads++;
        },
        (): number => {
          nowTick += 100;
          return nowTick;
        }
      );

      await viewModel.initialize();
      expect(viewModel.passedCount()).assertEqual(0);
      expect(viewModel.totalCount()).assertEqual(3);
      expect(viewModel.earnedXp()).assertEqual(0);
      expect(viewModel.maxXp()).assertEqual(60);

      // Failed first attempt awards 0 XP and does not light seal.
      const failResult = await viewModel.submitAttempt('cert-03', 3);
      expect(failResult.passed).assertFalse();
      expect(failResult.newlyPassed).assertFalse();
      expect(failResult.awardedXpNow).assertEqual(0);
      expect(failResult.record.attempts).assertEqual(1);
      expect(failResult.record.bestScore).assertEqual(3);
      expect(bonusReloads).assertEqual(0);
      expect(viewModel.passedCount()).assertEqual(0);

      // Passing attempt lights seal and awards +25 XP once.
      const passResult = await viewModel.submitAttempt('cert-03', 4);
      expect(passResult.passed).assertTrue();
      expect(passResult.newlyPassed).assertTrue();
      expect(passResult.awardedXpNow).assertEqual(25);
      expect(passResult.record.passed).assertTrue();
      expect(passResult.record.bestScore).assertEqual(4);
      expect(passResult.record.xpAwarded).assertEqual(25);
      expect(bonusReloads).assertEqual(1);
      expect(viewModel.passedCount()).assertEqual(1);
      expect(viewModel.earnedXp()).assertEqual(25);

      // Repeat pass improves bestScore without granting duplicate XP.
      const repeatPass = await viewModel.submitAttempt('cert-03', 5);
      expect(repeatPass.passed).assertTrue();
      expect(repeatPass.newlyPassed).assertFalse();
      expect(repeatPass.awardedXpNow).assertEqual(0);
      expect(repeatPass.record.bestScore).assertEqual(5);
      expect(repeatPass.record.attempts).assertEqual(3);
      expect(repeatPass.record.xpAwarded).assertEqual(25);
      expect(bonusReloads).assertEqual(1);

      // Subsequent lower score never revokes earned seal or awarded XP.
      const lowRetry = await viewModel.submitAttempt('cert-03', 1);
      expect(lowRetry.passed).assertFalse();
      expect(lowRetry.awardedXpNow).assertEqual(0);
      expect(lowRetry.record.passed).assertTrue();
      expect(lowRetry.record.bestScore).assertEqual(5);
      expect(lowRetry.record.xpAwarded).assertEqual(25);
      expect(viewModel.earnedXp()).assertEqual(25);

      const seals = viewModel.sealSummaries();
      expect(seals.length).assertEqual(3);
      expect(seals[0].passed).assertFalse();
      expect(seals[1].passed).assertFalse();
      expect(seals[2].passed).assertTrue();
      viewModel.dispose();
    });

    it('returns the first-pass receipt before refresh settles and retries only the profile read', 0, async () => {
      const repo = new InMemoryAssessmentRepository();
      let reloads = 0;
      let failRead: (reason: Error) => void = (_reason: Error): void => {};
      const firstRead = new Promise<void>((_resolve: () => void, reject: (reason: Error) => void): void => {
        failRead = reject;
      });
      const vm = new FoundationAssessmentViewModel(repo, (): Promise<void> => {
        reloads++;
        return reloads === 1 ? firstRead : Promise.resolve();
      });

      const receipt = await vm.submitAttempt('cert-01', 5);
      expect(receipt.newlyPassed).assertTrue();
      expect(receipt.awardedXpNow).assertEqual(15);
      expect(receipt.record.attempts).assertEqual(1);
      failRead(new Error('画像读取失败'));
      await Promise.resolve();
      expect(vm.profileRefreshError).assertEqual('画像读取失败');
      await vm.refreshResearchProfile();
      expect(vm.profileRefreshError).assertEqual('');
      expect(reloads).assertEqual(2);
      const stored = (await repo.listRecords())[0];
      expect(stored.attempts).assertEqual(1);
      expect(stored.xpAwarded).assertEqual(15);
      expect(stored.passed).assertTrue();
      vm.dispose();
    });

    it('adds earned assessment bonus XP into derived ResearchProgress and advances rank', 0, () => {
      const progress = deriveResearchProgress([], 0, 0, 25);
      expect(progress.bonusExperience).assertEqual(25);
      expect(progress.experience).assertEqual(25);
      expect(progress.level >= 2).assertTrue();
    });
  });
}
