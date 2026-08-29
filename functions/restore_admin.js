const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({
  credential: applicationDefault(),
  projectId: "barakah-new",
});

(async () => {
  const uid = "Y3YeLin9gYTbqN4if72o3iTrUSn2";

  await getFirestore()
    .collection("users")
    .doc(uid)
    .set(
      {
        role: "admin",
        driverAvailable: false,
        driverBusy: false,
        activeOrderId: null,
      },
      { merge: true }
    );

  console.log("✅ تم إرجاع ebrahimzaghal1@gmail.com إلى admin");
  process.exit(0);
})().catch((e) => {
  console.error("❌", e);
  process.exit(1);
});
