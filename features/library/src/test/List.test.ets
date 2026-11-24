import librarySnapshotTest from './LibrarySnapshot.test';
import readingHistoryStateTest from './ReadingHistoryState.test';
import storySeriesTest from './StorySeries.test';
import foundationAssessmentTest from './FoundationAssessment.test';
import raisaFeedbackTest from './RaisaFeedback.test';

/** Local Hypium entry point for the Library HAR. */
export default function testsuite(): void {
  librarySnapshotTest();
  readingHistoryStateTest();
  storySeriesTest();
  foundationAssessmentTest();
  raisaFeedbackTest();
}
