import { http } from '@kit.NetworkKit';
import { SCP } from './types';

// 接收后端 JSON 的原始类型，避免使用 any/unknown
interface RawScp {
  id?: string;
  number?: string;
  name?: string;
  title?: string;
  class?: string;
  objectClass?: string;
  series?: number;
  images?: string[];
  description?: string;
  containment?: string;
  containmentProcedures?: string;
  addendum?: string;
  interviews?: string;
  dateAdded?: string;
  tags?: string[];
  error?: string; // 添加可选的错误属性
}

// HTTP响应数据类型接口
interface HttpResponseData {
  results?: RawScp[];
  data?: RawScp[];
  error?: string;
}

/**
 * SCP API 网络层服务
 * 与本地运行的 scp-api 服务器集成
 */
export class ScpApi {
  private static instance: ScpApi;
  // private readonly baseUrl = 'http://10.0.2.2:3000';
  // private readonly baseUrl = 'http://192.168.1.8:3000';
  // private readonly baseUrl = '0.tcp.jp.ngrok.io:19815';
  private readonly baseUrl = 'http://192.168.3.103:3000';
  private httpRequest: http.HttpRequest;

  private constructor() {
    this.httpRequest = http.createHttp();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): ScpApi {
    if (!ScpApi.instance) {
      ScpApi.instance = new ScpApi();
    }
    return ScpApi.instance;
  }

  /**
   * 根据编号获取SCP详情
   * @param number SCP编号（如 "049"）
   * @returns Promise<SCP | null>
   */
  async getScpDetail(number: string): Promise<SCP | null> {
    try {
      const url = `${this.baseUrl}/scp/${number}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (response.responseCode === 200) {
        const resultString: string = response.result.toString();
        const responseData: RawScp = JSON.parse(resultString);
        // /scp/:id 直接返回条目对象，无 success 包装
        if (responseData && typeof responseData === 'object' && !responseData.error) {
          return this.mapToSCP(responseData);
        }
      }
      console.error('SCP详情请求失败:', response.responseCode, response.result);
      return null;
    } catch (error) {
      console.error('获取SCP详情失败:', error);
      return null;
    }
  }

  /**
   * 获取SCP列表
   * @param limit 限制返回数量（默认20）
   * @param page 页码（默认1）
   * @param series 系列编号（可选，1-9）
   * @returns Promise<SCP[]>
   */
  async getScpList(limit: number = 20, page: number = 1, series?: number): Promise<SCP[]> {
    try {
      const offset = (page - 1) * limit;
      let url = `${this.baseUrl}/scp?limit=${limit}&offset=${offset}`;
      
      // 如果指定了系列，添加系列过滤参数
      if (series && series > 0) {
        url += `&series=${series}`;
      }
      
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (response.responseCode === 200) {
        const resultString: string = response.result.toString();
        const responseData: HttpResponseData = JSON.parse(resultString);
        if (responseData.data && Array.isArray(responseData.data)) {
          // 直接映射列表数据，不再对每个条目单独请求详情
          return responseData.data.map(this.mapToSCP);
        }
      }
      console.error('SCP列表请求失败:', response.responseCode, response.result);
      return [];
    } catch (error) {
      console.error('获取SCP列表失败:', error);
      return [];
    }
  }

  /**
   * 搜索SCP条目
   * @param keyword 搜索关键词
   * @param limit 限制返回数量（默认50）
   * @returns Promise<SCP[]>
   */
  async searchScp(keyword: string, limit: number = 50, series?: number): Promise<SCP[]> {
    try {
      let url = `${this.baseUrl}/search?q=${encodeURIComponent(keyword)}&limit=${limit}`;
      if (series && series > 0) {
        url += `&series=${series}`;
      }
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (response.responseCode === 200) {
        const responseData: HttpResponseData = JSON.parse(response.result as string);
        if (responseData.results && Array.isArray(responseData.results)) {
          // 直接映射搜索结果，不再对每个条目单独请求详情
          const mappedResults = responseData.results.map(this.mapToSCP);
          return mappedResults;
        }
      }
      console.error('SCP搜索请求失败:', response.responseCode, response.result);
      return [];
    } catch (error) {
      console.error('搜索SCP失败:', error);
      return [];
    }
  }

  /**
   * 将API返回的数据映射为本地SCP接口
   * @param apiData API返回的数据
   * @returns SCP
   */
  private mapToSCP(apiData: RawScp): SCP {
    // 处理图片：如果images数组有值，取第一张，否则使用undefined
    const image = apiData.images && apiData.images.length > 0 ? apiData.images[0] : undefined;

    // 生成唯一ID
    const id = apiData.id || `scp-${apiData.number || 'unknown'}`;
    const scpNumber = apiData.id || (apiData.number ? `SCP-${apiData.number}` : 'SCP-???');

    // 定义已知的固定字段，用于过滤动态字段
    const knownFields = new Set([
      'id', 'number', 'name', 'title', 'class', 'objectClass', 'series', 
      'images', 'description', 'containment', 'containmentProcedures', 
      'addendum', 'interviews', 'dateAdded', 'tags', 'error'
    ]);

    // 提取动态字段
    const dynamicFields: Record<string, string> = {};
    const entries: [string, string | number | string[] | undefined][] = Object.entries(apiData);
    for (let i = 0; i < entries.length; i++) {
      const key: string = entries[i][0];
      const value: string | number | string[] | undefined = entries[i][1];
      if (!knownFields.has(key) && typeof value === 'string' && value.trim() !== '') {
        dynamicFields[key] = value;
      }
    }

    return {
      id: id,
      number: scpNumber,
      title: apiData.name || apiData.title || '未知项目',
      objectClass: apiData.class || apiData.objectClass || 'Unknown',
      image: image,
      description: apiData.description || '',
      containmentProcedures: apiData.containment || apiData.containmentProcedures || '',
      addendum: apiData.addendum || undefined,
      interviews: apiData.interviews || undefined,
      series: apiData.series ?? 1, // 直接使用API返回的series，若不存在则默认为1
      dateAdded: apiData.dateAdded || new Date().toISOString().split('T')[0],
      tags: Array.isArray(apiData.tags) ? apiData.tags : [],
      isFavorited: false, // 默认未收藏
      dynamicFields: Object.keys(dynamicFields).length > 0 ? dynamicFields : undefined
    };
  }

  /**
   * 检查API服务器健康状态
   * @returns Promise<boolean>
   */
  async checkHealth(): Promise<boolean> {
    try {
      const response = await this.httpRequest.request(`${this.baseUrl}/health`, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 5000,
        readTimeout: 5000
      });
      return response.responseCode === 200;
    } catch (error) {
      console.error('API健康检查失败:', error);
      return false;
    }
  }

  /**
   * 销毁HTTP请求资源
   */
  destroy(): void {
    this.httpRequest.destroy();
  }
}

// 导出单例实例
export const scpApi = ScpApi.getInstance();