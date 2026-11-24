import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';

const MAX_TEXT_CACHE_BYTES: number = 64 * 1024 * 1024;
const TEXT_CACHE_EXTENSION: string = '.utf8';
const TEXT_CACHE_READ_CHUNK_BYTES: number = 256 * 1024;

/**
 * common/storage 提供的 cacheDir UTF-8 大文本原子存储。
 *
 * 正式文件名同时携带随机 UUID 与字节数；写入先落同目录临时文件并 fsync，
 * 再通过 rename 发布。读取只认可本实例目录中的正式文件，且严格校验长度与
 * UTF-8 编码，避免损坏缓存被当作有效正文返回。
 */
export class AtomicTextCacheFileStore {
  private readonly directory: string;
  private readonly encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('utf-8', {
    fatal: true,
    ignoreBOM: false
  });
  private initialization: Promise<void> | undefined = undefined;

  constructor(cacheDir: string, subdirectory: string) {
    this.directory = `${cacheDir}/${subdirectory}`;
  }

  initialize(): Promise<void> {
    if (this.initialization !== undefined) {
      return this.initialization;
    }
    const task = this.ensureDirectory();
    this.initialization = task;
    task.catch((): void => {
      if (this.initialization === task) {
        this.initialization = undefined;
      }
    });
    return task;
  }

  async write(text: string): Promise<string> {
    if (text.length === 0) {
      throw new Error('缓存文本不能为空');
    }
    await this.initialize();
    // cacheDir 可能在进程存活期间被系统回收，每次新写入前再做一次轻量确认。
    await this.ensureDirectory();
    const bytes = this.encoder.encodeInto(text);
    if (bytes.byteLength <= 0 || bytes.byteLength > MAX_TEXT_CACHE_BYTES) {
      throw new Error(`缓存文本大小无效：${bytes.byteLength}`);
    }

    const fileId = util.generateRandomUUID(true).toLowerCase();
    const finalPath = `${this.directory}/${fileId}_${bytes.byteLength}${TEXT_CACHE_EXTENSION}`;
    const temporaryId = util.generateRandomUUID(true).toLowerCase();
    const temporaryPath = `${this.directory}/.${fileId}_${temporaryId}.tmp`;
    let file: fs.File | undefined = undefined;
    try {
      file = await fs.open(
        temporaryPath,
        fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC | fs.OpenMode.NOFOLLOW
      );
      const written = await fs.write(file.fd, bytes.buffer as ArrayBuffer);
      if (written !== bytes.byteLength) {
        throw new Error(`缓存文本写入不完整：${written}/${bytes.byteLength}`);
      }
      await fs.fsync(file.fd);
      await fs.close(file);
      file = undefined;
      // 临时文件与正式文件位于同一目录，不会向读取方暴露部分写入内容。
      await fs.rename(temporaryPath, finalPath);
      return finalPath;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知文件错误';
      throw new Error(`缓存文本原子写入失败：${message}`);
    } finally {
      await this.closeQuietly(file);
      // rename 成功后临时路径已不存在；失败路径也必须清除残留临时文件。
      await this.removeIfExistsQuietly(temporaryPath);
    }
  }

