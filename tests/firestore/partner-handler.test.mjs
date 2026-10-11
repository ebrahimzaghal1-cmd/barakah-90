import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { randomUUID } from 'node:crypto';

// Execute the local production handler with network/storage boundaries stubbed.
// No secrets, service account credentials, or live network calls are used.
const source = readFileSync(new URL('../../barakah_worker_recovered/barakah-secure-api/src/index.js', import.meta.url), 'utf8');
const start = source.indexOf('async function createPartnerApplication(');
const end = source.indexOf('__name(createPartnerApplication,', start);
assert(start >= 0 && end > start, 'Locate the current partner handler before testing it');
const fixture = (extra = {}) => ({ businessName: 'Test Shop', ownerName: 'Test Owner', email: 'owner@example.test',
  phone: '00000000', activityType: 'barber', businessCategory: 'Test category', area: 'Test area',
  locationUrl: 'https://example.test/location', identityDocumentRef: 'synthetic-document-reference',
  latitude: 31, longitude: 35, acceptedPartnerAgreement: true, acceptedPrivacyPolicy: true, ...extra });
const execute = async (body) => {
  const writes = [];
  const handler = runInNewContext(`${source.slice(start, end)}; createPartnerApplication`, {
    readJson: async () => body, crypto: { randomUUID },
    serviceToken: async () => 'synthetic-local-only',
    firestoreCreate: async (_env, _token, collection, id, data) => writes.push({ collection, id, data }),
    adminPushTokens: async () => [], sendPushToTokens: async () => {},
    fail: (_status, code) => { throw new Error(code); },
  });
  const result = await handler({}, {});
  return { result, writes };
};
test('partner handler: current unauthenticated submission still builds a pending record', async () => {
  const { result, writes } = await execute(fixture());
  assert.equal(result.status, 'pending');
  assert.equal(writes.length, 1);
  assert.equal(writes[0].collection, 'merchant_applications');
});
test('partner handler: caller cannot enable merchant status or alter verification and commission', async () => {
  const { writes } = await execute(fixture({ status: 'accepted', identityVerified: true, payoutVerified: true,
    businessVerified: true, merchantEnabled: true, commissionRate: 0, subscriptionFee: -1 }));
  const data = writes[0].data;
  assert.equal(data.status, 'pending'); assert.equal(data.merchantEnabled, false);
  assert.equal(data.identityVerified, false); assert.equal(data.payoutVerified, false);
  assert.equal(data.businessVerified, false); assert.equal(data.commissionRate, 10);
  assert.equal(data.subscriptionFee, 0);
});
test('partner handler: missing consent and nonnumeric coordinates are rejected', async () => {
  await assert.rejects(execute(fixture({ acceptedPartnerAgreement: false })), /agreements-required/);
  await assert.rejects(execute(fixture({ latitude: 'invalid' })), /invalid-location/);
});
test('partner handler: rejects null, boolean and geographically invalid coordinates', async () => {
  for (const latitude of [null, '', false, {}, 91, -91]) {
    await assert.rejects(execute(fixture({ latitude })), /invalid-location/);
  }
  for (const longitude of [null, '', false, {}, 181, -181]) {
    await assert.rejects(execute(fixture({ longitude })), /invalid-location/);
  }
  assert.equal((await execute(fixture({ latitude: 0, longitude: 0 }))).writes.length, 1);
});
