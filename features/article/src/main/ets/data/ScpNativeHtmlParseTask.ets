import { taskpool } from '@kit.ArkTS';
import { ScpNativeHtmlParser } from './ScpNativeHtmlParser';

const OFFLOAD_MIN_HTML_LENGTH: number = 4096;

// Parsing a long article can involve a few thousand nodes. Keep the tokenizer
// off the UI thread, just like the catalog parser, while retaining a plain JSON
// boundary between TaskPool and the Article mapper.
@Concurrent
function parseNativeArticleHtmlTask(html: string): string {
  return JSON.stringify(ScpNativeHtmlParser.parse(html));
}

export async function parseNativeArticleHtml(html: string): Promise<string> {
  if (html.length < OFFLOAD_MIN_HTML_LENGTH) {
    return JSON.stringify(ScpNativeHtmlParser.parse(html));
  }
  try {
    const task = new taskpool.GenericsTask<[string], string>(parseNativeArticleHtmlTask, html);
    return await taskpool.execute<[string], string>(task, taskpool.Priority.HIGH);
  } catch (_error) {
    return JSON.stringify(ScpNativeHtmlParser.parse(html));
  }
}
