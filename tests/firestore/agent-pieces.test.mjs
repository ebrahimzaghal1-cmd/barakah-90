import { after, before, test } from 'node:test';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const ADMIN_UID = 'Y3YeLin9gYTbqN4if72o3iTrUSn2';
const AGENT_UID = 'agent-piece-test';
const OTHER_UID = 'other-piece-test';

let env;

const db = (uid) => env.authenticatedContext(uid).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-barakah-agent-pieces',
    firestore: {
      host: '127.0.0.1',
      port: 8185,
      rules: readFileSync(
        new URL('../../firestore.rules', import.meta.url),
        'utf8',
      ),
    },
  });

  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users', ADMIN_UID),
      {
        isAdmin: true,
        role: 'admin',
      },
    );

    await setDoc(
      doc(context.firestore(), 'agents', AGENT_UID),
      {
        userId: AGENT_UID,
        fullName: 'Test Agent',
        approved: true,
        active: true,
      },
    );
  });
});

after(async () => {
  if (env) await env.cleanup();
});

function validPiece() {
  return {
    agentId: AGENT_UID,
    agentName: 'Test Agent',
    pieceCode: 'BRK001',
    name: 'Test Piece',
    size: '42',
    color: 'Black',
    notes: 'Test note',
    active: true,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

test('admin can create a valid agent piece', async () => {
  await assertSucceeds(
    setDoc(
      doc(
        db(ADMIN_UID),
        'agents',
        AGENT_UID,
        'pieces',
        'BRK001',
      ),
      validPiece(),
    ),
  );
});

test('agent can read own piece but another user cannot', async () => {
  await assertSucceeds(
    getDoc(
      doc(
        db(AGENT_UID),
        'agents',
        AGENT_UID,
        'pieces',
        'BRK001',
      ),
    ),
  );

  await assertFails(
    getDoc(
      doc(
        db(OTHER_UID),
        'agents',
        AGENT_UID,
        'pieces',
        'BRK001',
      ),
    ),
  );
});

test('agent cannot create or modify pieces directly', async () => {
  const ownDb = db(AGENT_UID);

  await assertFails(
    setDoc(
      doc(
        ownDb,
        'agents',
        AGENT_UID,
        'pieces',
        'BRK002',
      ),
      {
        ...validPiece(),
        pieceCode: 'BRK002',
      },
    ),
  );

  await assertFails(
    updateDoc(
      doc(
        ownDb,
        'agents',
        AGENT_UID,
        'pieces',
        'BRK001',
      ),
      {
        notes: 'Changed by agent',
        updatedAt: serverTimestamp(),
      },
    ),
  );
});

test('invalid code and unknown fields are rejected', async () => {
  await assertFails(
    setDoc(
      doc(
        db(ADMIN_UID),
        'agents',
        AGENT_UID,
        'pieces',
        'bad code',
      ),
      {
        ...validPiece(),
        pieceCode: 'bad code',
      },
    ),
  );

  await assertFails(
    setDoc(
      doc(
        db(ADMIN_UID),
        'agents',
        AGENT_UID,
        'pieces',
        'BRK999',
      ),
      {
        ...validPiece(),
        pieceCode: 'BRK999',
        injectedRole: 'admin',
      },
    ),
  );
});


test('admin can use collectionGroup search for pieces while normal user cannot', async () => {
  await assertSucceeds(
    getDocs(
      collectionGroup(
        db(ADMIN_UID),
        'pieces',
      ),
    ),
  );

  await assertFails(
    getDocs(
      collectionGroup(
        db(OTHER_UID),
        'pieces',
      ),
    ),
  );
});

test('admin can update allowed fields and delete piece', async () => {
  const ref = doc(
    db(ADMIN_UID),
    'agents',
    AGENT_UID,
    'pieces',
    'BRK001',
  );

  await assertSucceeds(
    updateDoc(ref, {
      color: 'White',
      notes: 'Updated safely',
      active: false,
      updatedAt: serverTimestamp(),
    }),
  );

  await assertSucceeds(deleteDoc(ref));
});
