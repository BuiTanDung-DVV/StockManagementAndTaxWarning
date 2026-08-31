const test = require('node:test');
const assert = require('node:assert/strict');

const {
  LegalGroundingService,
} = require('../dist/services/legal-grounding.service');

test('Gemini legal request always enables current Google Search', async () => {
  const originalFetch = global.fetch;
  let capturedUrl = '';
  let capturedOptions;
  global.fetch = async (url, options) => {
    capturedUrl = String(url);
    capturedOptions = options;
    return {
      ok: true,
      json: async () => ({
        candidates: [{
          content: { parts: [{ text: 'Câu trả lời có nguồn.' }] },
          groundingMetadata: {
            groundingChunks: [{
              web: {
                title: 'Văn bản chính thức',
                uri: 'https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=1',
              },
            }],
          },
        }],
      }),
    };
  };

  try {
    const service = new LegalGroundingService();
    const result = await service.generateWithGoogleSearch(
      'test-secret-key',
      'gemini-2.5-flash',
      'Tra cứu tài liệu thuế mới nhất',
    );

    assert.equal(result.answer, 'Câu trả lời có nguồn.');
    assert.equal(result.chunks.length, 1);
    assert.doesNotMatch(capturedUrl, /test-secret-key/);
    assert.equal(capturedOptions.headers['x-goog-api-key'], 'test-secret-key');
    assert.deepEqual(JSON.parse(capturedOptions.body).tools, [
      { google_search: {} },
    ]);
  } finally {
    global.fetch = originalFetch;
  }
});

test('legal grounding returns only allowlisted sources in priority order', async () => {
  const service = new LegalGroundingService();
  const sources = await service.extractTrustedSources([
    { web: { title: 'Blog', uri: 'https://example.com/tax' } },
    { web: { title: 'TVPL', uri: 'https://thuvienphapluat.vn/van-ban/a.aspx' } },
    { web: { title: 'CSDL quốc gia', uri: 'https://vbpl.vn/TW/Pages/a.aspx' } },
  ]);

  assert.deepEqual(sources.map(item => item.domain), [
    'vbpl.vn',
    'thuvienphapluat.vn',
  ]);
});
