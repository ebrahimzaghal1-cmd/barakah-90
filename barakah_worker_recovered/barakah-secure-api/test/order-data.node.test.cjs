// Run the real order handler with in-memory persistence and no live services.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../src/index.js'), 'utf8');
function extract(name, async = false) {
  const start = source.indexOf(`${async ? 'async ' : ''}function ${name}(`);
  const end = source.indexOf(`__name(${name},`, start);
  assert.ok(start >= 0 && end > start);
  return source.slice(start, end);
}
async function checkout(item, profile = { displayName: 'عميلة', phone: '0590000000' }) {
  let stored;
  const product = {kind: 'product', title: 'وجبة', businessId: 'shop', price: 10,
    mealOptions: [{id:'large', name:'كبير', price:20}],
    addons: [{id:'cheese', name:'جبنة', price:5}]};
  const context = vm.createContext({
    Request, Date, console, crypto: require('node:crypto').webcrypto,
    MAX_ITEMS: 50, readJson: request => request.json(),
    serviceToken: async () => 'test-token',
    firestoreGet: async (_env, _token, path) => ({
      'items/meal': product, 'items/shop': { title:'مطعم', businessStatus:'open' },
      'users/test-user': profile, 'app_settings/loyalty': {},
    })[path],
    createWrite: (_env, path, data) => ({path, data}),
    firestoreCommit: async (_env, _token, writes) => { stored = writes[0].data; return true; },
    notifyAdminsAboutOrder: async () => {},
    fail: (_status, code) => { throw new Error(code); },
  });
  vm.runInContext(['money','normalizeMealOptions','finiteOrNull'].map(n => extract(n)).join('\n')
    + '\n' + extract('createOrder', true), context);
  const env = {DB: { prepare(sql) { return {
    bind() { return this; },
    async first() { return sql.startsWith('UPDATE counters') ? {value: 1} : null; },
    async run() { return {meta: {changes: 1}}; },
  }; }}};
  await context.createOrder(new Request('https://example.test/v1/orders', {
    method:'POST', headers:{'Idempotency-Key':'test-request-12345678'},
    body:JSON.stringify({items:[item], deliveryMethod:'pickup', paymentMethod:'cash'}),
  }), env, {uid:'test-user', email:'test@example.com'});
  return JSON.parse(JSON.stringify(stored));
}
test('persists customization and customer snapshot with server prices', async () => {
  const order = await checkout({productId:'meal', quantity:2, optionId:'large',
    addonIds:['cheese'], note:' بدون بصل ', price:0});
  assert.equal(order.items[0].note, 'بدون بصل');
  assert.deepEqual(order.items[0].addonIds, ['cheese']);
  assert.equal(order.items[0].addons[0].name, 'جبنة');
  assert.equal(order.items[0].optionName, 'كبير + جبنة');
  assert.equal(order.total, 50);
  assert.equal(order.customerName, 'عميلة');
  assert.equal(order.customerPhone, '0590000000');
});
test('accepts old clients omitting addons and note, with legacy profile name', async () => {
  const order = await checkout({productId:'meal', quantity:1, optionId:'large'},
    {fullName:'اسم قديم', displayName:' ', phone:'0590000000'});
  assert.deepEqual(order.items[0].addonIds, []);
  assert.equal(order.items[0].note, null);
  assert.equal(order.customerName, 'اسم قديم');
  assert.equal(order.total, 20);
});
test('rejects unavailable and duplicate addon IDs', async () => {
  for (const addonIds of [['missing'], ['cheese','cheese']]) {
    await assert.rejects(checkout({productId:'meal',quantity:1,optionId:'large',addonIds}),
      /addon-unavailable/);
  }
});
