import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
const source = readFileSync(new URL('../../barakah_worker_recovered/barakah-secure-api/src/index.js', import.meta.url), 'utf8');
const start = source.indexOf('async function readJson(request) {');
const end = source.indexOf('__name(readJson,', start);
assert(start >= 0 && end > start);
const readJson = runInNewContext(`${source.slice(start, end)}; readJson`, {
  Uint8Array, TextDecoder,
  fail: (status, code) => { throw Object.assign(new Error(code), { status }); },
});
const request = (body, headers = {}) => new Request('https://example.test', { method: 'POST', body, headers });
test('request body: normal multilingual JSON parses without Content-Length', async () => {
  const value = await readJson(request(JSON.stringify({ text: 'رسالة دعم', status: 'open' })));
  assert.equal(value.text, 'رسالة دعم');
});
test('request body: permits exactly 128000 bytes and rejects one byte more', async () => {
  const text = `"${'a'.repeat(127998)}"`;
  assert.equal((await readJson(request(text))).length, 127998);
  await assert.rejects(readJson(request(`${text} `)), { status: 413 });
});
test('request body: missing or false small Content-Length cannot bypass byte limit', async () => {
  const text = JSON.stringify({ text: 'a'.repeat(128000) });
  await assert.rejects(readJson(request(text)), { status: 413 });
  await assert.rejects(readJson(request(text, { 'content-length': '10' })), { status: 413 });
});
test('request body: byte count includes multibyte characters', async () => {
  await assert.rejects(readJson(request(JSON.stringify('س'.repeat(64000)))), { status: 413 });
});
test('request body: stops and cancels a chunked body as soon as the limit is crossed', async () => {
  let cancelled = false;
  let chunksRead = 0;
  const body = new ReadableStream({
    pull(controller) { chunksRead++; controller.enqueue(new Uint8Array(64001)); },
    cancel() { cancelled = true; },
  }, { highWaterMark: 0 });
  await assert.rejects(readJson({ headers: new Headers(), body }), { status: 413 });
  assert.equal(cancelled, true);
  assert.equal(chunksRead, 2);
});
test('request body: empty and malformed JSON are rejected', async () => {
  await assert.rejects(readJson(request(null)), { status: 400 });
  await assert.rejects(readJson(request('{broken')), { status: 400 });
});
