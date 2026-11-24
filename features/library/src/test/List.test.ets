import librarySnapshotTest from './LibrarySnapshot.test';
import readingHistoryStateTest from './ReadingHistoryState.test';

/** Local Hypium entry point for the Library HAR. */
export default function testsuite(): void {
  librarySnapshotTest();
  readingHistoryStateTest();
}
