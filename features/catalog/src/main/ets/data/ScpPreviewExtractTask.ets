import { taskpool } from '@kit.ArkTS';
import {
  ScpPreviewExtractionPayload,
  ScpPreviewHtmlExtractor
} from './ScpPreviewHtmlExtractor';

const OFFLOAD_MIN_HTML_LENGTH: number = 4096;

@Concurrent
function extractPreviewHtmlTask(html: string): string {
  return JSON.stringify(ScpPreviewHtmlExtractor.extractPreview(html));
}

@Concurrent
function extractPreviewDescriptionTask(html: string): string {
  return ScpPreviewHtmlExtractor.extractDescription(html);
}

/**
 * Offload preview image/description HTML regex scans to TaskPool for large
 * pages while falling back synchronously on small payloads or test runners.
 */
export async function extractPreviewOffThread(
  html: string,
  highPriority: boolean
): Promise<ScpPreviewExtractionPayload> {
  if (html.length < OFFLOAD_MIN_HTML_LENGTH) {
    return ScpPreviewHtmlExtractor.extractPreview(html);
  }
  try {
    const task = new taskpool.GenericsTask<[string], string>(extractPreviewHtmlTask, html);
    const json = await taskpool.execute<[string], string>(
      task,
      highPriority ? taskpool.Priority.HIGH : taskpool.Priority.MEDIUM
    );
    return JSON.parse(json) as ScpPreviewExtractionPayload;
  } catch (_error) {
    return ScpPreviewHtmlExtractor.extractPreview(html);
  }
}

export async function extractPreviewDescriptionOffThread(
  html: string,
  highPriority: boolean
): Promise<string> {
  if (html.length < OFFLOAD_MIN_HTML_LENGTH) {
    return ScpPreviewHtmlExtractor.extractDescription(html);
  }
  try {
    const task = new taskpool.GenericsTask<[string], string>(
      extractPreviewDescriptionTask,
      html
    );
    return await taskpool.execute<[string], string>(
      task,
      highPriority ? taskpool.Priority.HIGH : taskpool.Priority.MEDIUM
    );
  } catch (_error) {
    return ScpPreviewHtmlExtractor.extractDescription(html);
  }
}
