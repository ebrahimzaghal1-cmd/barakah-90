import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { randomUUID } from 'node:crypto';

const source = readFileSync(process.env.SUPPORT_WORKER_SOURCE || new URL('../../barakah_worker_recovered/barakah-secure-api/src/index.js', import.meta.url), 'utf8');
const start = source.indexOf('async function sendSupportMessage(');
const end = source.indexOf('__name(sendSupportMessage,', start);
assert(start >= 0 && end > start, 'Locate the current support handler before testing it');
async function execute({ uid = 'agent', contractStatus = 'accepted', assignedAgentId = 'agent', enabled = true, payload = { text: 'Test reply' }, admin = false } = {}) {
  let committed = false;
  let writes = [];
  const handler = runInNewContext(`${source.slice(start, end)}; sendSupportMessage`, {
    readJson: async () => ({ threadId: 'alice', ...payload }), crypto: { randomUUID }, URL, console: { error() {} },
    serviceToken: async () => 'synthetic-local-only',
    firestoreGet: async (_env, _token, path) => {
      if (path === 'support_threads/alice') return { customerId: 'alice', assignedAgentId, updateTime: 'synthetic-version' };
      if (path === `users/${uid}`) return { role: uid === 'alice' ? 'customer' : 'customer_service', customerServiceEnabled: enabled, displayName: 'Test' };
      if (path === `employment_contracts/${uid}`) return contractStatus === null ? null : { status: contractStatus };
      throw new Error('Unexpected read');
    },
    userPushTokens: async () => [], adminPushTokens: async () => [], sendPushToTokens: async () => {},
    isPrimaryAdmin: () => admin, sendPushBestEffort: async () => {},
    createWrite: (_env, path, data) => ({ path, data }), updateWrite: (_env, path, data) => ({ path, data }),
    firestoreCommit: async (_env, _token, value) => { committed = true; writes = value; return true; },
    fail: (_status, code) => { throw new Error(code); },
  });
  const result = await handler({}, {}, { uid });
  return { result, committed, writes };
}
test('support handler: assigned enabled staff with accepted contract can reply', async () => {
  assert.equal((await execute()).committed, true);
});
test('support handler: missing, unsigned and revoked contracts cannot bypass Firestore rules', async () => {
  for (const contractStatus of [null, 'awaiting_signature', 'revoked']) {
    await assert.rejects(execute({ contractStatus }), /support-contract-required/);
  }
});
test('support handler: unassigned or disabled staff cannot reply', async () => {
  await assert.rejects(execute({ assignedAgentId: 'other-agent' }), /support-permission-denied/);
  await assert.rejects(execute({ enabled: false }), /support-permission-denied/);
});
test('support handler: customers can still send without an employment contract', async () => {
  assert.equal((await execute({ uid: 'alice', contractStatus: null })).committed, true);
});

const imageUrl = 'https://ik.imagekit.io/barakah/test.jpg';
const videoUrl = 'https://ik.imagekit.io/barakah/test.mp4';
test('support media: image-only messages persist attachment for customer, staff and admin', async () => {
  for (const options of [{uid: 'alice'}, {}, {uid: 'owner', admin: true}]) {
    const {writes} = await execute({...options, payload: {imageUrl, mediaType: 'image'}});
    assert.equal(writes[0].data.imageUrl, imageUrl);
    assert.equal(writes[0].data.mediaType, 'image');
    assert.equal(writes[0].data.text, '');
    assert.equal(writes[1].data.lastMessage, '📷 صورة');
  }
});
test('support media: captions and video-only messages persist', async () => {
  const caption = await execute({payload: {text: 'Caption', imageUrl}});
  assert.equal(caption.writes[0].data.text, 'Caption');
  assert.equal(caption.writes[1].data.lastMessage, 'Caption');
  const video = await execute({payload: {videoUrl}});
  assert.equal(video.writes[0].data.videoUrl, videoUrl);
  assert.equal(video.writes[0].data.mediaType, 'video');
});
test('support media: empty, oversized, unsafe and mismatched messages are rejected', async () => {
  for (const payload of [{}, {text: 'x'.repeat(4001)}]) {
    await assert.rejects(execute({payload}), /invalid-message/);
  }
  for (const payload of [
    {imageUrl, videoUrl}, {imageUrl, mediaType: 'video'}, {mediaType: 'image'},
    {imageUrl: 'https://example.com/a.jpg'}, {imageUrl: imageUrl+'?a=1'},
    {imageUrl: 'https://user@ik.imagekit.io/a.jpg'}, {imageUrl: 'http://ik.imagekit.io/a.jpg'},
    {imageUrl: 'https://ik.imagekit.io.evil.com/a.jpg'}
  ]) await assert.rejects(execute({payload}), /invalid-media/);
});
test('support media: attachments cannot bypass staff authorization', async () => {
  await assert.rejects(execute({contractStatus: null, payload: {imageUrl}}), /support-contract-required/);
  await assert.rejects(execute({assignedAgentId: 'other', payload: {imageUrl}}), /support-permission-denied/);
});
