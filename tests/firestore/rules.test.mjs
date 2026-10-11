import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, getDocs, collection, query, where, writeBatch, runTransaction, serverTimestamp, Timestamp, setLogLevel } from 'firebase/firestore';

// Synthetic identities and data only. Never connects to a real Firebase project.
const projectId = 'demo-barakah-rules';
const adminId = 'Y3YeLin9gYTbqN4if72o3iTrUSn2'; // Public UID required by the rules, not a credential.
let env;
const db = (uid = 'alice') => env.authenticatedContext(uid, { email: `${uid}@example.test` }).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();
const put = (client, path, data) => setDoc(doc(client, path), data);
const change = (client, path, data) => updateDoc(doc(client, path), data);
const now = () => serverTimestamp();
const profile = (extra = {}) => ({
  email: 'alice@example.test', phone: '', displayName: 'Alice', address: '', gender: '',
  agentNumber: '', agentLocation: '', agentLatitude: null, agentLongitude: null,
  facebookUrl: '', instagramUrl: '', tiktokUrl: '', language: 'ar', role: 'customer',
  loyaltyPoints: 50, signupGiftClaimed: true, signupGiftPoints: 50,
  signupGiftClaimedAt: now(), joinedAt: now(), createdAt: now(), ...extra,
});
const lock = (extra = {}) => ({ businessId: 'shop', dateKey: '2026-10-01', startMinutes: 600,
  endMinutes: 630, status: 'reserved', createdAt: now(), ...extra });
const booking = (extra = {}) => ({ businessId: 'shop', serviceId: 'service_1', serviceTitle: 'Haircut',
  customerId: 'alice', customerName: 'Alice', customerPhone: '00000000', dateKey: '2026-10-01',
  startMinutes: 600, endMinutes: 630, scheduledAt: Timestamp.fromDate(new Date('2026-10-01T07:00:00Z')),
  price: 30, commissionRate: 10, commissionAmount: 3, businessNetAmount: 27, status: 'pending',
  orderType: 'barber_booking', createdAt: now(), updatedAt: now(), ...extra });
const support = (extra = {}) => ({ customerId: 'alice', customerName: 'Alice', customerEmail: 'alice@example.test',
  status: 'open', assignedAgentId: '', assignedAgentName: '', lastMessage: '', createdAt: now(), updatedAt: now(), ...extra });
const message = (extra = {}) => ({ senderId: 'alice', senderRole: 'applicant', senderName: 'Alice', text: 'Hello', createdAt: now(), ...extra });
const summary = (extra = {}) => ({ applicantId: 'alice', applicantName: 'Alice', lastMessage: 'Hello', updatedAt: now(), ...extra });
const seed = (entries) => env.withSecurityRulesDisabled(async ctx => {
  const b = writeBatch(ctx.firestore());
  for (const [path, data] of Object.entries(entries)) b.set(doc(ctx.firestore(), path), data);
  await b.commit();
});

