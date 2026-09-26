// Run with an authorized application-default credential. Never prints private fields.
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const cliPath = process.env.FIREBASE_CLI_LIB;
const credential = cliPath ? {getAccessToken: async () => {
  const auth = require(`${cliPath}/auth`);
  const account = auth.getProjectDefaultAccount(process.cwd());
  if (!account?.tokens?.refresh_token) throw new Error('Firebase CLI login required');
  const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  if (!token?.access_token) throw new Error('Could not refresh Firebase authorization');
  return {access_token: token.access_token, expires_in: 3600};
}} : applicationDefault();
initializeApp({projectId: 'barakah-new', credential});
(async () => {
  const db = getFirestore();
  const agents = await db.collection('items').where('kind', '==', 'agent').get();
  let count = 0;
  for (const doc of agents.docs) {
    await db.runTransaction(async tx => {
      const fresh = (await tx.get(doc.ref)).data();
      const privateFields = ['agentPhone','phone','phoneNumber','whatsappUrl','ownerEmail'];
      const secret = Object.fromEntries(privateFields.filter(k => fresh[k] != null).map(k => [k, fresh[k]]));
      if (!Object.keys(secret).length) return;
      tx.set(db.doc(`mediator_private/${doc.id}`), {...secret, ...(fresh.agentPhone ? {phone: fresh.agentPhone} : {}), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
      tx.update(doc.ref, Object.fromEntries(privateFields.map(k => [k, FieldValue.delete()])));
    });
    count++;
  }
  console.log(`Privacy migration checked ${count} mediator records.`);
})().catch(e => {console.error(e.message); process.exitCode = 1;});
