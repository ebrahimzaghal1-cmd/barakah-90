import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
const source = readFileSync(new URL('../../barakah_worker_recovered/barakah-secure-api/src/index.js', import.meta.url), 'utf8');
const start = source.indexOf('async function listOrderSupervisorOrders(');
const end = source.indexOf('__name(listOrderSupervisorOrders,', start);
assert(start >= 0 && end > start);
function handler(actor) {
  return runInNewContext(`${source.slice(start, end)}; listOrderSupervisorOrders`, {
    serviceToken: async () => 'test-token',
    firestoreGet: async () => actor,
    isPrimaryAdmin: () => false,
    firestoreQuery: async () => [{ id: 'order', items: [
      { title: 'وجبة', quantity: 1, specialNote: ' بدون بصل ', price: 10 },
      { title: 'وجبة قديمة', quantity: 2 },
    ] }],
    fail: (status, code) => { throw Object.assign(new Error(code), { status }); },
  });
}
test('supervisor receives item notes without exposing item prices', async () => {
  const result = await handler({ role: 'order_supervisor', adminPermissions: { manageOrders: true } })({}, {});
  const items = result.orders[0].items;
  assert.equal(items[0].specialNote, 'بدون بصل');
  assert.equal(items[1].specialNote, '');
  assert.equal(items[0].price, undefined);
});
test('notes remain inaccessible to an unauthorized user', async () => {
  await assert.rejects(handler({ role: 'customer' })({}, {}), { status: 403 });
});