before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || '', /^(127\.0\.0\.1|localhost):8185$/,
    'Run through npm test; an isolated local emulator is required.');
  setLogLevel('silent');
  env = await initializeTestEnvironment({ projectId, firestore: {
    host: '127.0.0.1', port: 8185,
    rules: readFileSync(process.env.BARAKAH_RULES_FILE || new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seed({
    'users/merchant': { role: 'merchant' }, 'users/otherMerchant': { role: 'merchant' },
    [`users/${adminId}`]: { role: 'admin' },
    'items/shop': { ownerId: 'merchant', managerIds: [], type: 'barber', kind: 'business' },
    'users/agent': { role: 'customer_service', customerServiceEnabled: true },
    'employment_contracts/agent': { status: 'accepted' },
    'customer_service_presence/agent': { isAvailable: true, displayName: 'Agent' },
  });
});

test('users: current registration payload preserves the 50-point gift', async () => {
  await assertSucceeds(put(db(), 'users/alice', profile()));
  assert.equal((await getDoc(doc(db(), 'users/alice'))).data().loyaltyPoints, 50);
});
for (const [name, extra] of Object.entries({
  'injected points': { loyaltyPoints: 50000 }, 'isAdmin flag': { isAdmin: true },
  'permissions': { adminPermissions: { manageOrders: true } }, 'staff enablement': { customerServiceEnabled: true },
  'forged email': { email: 'victim@example.test' }, 'role escalation': { role: 'admin' },
  'backdated gift': { signupGiftClaimedAt: Timestamp.fromMillis(1) },
})) test(`users: rejects ${name}`, async () => assertFails(put(db(), 'users/alice', profile(extra))));

test('users: legacy missing gift fields can claim once; replay and balance edits fail', async () => {
  await seed({ 'users/alice': { role: 'customer' } });
  const gift = { loyaltyPoints: 50, signupGiftClaimed: true, signupGiftPoints: 50, signupGiftClaimedAt: now() };
  await assertSucceeds(change(db(), 'users/alice', gift));
  await assertFails(change(db(), 'users/alice', { ...gift, loyaltyPoints: 100 }));
  await assertFails(change(db(), 'users/alice', { loyaltyPoints: 500 }));
  await assertSucceeds(change(db(), 'users/alice', { displayName: 'Updated', updatedAt: now(), fcmTokens: ['synthetic-token'] }));
});
test('users: private profiles and administrator edits remain protected', async () => {
  await seed({ 'users/alice': { role: 'customer', loyaltyPoints: 50 } });
  await assertFails(getDoc(doc(db('bob'), 'users/alice')));
  await assertSucceeds(change(db(adminId), 'users/alice', { role: 'merchant' }));
});

test('bookings: public availability and private booking reads remain valid', async () => {
  await seed({ 'barber_slot_locks/slot': lock(), 'barber_bookings/booking': booking() });
  await assertSucceeds(getDocs(query(collection(anonymous(), 'barber_slot_locks'), where('businessId', '==', 'shop'))));
  await assertSucceeds(getDoc(doc(db(), 'barber_bookings/booking')));
  await assertSucceeds(getDoc(doc(db('merchant'), 'barber_bookings/booking')));
  await assertFails(getDoc(doc(db('bob'), 'barber_bookings/booking')));
});
test('bookings: all direct writes are denied, including apparently valid payloads', async () => {
  await seed({ 'barber_slot_locks/slot': lock(), 'barber_bookings/booking': booking() });
  for (const client of [db(), db('merchant'), db(adminId), anonymous()]) {
    await assertFails(put(client, 'barber_slot_locks/new', lock()));
    await assertFails(put(client, 'barber_bookings/new', booking()));
    await assertFails(change(client, 'barber_slot_locks/slot', { status: 'cancelled' }));
    await assertFails(change(client, 'barber_bookings/booking', { status: 'cancelled', updatedAt: now() }));
  }
  await assertFails(getDoc(doc(db(), 'barber_booking_days/shop_day')));
});
test('analytics: anonymous visits and category views work; forged timestamps and extras fail', async () => {
  const client = anonymous(); const event = { eventType: 'app_visit', sessionId: 'synthetic-session', createdAt: now() };
  await assertSucceeds(put(client, 'analytics_events/visit', event));
  await assertSucceeds(put(client, 'analytics_events/category', { ...event, eventType: 'category_view', category: 'Food' }));
  await assertFails(put(client, 'analytics_events/old', { ...event, createdAt: Timestamp.fromMillis(1) }));
  await assertFails(put(client, 'analytics_events/extra', { ...event, userId: 'victim' }));
  await assertFails(getDoc(doc(client, 'analytics_events/visit')));
});
test('partners: direct creation is closed; server-seeded records remain admin-only', async () => {
  const record = {
    businessName: 'Synthetic shop', ownerName: 'Test Owner', email: 'owner@example.test',
    phone: '00000000', nationalId: 'TEST-ID', activityType: 'barber', area: 'Test area',
    description: '', locationUrl: '', latitude: 0, longitude: 0,
    payoutOwnerName: 'Test Owner', payoutMethod: 'Test', payoutAccount: 'TEST-ONLY',
    identityDocumentRef: '', businessDocumentRef: '', payoutDocumentRef: '',
    commissionRate: 10, commissionAppliesTo: 'products_and_bookings', subscriptionFee: 0,
    acceptedPartnerAgreement: true, acceptedPrivacyPolicy: true, agreementVersion: 'test',
    identityVerified: false, businessVerified: false, payoutVerified: false,
    merchantEnabled: false, status: 'pending', source: 'partner_web',
    createdAt: now(), updatedAt: now(), agreementAcceptedAt: now(),
  };
  await assertFails(put(anonymous(), 'merchant_applications/new', record));
  await assertFails(put(db(), 'merchant_applications/new', record));
  await seed({ 'merchant_applications/server-created': record });
  await assertSucceeds(getDoc(doc(db(adminId), 'merchant_applications/server-created')));
  await assertFails(getDoc(doc(db(), 'merchant_applications/server-created')));
  await assertSucceeds(change(db(adminId), 'merchant_applications/server-created', { identityVerified: true }));
});

test('recruitment: current atomic summary/message write and administrator response work', async () => {
  const client = db(); const b = writeBatch(client);
  b.set(doc(client, 'recruitment_chats/alice'), summary(), { merge: true });
  b.set(doc(client, 'recruitment_chats/alice/messages/hello'), message());
  await assertSucceeds(b.commit());
  await assertSucceeds(put(db(adminId), 'recruitment_chats/alice/messages/reply', message({ senderId: adminId, senderRole: 'admin' })));
  await assertFails(getDoc(doc(db('bob'), 'recruitment_chats/alice/messages/hello')));
});
test('recruitment: applicants cannot inject workflow fields or forge admin messages/times', async () => {
  await assertFails(put(db(), 'recruitment_chats/alice', summary({ status: 'accepted' })));
  await assertFails(put(db(), 'recruitment_chats/alice/messages/forged', message({ senderRole: 'admin' })));
  await assertFails(put(db(), 'recruitment_chats/alice/messages/extra', message({ verified: true })));
  await assertFails(put(db(), 'recruitment_chats/alice/messages/old', message({ createdAt: Timestamp.fromMillis(1) })));
});
test('recruitment: normal updates preserve existing server fields but cannot change them', async () => {
  await seed({ 'recruitment_chats/alice': summary({ status: 'reviewed' }) });
  await assertSucceeds(change(db(), 'recruitment_chats/alice', summary({ lastMessage: 'Follow up' })));
  await assertFails(change(db(), 'recruitment_chats/alice', { status: 'accepted', updatedAt: now() }));
});

test('support: own missing-document read, create, assignment and assigned-agent query work', async () => {
  await assertSucceeds(getDoc(doc(db(), 'support_threads/alice')));
  await assertSucceeds(put(db(), 'support_threads/alice', support()));
  await assertSucceeds(change(db(), 'support_threads/alice', { assignedAgentId: 'agent', assignedAgentName: 'Agent', status: 'assigned', updatedAt: now() }));
  await assertSucceeds(getDocs(query(collection(db('agent'), 'support_threads'), where('assignedAgentId', '==', 'agent'))));
  await assertSucceeds(change(db('agent'), 'support_threads/alice', { status: 'active', updatedAt: now() }));
});
test('support: attacker cannot squat another users document identifier', async () => {
  await assertFails(put(db(), 'support_threads/bob', support()));
});
test('support: a legacy spoofed document is not disclosed to its path owner', async () => {
  await seed({ 'support_threads/bob': support() });
  await assertFails(getDoc(doc(db('bob'), 'support_threads/bob')));
});
test('support: assigned creation and private messages preserve role/owner restrictions', async () => {
  await assertSucceeds(put(db(), 'support_threads/alice', support({ assignedAgentId: 'agent', assignedAgentName: 'Agent', status: 'assigned' })));
  await assertSucceeds(put(db(), 'support_threads/alice/messages/customer', message({ senderRole: 'customer' })));
  await assertSucceeds(put(db('agent'), 'support_threads/alice/messages/agent', message({ senderId: 'agent', senderRole: 'customer_service' })));
  await assertFails(put(db('bob'), 'support_threads/alice/messages/stranger', message({ senderId: 'bob', senderRole: 'customer' })));
  await assertFails(put(db(), 'support_threads/alice/messages/forged-time', message({ senderRole: 'customer', createdAt: Timestamp.fromMillis(1) })));
  await assertFails(getDoc(doc(db('bob'), 'support_threads/alice/messages/customer')));
  await assertFails(change(db(), 'support_threads/alice', { assignedAgentId: 'bob' }));
});

test('support: rejects malformed timestamps and impersonated email on creation', async () => {
  await assertFails(put(db(), 'support_threads/alice', support({ updatedAt: 'invalid-date' })));
  await assertFails(put(db(), 'support_threads/alice', support({ createdAt: Timestamp.fromMillis(1) })));
  await assertFails(put(db(), 'support_threads/alice', support({ customerEmail: 'victim@example.test' })));
});
test('support: customers and staff cannot corrupt inbox sorting or inject unknown status', async () => {
  await seed({ 'support_threads/alice': support({ assignedAgentId: 'agent', status: 'assigned' }) });
  for (const uid of ['alice', 'agent']) {
    await assertFails(change(db(uid), 'support_threads/alice', { updatedAt: 'invalid-date' }));
    await assertFails(change(db(uid), 'support_threads/alice', { status: 'forged', updatedAt: now() }));
    await assertFails(change(db(uid), 'support_threads/alice', { lastMessageAt: Timestamp.fromMillis(1), updatedAt: now() }));
    await assertSucceeds(change(db(uid), 'support_threads/alice', { status: 'closed', updatedAt: now() }));
  }
});
