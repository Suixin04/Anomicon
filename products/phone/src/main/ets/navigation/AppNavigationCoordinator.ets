/**
 * Product-level navigation gateway. Feature Views emit intents/callbacks;
 * only this phone composition boundary touches NavPathStack.
 */
import { promptAction } from '@kit.ArkUI';
import { isReduceMotionEnabled, notifyNavigationStackChanged } from 'anomiconbasic';

export class AppNavigationCoordinator {
  private static readonly pending: Set<string> = new Set<string>();
  // A navigation stack is owned by its page tree; do not retain destroyed
  // stacks merely because they once received a navigation request.
  private static readonly stackIds: WeakMap<NavPathStack, number> =
    new WeakMap<NavPathStack, number>();
  private static nextStackId: number = 1;

  static async push(
    stack: NavPathStack | undefined,
    name: string,
    param?: Object
  ): Promise<boolean> {
    if (stack === undefined) {
      AppNavigationCoordinator.notifyFailure('push');
      return false;
    }
    const key = AppNavigationCoordinator.operationKey('push', stack, name, param);
    if (AppNavigationCoordinator.pending.has(key)) {
      AppNavigationCoordinator.notifyFailure('push');
      return false;
    }
    AppNavigationCoordinator.pending.add(key);
    try {
      await stack.pushDestination({ name: name, param: param }, true);
      notifyNavigationStackChanged();
      return true;
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      console.error(
        `Navigate to '${name}' failed. Code: ${businessError.code}, message: ${businessError.message}`
      );
      AppNavigationCoordinator.notifyFailure('push');
      return false;
    } finally {
      AppNavigationCoordinator.pending.delete(key);
    }
  }

  static async replace(
    stack: NavPathStack | undefined,
    name: string,
    param?: Object
  ): Promise<boolean> {
    if (stack === undefined) {
      AppNavigationCoordinator.notifyFailure('replace');
      return false;
    }
    const key = AppNavigationCoordinator.operationKey('replace', stack, name, param);
    if (AppNavigationCoordinator.pending.has(key)) {
      AppNavigationCoordinator.notifyFailure('replace');
      return false;
    }
    AppNavigationCoordinator.pending.add(key);
    try {
      await stack.replaceDestination({ name: name, param: param }, { animated: true });
      return true;
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      console.error(
        `Replace with '${name}' failed. Code: ${businessError.code}, message: ${businessError.message}`
      );
      AppNavigationCoordinator.notifyFailure('replace');
      return false;
    } finally {
      AppNavigationCoordinator.pending.delete(key);
    }
  }

  /**
   * Open a top-level destination from the root tab master pane.
   *
   * When Split mode is already showing a detail stack, pop back to the root
   * detail entry without collapsing the stack to zero and replace it in place.
   */
  static async openFromMaster(
    stack: NavPathStack | undefined,
    name: string,
    param: Object | undefined,
    splitActive: boolean
  ): Promise<boolean> {
    if (stack === undefined) {
      AppNavigationCoordinator.notifyFailure('push');
      return false;
    }
    if (!splitActive || stack.size() === 0) {
      return AppNavigationCoordinator.push(stack, name, param);
    }
    const paths = stack.getPathStack();
    const top = paths.length > 0 ? paths[paths.length - 1] : undefined;
    const targetParamJson = param === undefined ? '' : JSON.stringify(param);
    const topParamJson = top?.param === undefined ? '' : JSON.stringify(top.param);
    if (paths.length === 1 && top !== undefined && top.name === name && topParamJson === targetParamJson) {
      return true;
    }
    const key = AppNavigationCoordinator.operationKey('master', stack, name, param);
    if (AppNavigationCoordinator.pending.has(key)) {
      return false;
    }
    AppNavigationCoordinator.pending.add(key);
    try {
      if (paths.length > 1) {
        stack.popToIndex(0, false);
      }
      await stack.replaceDestination({ name: name, param: param }, { animated: !isReduceMotionEnabled() });
      notifyNavigationStackChanged();
      return true;
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      console.error(
        `Open from master '${name}' failed. Code: ${businessError.code}, message: ${businessError.message}`
      );
      AppNavigationCoordinator.notifyFailure('replace');
      return false;
    } finally {
      AppNavigationCoordinator.pending.delete(key);
    }
  }

  /** Include the destination stack and payload so independent routes do not block each other. */
  private static operationKey(
    operation: string,
    stack: NavPathStack,
    name: string,
    param?: Object
  ): string {
    const payload = param === undefined ? '' : JSON.stringify(param);
    return `${operation}:${AppNavigationCoordinator.stackId(stack)}:${name}:${payload}`;
  }

  private static stackId(stack: NavPathStack): number {
    const existing = AppNavigationCoordinator.stackIds.get(stack);
    if (existing !== undefined) {
      return existing;
    }
    const assigned = AppNavigationCoordinator.nextStackId++;
    AppNavigationCoordinator.stackIds.set(stack, assigned);
    return assigned;
  }

  /** Keep navigation failures visible even when the originating View ignores the Promise. */
  private static notifyFailure(operation: string): void {
    const message = operation === 'replace' ?
      '无法打开内容，请稍后重试' : '页面打开失败，请稍后重试';
    promptAction.openToast({ message: message }).catch((error: BusinessError): void => {
      console.error(`Navigation failure toast failed. Code: ${error.code}, message: ${error.message}`);
    });
  }
}
