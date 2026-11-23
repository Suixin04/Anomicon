import externalUrlPolicyTest from './ExternalUrlPolicy.test';
import responsiveLayoutTest from './ResponsiveLayout.test';

/** Local Hypium entry point for the common HAR. */
export default function testsuite(): void {
  externalUrlPolicyTest();
  responsiveLayoutTest();
}
