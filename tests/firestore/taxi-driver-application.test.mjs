import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
  serverTimestamp,
} from 'firebase/firestore';

const projectId = 'demo-barakah-taxi-driver-application';
const adminId = 'Y3YeLin9gYTbqN4if72o3iTrUSn2';

const applicantId = 'taxiApplicant';
const otherId = 'otherUser';

let env;

const db = (uid, token = {}) =>
  env.authenticatedContext(uid, token).firestore();

const applicationPath =
  `taxi_driver_applications/${applicantId}`;

async function seed(entries) {
  await env.withSecurityRulesDisabled(async (context) => {
    const batch = writeBatch(context.firestore());

    for (const [path, data] of Object.entries(entries)) {
      batch.set(doc(context.firestore(), path), data);
    }

    await batch.commit();
  });
}

function applicationData() {
  return {
    userId: applicantId,
    fullName: 'سائق تكسي اختبار',
    email: 'taxi@example.com',
    phone: '0590000000',
    nationalId: '123456789',
    vehicle: 'Toyota Corolla',
    plateNumber: '12-345-67',
    vehicleColor: 'أبيض',
    driverLicenseNumber: 'DL12345',
    vehicleLicenseNumber: 'VL12345',
    vehicleInsuranceNumber: 'INS12345',
    payoutMethod: 'bank',
    payoutAccount: 'TEST-ACCOUNT',
    acceptedDriverTerms: true,
    acceptedPrivacyPolicy: true,
    agreementVersion: 'taxi-driver-v1',
    agreementAcceptedAt: serverTimestamp(),
    status: 'pending',
    identityVerified: false,
    driverLicenseVerified: false,
    vehicleDocumentsVerified: false,
    payoutVerified: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

before(async () => {
  assert.match(
    process.env.FIRESTORE_EMULATOR_HOST || '',
    /^(127\.0\.0\.1|localhost):8185$/,
    'Use the isolated Firestore emulator on port 8185.',
  );

  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8185,
      rules: readFileSync(
        new URL('../../firestore.rules', import.meta.url),
        'utf8',
      ),
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();

  await seed({
    [`users/${adminId}`]: {
      role: 'admin',
      email: 'admin@example.com',
    },
    [`users/${applicantId}`]: {
      role: 'customer',
      email: 'taxi@example.com',
    },
    [`users/${otherId}`]: {
      role: 'customer',
      email: 'other@example.com',
    },
  });
});

test('taxi driver application: owner can create a valid pending application', async () => {
  const applicantDb = db(applicantId, {
    email: 'taxi@example.com',
  });

  await assertSucceeds(
    setDoc(
      doc(applicantDb, applicationPath),
      applicationData(),
    ),
  );

  const snapshot = await assertSucceeds(
    getDoc(doc(applicantDb, applicationPath)),
  );

  assert.equal(snapshot.data().status, 'pending');
  assert.equal(snapshot.data().identityVerified, false);
  assert.equal(snapshot.data().payoutVerified, false);
});

test('taxi driver application: user cannot create another users application', async () => {
  const otherDb = db(otherId, {
    email: 'other@example.com',
  });

  await assertFails(
    setDoc(
      doc(otherDb, applicationPath),
      applicationData(),
    ),
  );
});

test('taxi driver application: owner can edit personal fields while still pending', async () => {
  const applicantDb = db(applicantId, {
    email: 'taxi@example.com',
  });

  await assertSucceeds(
    setDoc(
      doc(applicantDb, applicationPath),
      applicationData(),
    ),
  );

  await assertSucceeds(
    updateDoc(
      doc(applicantDb, applicationPath),
      {
        vehicle: 'Toyota Prius',
        vehicleColor: 'أسود',
        agreementAcceptedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    ),
  );

  const snapshot = await assertSucceeds(
    getDoc(doc(applicantDb, applicationPath)),
  );

  assert.equal(snapshot.data().vehicle, 'Toyota Prius');
  assert.equal(snapshot.data().status, 'pending');
});

test('taxi driver application: applicant cannot approve or verify themselves', async () => {
  const applicantDb = db(applicantId, {
    email: 'taxi@example.com',
  });

  await assertSucceeds(
    setDoc(
      doc(applicantDb, applicationPath),
      applicationData(),
    ),
  );

  await assertFails(
    updateDoc(
      doc(applicantDb, applicationPath),
      {
        status: 'approved',
        identityVerified: true,
        driverLicenseVerified: true,
        vehicleDocumentsVerified: true,
        payoutVerified: true,
        agreementAcceptedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    ),
  );

  const snapshot = await assertSucceeds(
    getDoc(doc(applicantDb, applicationPath)),
  );

  assert.equal(snapshot.data().status, 'pending');
  assert.equal(snapshot.data().identityVerified, false);
});

test('taxi driver application: another customer cannot read the application', async () => {
  const applicantDb = db(applicantId, {
    email: 'taxi@example.com',
  });

  await assertSucceeds(
    setDoc(
      doc(applicantDb, applicationPath),
      applicationData(),
    ),
  );

  const otherDb = db(otherId, {
    email: 'other@example.com',
  });

  await assertFails(
    getDoc(doc(otherDb, applicationPath)),
  );
});

test('taxi driver application: admin can read and approve a fully verified application', async () => {
  const applicantDb = db(applicantId, {
    email: 'taxi@example.com',
  });

  await assertSucceeds(
    setDoc(
      doc(applicantDb, applicationPath),
      applicationData(),
    ),
  );

  const adminDb = db(adminId, {
    email: 'admin@example.com',
  });

  await assertSucceeds(
    getDoc(doc(adminDb, applicationPath)),
  );

  await assertSucceeds(
    updateDoc(
      doc(adminDb, applicationPath),
      {
        identityVerified: true,
        driverLicenseVerified: true,
        vehicleDocumentsVerified: true,
        payoutVerified: true,
        status: 'approved',
        approvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    ),
  );

  const snapshot = await assertSucceeds(
    getDoc(doc(adminDb, applicationPath)),
  );

  assert.equal(snapshot.data().status, 'approved');
  assert.equal(snapshot.data().identityVerified, true);
  assert.equal(snapshot.data().driverLicenseVerified, true);
  assert.equal(snapshot.data().vehicleDocumentsVerified, true);
  assert.equal(snapshot.data().payoutVerified, true);
});
