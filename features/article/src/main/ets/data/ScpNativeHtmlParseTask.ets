import { taskpool } from '@kit.ArkTS';
import { ScpNativeHtmlParser } from './ScpNativeHtmlParser';

// Parsing a long article can involve a few thousand nodes. Keep the tokenizer
// off the UI thread, just like the catalog parser, while retaining a plain JSON
// boundary between TaskPool and the Article mapper.
@Concurrent
function parseNativeArticleHtmlTask(html: string): string {
  return JSON.stringify(ScpNativeHtmlParser.parse(html));
}

export async function parseNativeArticleHtml(html: string): Promise<string> {
  const task = new taskpool.GenericsTask<[string], string>(parseNativeArticleHtmlTask, html);
  return taskpool.execute<[string], string>(task, taskpool.Priority.HIGH);
}
