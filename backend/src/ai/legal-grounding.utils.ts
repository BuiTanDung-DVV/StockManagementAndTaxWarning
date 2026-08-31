export type LegalSourceKind = 'official' | 'tvpl';

export interface LegalSourceCitation {
  title: string;
  url: string;
  domain: string;
  sourceKind: LegalSourceKind;
  sourceLabel: string;
}

const LEGAL_QUESTION_PATTERN = new RegExp(
  [
    'pháp luật', 'quy định', 'luật', 'nghị định', 'thông tư', 'quyết định',
    'công văn', 'văn bản', 'tài liệu', 'hiệu lực', 'thuế', 'hóa đơn', 'hoá đơn', 'kê khai',
    'htkk', 'lệ phí', 'xử phạt', 'mức phạt', 'hộ kinh doanh', 'nghĩa vụ',
    'khấu trừ', 'hoàn thuế', 'hoàn thuế', 'thuế suất', 'gtgt', 'tncn', 'tndn',
    'phap luat', 'quy dinh', 'luat', 'nghi dinh', 'thong tu', 'quyet dinh',
    'cong van', 'van ban', 'tai lieu', 'hieu luc', 'thue', 'hoa don', 'ke khai',
    'le phi', 'xu phat', 'ho kinh doanh', 'nghia vu', 'khau tru', 'hoan thue',
  ].join('|'),
  'i',
);

const OFFICIAL_DOMAINS = [
  'vbpl.vn',
  'vanban.chinhphu.vn',
  'chinhphu.vn',
  'mof.gov.vn',
  'gdt.gov.vn',
  'moj.gov.vn',
  'quochoi.vn',
];

const TVPL_DOMAINS = ['thuvienphapluat.vn'];

export function isLegalDocumentQuestion(question: string): boolean {
  return LEGAL_QUESTION_PATTERN.test(question.normalize('NFC'));
}

function matchesDomain(hostname: string, allowedDomain: string): boolean {
  return hostname === allowedDomain || hostname.endsWith(`.${allowedDomain}`);
}

export function classifyLegalSource(rawUrl: string): Omit<LegalSourceCitation, 'title' | 'url'> | null {
  try {
    const url = new URL(rawUrl);
    if (url.protocol !== 'https:') return null;
    const domain = url.hostname.toLowerCase().replace(/^www\./, '');

    const officialDomain = OFFICIAL_DOMAINS.find(value => matchesDomain(domain, value));
    if (officialDomain) {
      return {
        domain,
        sourceKind: 'official',
        sourceLabel: officialDomain === 'vbpl.vn'
          ? 'CSDL quốc gia về văn bản pháp luật'
          : 'Nguồn cơ quan nhà nước',
      };
    }

    if (TVPL_DOMAINS.some(value => matchesDomain(domain, value))) {
      return {
        domain,
        sourceKind: 'tvpl',
        sourceLabel: 'Thư Viện Pháp Luật',
      };
    }
  } catch {
    return null;
  }
  return null;
}

export function rankAndDedupeLegalSources(
  sources: Array<{ title?: string; url?: string }>,
): LegalSourceCitation[] {
  const seen = new Set<string>();
  const citations: LegalSourceCitation[] = [];

  for (const source of sources) {
    const url = source.url?.trim();
    const title = source.title?.replace(/\s+/g, ' ').trim();
    if (!url || !title) continue;
    const classification = classifyLegalSource(url);
    if (!classification) continue;

    let dedupeKey: string;
    try {
      const parsed = new URL(url);
      parsed.hash = '';
      dedupeKey = parsed.toString();
    } catch {
      continue;
    }
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    citations.push({ title: title.slice(0, 240), url, ...classification });
  }

  return citations
    .sort((left, right) => {
      const priority = (value: LegalSourceCitation) => {
        if (value.domain === 'vbpl.vn') return 0;
        if (value.sourceKind === 'official') return 1;
        return 2;
      };
      return priority(left) - priority(right);
    })
    .slice(0, 5);
}
