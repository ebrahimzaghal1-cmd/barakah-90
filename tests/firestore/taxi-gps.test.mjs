import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, deleteDoc, where, writeBatch, setLogLevel, Timestamp } from 'firebase/firestore';

// This suite intentionally uses its own synthetic project and a loopback-only
// emulator. Neither SDK calls nor the Worker REST adapter reach production.
const projectId = 'demo-barakah-taxi-gps';
const adminId = 'Y3YeLin9gYTbqN4if72o3iTrUSn2';
const orderId = 'gps-trip';
const orderPath = `taxi_orders/${orderId}`;
const firstTime = new Date('2026-09-19T12:00:00.000Z');
let env;
const db = uid => env.authenticatedContext(uid).firestore();
const seed = entries => env.withSecurityRulesDisabled(async context => {
  const batch = writeBatch(context.firestore());
  for (const [path, data] of Object.entries(entries)) batch.set(doc(context.firestore(), path), data);
  await batch.commit();
});

before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):8185$/,
    'Use the isolated local Firestore emulator on port 8185.');
  setLogLevel('silent');
  env = await initializeTestEnvironment({ projectId, firestore: {
    host: '127.0.0.1', port: 8185,
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});

after(async () => { if (env) await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await seed({
    'users/customer': { role: 'customer' },
    'users/otherCustomer': { role: 'customer' },
    'users/merchant': { role: 'merchant' },
    [`users/${adminId}`]: { role: 'admin' },
    'users/driver': { role: 'customer', taxiDriverEnabled: true, taxiBusinessId: 'office' },
    'users/otherDriver': { role: 'customer', taxiDriverEnabled: true, taxiBusinessId: 'office' },
    'items/office': { ownerId: 'merchant', managerIds: [], title: 'Internal test office', type: 'taxi', commissionRate: 10 },
    [orderPath]: {
      orderId, orderNumber: '#TK-GPS', businessId: 'office', businessName: 'تكسي بركة',
      customerId: 'customer', driverUid: 'driver', status: 'dispatched',
      fareAmount: null, commissionRate: null, commissionAmount: null, businessNet: null,
      commissionStatus: 'pending', commissionEarnedAt: null,
      createdAt: Timestamp.fromDate(firstTime),
      updatedAt: Timestamp.fromDate(firstTime),
      tripStartedAt: Timestamp.fromDate(firstTime),
      tripStartedBy: 'driver',
      driverLatitude: 32.31,
      driverLongitude: 35.02,
      driverLocationUpdatedAt: Timestamp.fromDate(firstTime),
    },
  });
});

test('taxi rules: assigned driver and customer can read GPS, others cannot', async () => {
  for (const uid of ['driver', 'customer', 'merchant', adminId]) {
    const snapshot = await assertSucceeds(getDoc(doc(db(uid), orderPath)));
    assert.equal(snapshot.data().driverLatitude, 32.31);
    assert.equal(snapshot.data().businessName, 'تكسي بركة');
  }
  for (const uid of ['otherDriver', 'otherCustomer']) {
    await assertFails(getDoc(doc(db(uid), orderPath)));
  }
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), orderPath)));
  const ownTrips = query(collection(db('driver'), 'taxi_orders'), where('driverUid', '==', 'driver'));
  assert.equal((await assertSucceeds(getDocs(ownTrips))).size, 1);
  const customerTrips = query(collection(db('customer'), 'taxi_orders'), where('customerId', '==', 'customer'));
  assert.equal((await assertSucceeds(getDocs(customerTrips))).size, 1);
  await assertFails(getDocs(collection(db('driver'), 'taxi_orders')));
});

test('taxi rules: every client is denied direct GPS, status, create and delete writes', async () => {
  for (const uid of ['driver', 'customer', 'merchant', adminId]) {
    const client = db(uid);
    await assertFails(updateDoc(doc(client, orderPath), {
      driverLatitude: 32.31, driverLongitude: 35.02,
      tripStartedAt: firstTime, driverLocationUpdatedAt: firstTime,
    }));
    await assertFails(updateDoc(doc(client, orderPath), { status: 'completed' }));
    await assertFails(setDoc(doc(client, 'taxi_orders/forged'), {
      customerId: uid, driverUid: uid, businessId: 'office', status: 'dispatched',
    }));
    await assertFails(deleteDoc(doc(client, orderPath)));
  }
  const unchanged = await assertSucceeds(getDoc(doc(db('driver'), orderPath)));
  assert.equal(unchanged.data().driverLatitude, 32.31);
});

