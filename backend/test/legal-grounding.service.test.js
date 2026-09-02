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
            groundingSupports: [{
              segment: { text: 'Câu trả lời có nguồn.' },
              groundingChunkIndices: [0],
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
    assert.equal(result.supports.length, 1);
    assert.doesNotMatch(capturedUrl, /test-secret-key/);
    assert.equal(capturedOptions.headers['x-goog-api-key'], 'test-secret-key');
    assert.deepEqual(JSON.parse(capturedOptions.body).tools, [
      { google_search: {} },
    ]);
  } finally {
    global.fetch = originalFetch;
  }
});

test('maps each grounded claim only to trusted visible legal sources', async () => {
  const service = new LegalGroundingService();
  const result = await service.extractTrustedGrounding(
    [
      { web: { title: 'CSDL quốc gia', uri: 'https://vbpl.vn/TW/Pages/a.aspx' } },
      { web: { title: 'Blog không tin cậy', uri: 'https://example.com/tax' } },
      { web: { title: 'Thư Viện Pháp Luật', uri: 'https://thuvienphapluat.vn/van-ban/b.aspx' } },
    ],
    [
      { segment: { text: 'Nội dung thứ nhất.' }, groundingChunkIndices: [0, 1] },
      { segment: { text: 'Nội dung thứ hai.' }, groundingChunkIndices: [2] },
      { segment: { text: 'Không có nguồn tin cậy.' }, groundingChunkIndices: [1] },
    ],
  );

  assert.deepEqual(result.sources.map(item => item.domain), [
    'vbpl.vn',
    'thuvienphapluat.vn',
  ]);
  assert.deepEqual(result.claims, [
    {
      text: 'Nội dung thứ nhất.',
      sourceUrls: ['https://vbpl.vn/TW/Pages/a.aspx'],
    },
    {
      text: 'Nội dung thứ hai.',
      sourceUrls: ['https://thuvienphapluat.vn/van-ban/b.aspx'],
    },
  ]);
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
