import { readFile } from 'node:fs/promises';
import test, { after } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
} from 'firebase/storage';

const PROJECT_ID = 'demo-barakah-rules';
const PRIMARY_ADMIN_UID = 'Y3YeLin9gYTbqN4if72o3iTrUSn2';

let env;

async function environment() {
  if (env) return env;

  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: await readFile('firestore.rules', 'utf8'),
    },
    storage: {
      rules: await readFile('storage.rules', 'utf8'),
    },
  });

  return env;
}

async function storage(uid) {
  const e = await environment();
  return e.authenticatedContext(uid).storage();
}

function pdfBytes() {
  return new Uint8Array([
    0x25, 0x50, 0x44, 0x46,
    0x2d, 0x31, 0x2e, 0x34,
    0x0a, 0x25, 0x25, 0x45,
    0x4f, 0x46,
  ]);
}

after(async () => {
  if (env) {
    await env.cleanup();
  }
});

test('admin can upload partner signed PDF contract', async () => {
  const s = await storage(PRIMARY_ADMIN_UID);

  await assertSucceeds(
    uploadBytes(
      ref(
        s,
        'partner_contracts/application-1/contract.pdf',
      ),
      pdfBytes(),
      { contentType: 'application/pdf' },
    ),
  );
});

test('normal signed user cannot upload partner contract', async () => {
  const s = await storage('normal-user-1');

  await assertFails(
    uploadBytes(
      ref(
        s,
        'partner_contracts/application-2/contract.pdf',
      ),
      pdfBytes(),
      { contentType: 'application/pdf' },
    ),
  );
});

test('partner contract is admin-readable but not user-readable', async () => {
  const admin = await storage(PRIMARY_ADMIN_UID);
  const path =
      'partner_contracts/application-3/contract.pdf';

  await assertSucceeds(
    uploadBytes(
      ref(admin, path),
      pdfBytes(),
      { contentType: 'application/pdf' },
    ),
  );

  await assertSucceeds(
    getBytes(ref(admin, path)),
  );

  const user = await storage('normal-user-2');

  await assertFails(
    getBytes(ref(user, path)),
  );
});

test('partner contract rejects non-PDF upload', async () => {
  const s = await storage(PRIMARY_ADMIN_UID);

  await assertFails(
    uploadBytes(
      ref(
        s,
        'partner_contracts/application-4/contract.pdf',
      ),
      new Uint8Array([1, 2, 3]),
      { contentType: 'text/plain' },
    ),
  );
});

test('partner contract requires fixed contract.pdf filename', async () => {
  const s = await storage(PRIMARY_ADMIN_UID);

  await assertFails(
    uploadBytes(
      ref(
        s,
        'partner_contracts/application-5/other.pdf',
      ),
      pdfBytes(),
      { contentType: 'application/pdf' },
    ),
  );
});

test('admin can delete partner signed contract', async () => {
  const s = await storage(PRIMARY_ADMIN_UID);
  const path =
      'partner_contracts/application-6/contract.pdf';

  await assertSucceeds(
    uploadBytes(
      ref(s, path),
      pdfBytes(),
      { contentType: 'application/pdf' },
    ),
  );

  await assertSucceeds(
    deleteObject(ref(s, path)),
  );
});
