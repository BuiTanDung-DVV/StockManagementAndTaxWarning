import https from 'https';

export interface TvplSearchResult {
  title: string;
  docNumber?: string;
  url: string;
  effectiveDate?: string;
  status?: string;
  summary?: string;
}

export class TvplSearchService {
  private static instance: TvplSearchService;

  private constructor() {}

  public static getInstance(): TvplSearchService {
    if (!TvplSearchService.instance) {
      TvplSearchService.instance = new TvplSearchService();
    }
    return TvplSearchService.instance;
  }

  /**
   * Tra cứu danh sách văn bản pháp luật mới nhất trên Thư Viện Pháp Luật theo tiêu đề / từ khóa
   */
  async searchLegalDocumentsByTitle(keyword: string): Promise<TvplSearchResult[]> {
    try {
      const searchUrl = `https://thuvienphapluat.vn/phap-luat/tim-van-ban.aspx?keyword=${encodeURIComponent(keyword)}&sort=1`;
      console.log(`[TVPL SEARCH] Searching TVPL for keyword: "${keyword}"`);

      const html = await this.fetchHtml(searchUrl);
      const results: TvplSearchResult[] = [];

      // Regex bóc tách tiêu đề và link văn bản từ HTML TVPL
      const regex = /<a[^>]+href=["']([^"']+)["'][^>]*class=["'][^"']*title-law[^"']*["'][^>]*>(.*?)<\/a>/gi;
      let match: RegExpExecArray | null;

      while ((match = regex.exec(html)) !== null && results.length < 5) {
        let href = match[1];
        const title = match[2].replace(/<[^>]+>/g, '').trim();

        if (title && title.length > 10) {
          if (!href.startsWith('http')) {
            href = `https://thuvienphapluat.vn${href.startsWith('/') ? '' : '/'}${href}`;
          }

          results.push({ title, url: href });
        }
      }

      return results;
    } catch (error: any) {
      console.warn('[TVPL SEARCH WARN] Tra cứu TVPL trực tiếp không khả dụng:', error?.message || error);
      return [];
    }
  }

  private fetchHtml(url: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const req = https.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
        },
        timeout: 3500,
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => data += chunk);
        res.on('end', () => resolve(data));
      });

      req.on('error', (err) => reject(err));
      req.on('timeout', () => {
        req.destroy();
        reject(new Error('TVPL Search Timeout'));
      });
    });
  }

}

export const tvplSearchService = TvplSearchService.getInstance();