  /** 文件缺失、长度异常、类型异常或非法 UTF-8 都是普通 cache miss。 */
  async read(path: string): Promise<string | undefined> {
    const expectedSize = this.expectedSize(path);
    if (expectedSize <= 0 || expectedSize > MAX_TEXT_CACHE_BYTES) {
      return undefined;
    }
    let file: fs.File | undefined = undefined;
    let damaged: boolean = false;
    try {
      if (!(await fs.access(path))) {
        return undefined;
      }
      const pathStat = await fs.stat(path);
      if (!pathStat.isFile() || pathStat.size !== expectedSize) {
        damaged = true;
        return undefined;
      }
      file = await fs.open(path, fs.OpenMode.READ_ONLY | fs.OpenMode.NOFOLLOW);
      const bytes = await this.readExactly(file.fd, expectedSize);
      const fileStat = await fs.stat(file.fd);
      if (!fileStat.isFile() || fileStat.size !== expectedSize) {
        damaged = true;
        return undefined;
      }
      let text: string;
      try {
        text = this.decoder.decodeToString(bytes, { stream: false });
      } catch (error) {
        // Invalid UTF-8 is evidence that the cache is damaged.  I/O errors
        // below are deliberately handled separately: a transient permission
        // or filesystem failure must not destroy a potentially recoverable
        // cache entry.
        damaged = true;
        return undefined;
      }
      if (text.length === 0) {
        damaged = true;
        return undefined;
      }
      return text;
    } catch (error) {
      // Keep the file for transient read/open/stat failures.  The next read
      // can retry after the filesystem or permission state recovers.
      return undefined;
    } finally {
      await this.closeQuietly(file);
      if (damaged) {
        await this.removeIfExistsQuietly(path);
      }
    }
  }

  /** 只删除本实例目录中由 UUID 规则生成的正式缓存文件。 */
  async remove(path: string): Promise<void> {
    if (this.expectedSize(path) <= 0) {
      return;
    }
    try {
      if (await fs.access(path)) {
        await fs.unlink(path);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知文件错误';
      throw new Error(`删除缓存文本失败：${message}`);
    }
  }

  /** 清空本实例目录中已提交的正式文本缓存及残留临时文件。 */
  async clearAll(): Promise<void> {
    try {
      if (!(await fs.access(this.directory))) {
        return;
      }
      const names = await fs.listFile(this.directory);
      for (let index = 0; index < names.length; index++) {
        const name = names[index];
        const fullPath = `${this.directory}/${name}`;
        if (this.expectedSize(fullPath) > 0 || name.endsWith('.tmp')) {
          await this.removeIfExistsQuietly(fullPath);
        }
      }
    } catch (_error) {
      // 目录清理尽可能完成，单次列举异常不阻断上层重置。
    }
  }

  private async ensureDirectory(): Promise<void> {
    try {
      if (!(await fs.access(this.directory))) {
        await fs.mkdir(this.directory, true);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知文件错误';
      throw new Error(`创建缓存文本目录失败：${message}`);
    }
  }

  private async readExactly(fd: number, byteLength: number): Promise<Uint8Array> {
    try {
      const output = new Uint8Array(byteLength);
      let offset: number = 0;
      while (offset < byteLength) {
        const chunkLength = Math.min(TEXT_CACHE_READ_CHUNK_BYTES, byteLength - offset);
        const chunk = new ArrayBuffer(chunkLength);
        const read = await fs.read(fd, chunk);
        if (read <= 0 || read > chunkLength) {
          throw new Error(`缓存文本读取不完整：${offset}/${byteLength}`);
        }
        output.set(new Uint8Array(chunk, 0, read), offset);
        offset += read;
      }
      return output;
    } catch (error) {
      const message = error instanceof Error ? error.message : '未知文件错误';
      throw new Error(`读取缓存文本失败：${message}`);
    }
  }

  private expectedSize(path: string): number {
    const prefix = `${this.directory}/`;
    if (!path.startsWith(prefix)) {
      return -1;
    }
    const name = path.substring(prefix.length);
    const matched = /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})_([0-9]+)\.utf8$/.exec(name);
    if (matched === null) {
      return -1;
    }
    const size = Number(matched[2]);
    return Number.isSafeInteger(size) ? size : -1;
  }

  private async closeQuietly(file: fs.File | undefined): Promise<void> {
    if (file === undefined) {
      return;
    }
    try {
      await fs.close(file);
    } catch (error) {
      // finally 中的关闭失败不能覆盖原始读写错误。
    }
  }

  private async removeIfExistsQuietly(path: string): Promise<void> {
    try {
      if (await fs.access(path)) {
        await fs.unlink(path);
      }
    } catch (error) {
      // 缓存与临时文件清理均为尽力而为，不覆盖调用方真正的读写结果。
    }
  }
}
