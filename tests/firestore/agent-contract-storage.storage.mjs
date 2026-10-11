import { after, before, test } from 'node:test';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  doc,
  setDoc,
} from 'firebase/firestore';

import {
  deleteObject,
  getBytes,
  ref as storageRef,
  uploadBytes,
} from 'firebase/storage';

const PROJECT_ID = 'demo-barakah-rules';

const PRIMARY_ADMIN_UID = 'Y3YeLin9gYTbqN4if72o3iTrUSn2';
const SECOND_ADMIN_UID = 'storage-admin-test';
const AGENT_UID = 'storage-agent-test';
const OTHER_UID = 'storage-other-test';

const CONTRACT_PATH =
  `agent_contracts/${AGENT_UID}/contract.pdf`;

let env;

const firestore = (uid) =>
  env.authenticatedContext(uid).firestore();

const storage = (uid) =>
  env.authenticatedContext(uid).storage();

const pdfBytes = new Uint8Array([
  0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34,
  0x0a, 0x25, 0x42, 0x41, 0x52, 0x41, 0x4b, 0x41,
]);

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,

    firestore: {
      host: '127.0.0.1',
      port: 8185,
      rules: readFileSync(
        new URL('../../firestore.rules', import.meta.url),
        'utf8',
      ),
    },

    storage: {
      host: '127.0.0.1',
      port: 9199,
      rules: readFileSync(
        new URL('../../storage.rules', import.meta.url),
        'utf8',
      ),
    },
  });

  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'users',
        SECOND_ADMIN_UID,
      ),
      {
        role: 'admin',
        isAdmin: true,
      },
    );

    await setDoc(
      doc(
        context.firestore(),
        'users',
        AGENT_UID,
      ),
      {
        role: 'customer',
        isAdmin: false,
      },
    );

    await setDoc(
      doc(
        context.firestore(),
        'users',
        OTHER_UID,
      ),
      {
        role: 'customer',
        isAdmin: false,
      },
    );
  });
});

after(async () => {
  if (env) {
    await env.cleanup();
  }
});

test(
  'primary admin can upload a valid PDF contract',
  async () => {
    await assertSucceeds(
      uploadBytes(
        storageRef(
          storage(PRIMARY_ADMIN_UID),
          CONTRACT_PATH,
        ),
        pdfBytes,
        {
          contentType: 'application/pdf',
        },
      ),
    );
  },
);

test(
  'agent can read own contract',
  async () => {
    const bytes = await assertSucceeds(
      getBytes(
        storageRef(
          storage(AGENT_UID),
          CONTRACT_PATH,
        ),
      ),
    );

    if (bytes.length === 0) {
      throw new Error('contract bytes were empty');
    }
  },
);

test(
  'another signed-in user cannot read agent contract',
  async () => {
    await assertFails(
      getBytes(
        storageRef(
          storage(OTHER_UID),
          CONTRACT_PATH,
        ),
      ),
    );
  },
);

test(
  'agent cannot upload or replace own contract',
  async () => {
    await assertFails(
      uploadBytes(
        storageRef(
          storage(AGENT_UID),
          CONTRACT_PATH,
        ),
        pdfBytes,
        {
          contentType: 'application/pdf',
        },
      ),
    );
  },
);

test(
  'normal user cannot delete contract',
  async () => {
    await assertFails(
      deleteObject(
        storageRef(
          storage(OTHER_UID),
          CONTRACT_PATH,
        ),
      ),
    );
  },
);

test(
  'admin role stored in Firestore can replace contract',
  async () => {
    await assertSucceeds(
      uploadBytes(
        storageRef(
          storage(SECOND_ADMIN_UID),
          CONTRACT_PATH,
        ),
        pdfBytes,
        {
          contentType: 'application/pdf',
        },
      ),
    );
  },
);

test(
  'admin cannot upload non-PDF content',
  async () => {
    await assertFails(
      uploadBytes(
        storageRef(
          storage(SECOND_ADMIN_UID),
          CONTRACT_PATH,
        ),
        new Uint8Array([1, 2, 3, 4]),
        {
          contentType: 'text/plain',
        },
      ),
    );
  },
);

test(
  'admin cannot use another filename in contract folder',
  async () => {
    await assertFails(
      uploadBytes(
        storageRef(
          storage(SECOND_ADMIN_UID),
          `agent_contracts/${AGENT_UID}/evil.pdf`,
        ),
        pdfBytes,
        {
          contentType: 'application/pdf',
        },
      ),
    );
  },
);

test(
  'admin can delete contract',
  async () => {
    await assertSucceeds(
      deleteObject(
        storageRef(
          storage(SECOND_ADMIN_UID),
          CONTRACT_PATH,
        ),
      ),
    );
  },
);
