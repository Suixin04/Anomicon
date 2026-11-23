import { taskpool } from '@kit.ArkTS';
import type { ExplorePayload, ExploreSource } from '../domain/ExploreContracts';
import { ExploreHtmlParser } from './ExploreHtmlParser';

const OFFLOAD_MIN_HTML_LENGTH: number = 4096;

@Concurrent
function parseExploreHtmlTask(source: string, html: string): string {
  return JSON.stringify(ExploreHtmlParser.parse(source as ExploreSource, html));
}

/**
 * Parse Explore index HTML off the main thread via TaskPool for substantial
 * responses, while keeping a synchronous fallback for small payloads and
 * restricted unit-test runners.
 */
export async function parseExploreHtmlOffThread(
  source: ExploreSource,
  html: string
): Promise<ExplorePayload> {
  if (html.length < OFFLOAD_MIN_HTML_LENGTH) {
    return ExploreHtmlParser.parse(source, html);
  }
  try {
    const task = new taskpool.GenericsTask<[string, string], string>(
      parseExploreHtmlTask,
      source as string,
      html
    );
    const json = await taskpool.execute<[string, string], string>(task, taskpool.Priority.HIGH);
    return JSON.parse(json) as ExplorePayload;
  } catch (_error) {
    return ExploreHtmlParser.parse(source, html);
  }
}
