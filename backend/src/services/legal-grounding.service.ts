import { GroundingChunk } from '@google/generative-ai';
import {
  classifyLegalSource,
  LegalClaimEvidence,
  LegalSourceCitation,
  rankAndDedupeLegalSources,
} from '../ai/legal-grounding.utils';

interface GroundingSupport {
  segment?: {
    text?: string;
    startIndex?: number;
    endIndex?: number;
  };
  groundingChunkIndices?: number[];
}

export interface TrustedLegalGrounding {
  sources: LegalSourceCitation[];
  claims: LegalClaimEvidence[];
}

const GOOGLE_GROUNDING_DOMAINS = [
  'vertexaisearch.cloud.google.com',
  'grounding-api-redirect.googleusercontent.com',
];

function isGoogleGroundingUrl(rawUrl: string): boolean {
  try {
    const hostname = new URL(rawUrl).hostname.toLowerCase();
    return GOOGLE_GROUNDING_DOMAINS.some(
      domain => hostname === domain || hostname.endsWith(`.${domain}`),
    );
  } catch {
    return false;
  }
}

export class LegalGroundingService {
  async generateWithGoogleSearch(
    apiKey: string,
    modelName: string,
    prompt: string,
  ): Promise<{
    answer: string;
    chunks: GroundingChunk[];
    supports: GroundingSupport[];
  }> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30000);
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(modelName)}:generateContent`,
        {
          method: 'POST',
          signal: controller.signal,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            tools: [{ google_search: {} }],
          }),
        },
      );

      const payload = await response.json() as {
        error?: { message?: string };
        candidates?: Array<{
          content?: { parts?: Array<{ text?: string }> };
          groundingMetadata?: {
            groundingChunks?: GroundingChunk[];
            groundingSupports?: GroundingSupport[];
          };
        }>;
      };
      if (!response.ok) {
        throw new Error(payload.error?.message || `Gemini Search HTTP ${response.status}`);
      }

      const candidate = payload.candidates?.[0];
      const answer = candidate?.content?.parts
        ?.map(part => part.text || '')
        .join('')
        .trim() || '';
      if (!answer) throw new Error('Gemini Search không trả về nội dung');

      return {
        answer,
        chunks: candidate?.groundingMetadata?.groundingChunks || [],
        supports: candidate?.groundingMetadata?.groundingSupports || [],
      };
    } finally {
      clearTimeout(timeout);
    }
  }

  async extractTrustedSources(chunks: GroundingChunk[] | undefined): Promise<LegalSourceCitation[]> {
    return (await this.extractTrustedGrounding(chunks, [])).sources;
  }

  async extractTrustedGrounding(
    chunks: GroundingChunk[] | undefined,
    supports: GroundingSupport[] | undefined,
  ): Promise<TrustedLegalGrounding> {
    if (!chunks?.length) return { sources: [], claims: [] };

    const resolved = await Promise.all(chunks.map(async chunk => {
      const title = chunk.web?.title?.trim();
      const rawUrl = chunk.web?.uri?.trim();
      if (!title || !rawUrl) return null;

      const trustedDirect = classifyLegalSource(rawUrl);
      if (trustedDirect) return { title, url: rawUrl };
      if (!isGoogleGroundingUrl(rawUrl)) return null;

      const resolvedUrl = await this.resolveGoogleRedirect(rawUrl);
      return resolvedUrl ? { title, url: resolvedUrl } : null;
    }));

    const sources = rankAndDedupeLegalSources(
      resolved.filter((value): value is { title: string; url: string } => value !== null),
    );
    const visibleUrls = new Set(sources.map(source => source.url));
    const seenClaims = new Set<string>();
    const claims = (supports || []).flatMap(support => {
      const text = support.segment?.text?.replace(/\s+/g, ' ').trim();
      if (!text || seenClaims.has(text)) return [];

      const sourceUrls = [...new Set(
        (support.groundingChunkIndices || [])
          .map(index => resolved[index]?.url)
          .filter((url): url is string => Boolean(url && visibleUrls.has(url))),
      )];
      if (sourceUrls.length === 0) return [];

      seenClaims.add(text);
      return [{ text: text.slice(0, 600), sourceUrls }];
    });

    return { sources, claims };
  }

  private async resolveGoogleRedirect(rawUrl: string): Promise<string | null> {
    let current = rawUrl;
    for (let redirectCount = 0; redirectCount < 5; redirectCount += 1) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 3500);
      try {
        const response = await fetch(current, {
          method: 'HEAD',
          redirect: 'manual',
          signal: controller.signal,
          headers: { 'User-Agent': 'SmartStock-Legal-Grounding/1.0' },
        });
        const location = response.headers.get('location');
        if (!location) return classifyLegalSource(current) ? current : null;

        const next = new URL(location, current).toString();
        if (classifyLegalSource(next)) return next;
        if (!isGoogleGroundingUrl(next)) return null;
        current = next;
      } catch {
        return null;
      } finally {
        clearTimeout(timeout);
      }
    }
    return null;
  }
}

export const legalGroundingService = new LegalGroundingService();