// Worker transaction authorization is covered by the Worker Vitest suite. The
// Firestore emulator's REST adapter does not support document reads carrying a
// transaction query parameter, so these end-to-end adapter checks stay
// documented here without running against a misleading emulator path.
test.skip('GPS REST transaction: only the currently assigned enabled office driver may start or update', async () => {
  for (const uid of ['customer', 'otherCustomer', 'merchant', adminId, 'otherDriver']) {
    for (const action of ['start_trip', 'update_location']) {
      await assert.rejects(act(uid, gps(action)), error => error.status === 403);
    }
  }
  for (const invalidProfile of [
    { role: 'driver', taxiDriverEnabled: false, taxiBusinessId: 'office' },
    { role: 'driver', taxiDriverEnabled: true, taxiBusinessId: 'another-office' },
  ]) {
    await seed({ 'users/driver': invalidProfile });
    for (const action of ['start_trip', 'update_location']) {
      await assert.rejects(act('driver', gps(action)), error => error.status === 403);
    }
  }
  assert.equal((await readOrder()).tripStartedAt, undefined);
});

test.skip('GPS REST transaction: server times survive retries and client fields cannot change finance or identity', async () => {
  await act('driver', gps('start_trip', {
    tripStartedAt: '1900-01-01', driverLocationUpdatedAt: '1900-01-01',
    businessName: 'forged', driverUid: 'otherDriver', status: 'completed',
    commissionRate: 0, fareAmount: 999,
  }));
  let order = await readOrder();
  assert.deepEqual(order.tripStartedAt, firstTime);
  assert.deepEqual(order.driverLocationUpdatedAt, firstTime);
  assert.equal(order.businessName, 'تكسي بركة');
  assert.equal(order.driverUid, 'driver');
  assert.equal(order.status, 'dispatched');
  assert.equal(order.fareAmount, null);
  assert.equal(order.commissionRate, null);
  await act('driver', gps('start_trip'), laterTime);
  assert.deepEqual((await readOrder()).tripStartedAt, firstTime);
  await act('driver', gps('update_location', { latitude: -90, longitude: 180 }), laterTime);
  order = await readOrder();
  assert.equal(order.driverLatitude, -90);
  assert.equal(order.driverLongitude, 180);
  assert.deepEqual(order.driverLocationUpdatedAt, laterTime);
  assert.deepEqual(order.tripStartedAt, firstTime);
});

test.skip('GPS REST transaction: missing, nonnumeric and out-of-range coordinates leave the document unchanged', async () => {
  const beforeStart = await readOrder();
  for (const input of [
    { action: 'start_trip', latitude: 32 },
    gps('start_trip', { latitude: '32.31' }),
    gps('start_trip', { longitude: 180.01 }),
  ]) {
    await assert.rejects(act('driver', input), error => error.status === 400);
    assert.deepEqual(await readOrder(), beforeStart);
  }
  await assert.rejects(act('driver', gps('update_location')), error => error.status === 409);
  await act('driver', gps('start_trip'));
  const beforeUpdate = await readOrder();
  for (const input of [
    gps('update_location', { latitude: null }),
    gps('update_location', { latitude: -90.01 }),
    gps('update_location', { longitude: Infinity }),
  ]) {
    await assert.rejects(act('driver', input), error => error.status === 400);
    assert.deepEqual(await readOrder(), beforeUpdate);
  }
});

test.skip('GPS REST transaction: completion racing a position update prevents all later positions', async () => {
  await act('driver', gps('start_trip'));
  const [positionResult, completeResult] = await Promise.allSettled([
    act('driver', gps('update_location', { latitude: 32.32 }), laterTime),
    act('merchant', { action: 'complete', fareAmount: 50 }, laterTime),
  ]);
  assert.equal(completeResult.status, 'fulfilled', String(completeResult.reason));
  if (positionResult.status === 'rejected') assert.equal(positionResult.reason.status, 409);
  const finished = await readOrder();
  assert.equal(finished.status, 'awaiting_customer_confirmation');
  assert.equal(finished.fareAmount, 50);
  assert.equal(finished.commissionAmount, 5);
  assert.equal(finished.commissionStatus, 'pending');
  for (const action of ['start_trip', 'update_location']) {
    await assert.rejects(act('driver', gps(action), new Date(laterTime.getTime() + 10000)), error => error.status === 409);
    assert.deepEqual(await readOrder(), finished);
  }
  await act('customer', { action: 'confirm' }, new Date(laterTime.getTime() + 20000));
  const confirmed = await readOrder();
  assert.equal(confirmed.status, 'completed');
  assert.equal(confirmed.commissionStatus, 'earned');
  await assert.rejects(act('driver', gps('update_location')), error => error.status === 409);
  assert.deepEqual(await readOrder(), confirmed);
});

test.skip('GPS REST transaction: cancellation or reassignment stops the previous driver', async () => {
  await act('driver', gps('start_trip'));
  await seed({ [orderPath]: { ...(await readOrder()), driverUid: 'otherDriver' } });
  await assert.rejects(act('driver', gps('update_location')), error => error.status === 403);
  await act('merchant', { action: 'cancel', reason: 'Synthetic test cancellation' });
  const cancelled = await readOrder();
  for (const action of ['start_trip', 'update_location']) {
    await assert.rejects(act('otherDriver', gps(action)), error => error.status === 409);
  }
  assert.deepEqual(await readOrder(), cancelled);
});
