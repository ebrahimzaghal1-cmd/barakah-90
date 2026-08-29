const {
  onDocumentWritten,
  onDocumentUpdated,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp();

// يحافظ على عدّاد مبيعات كل صنف بعد تسليم الطلب، لتغذية شريط
// "الأكثر مبيعاً" بترتيب حقيقي لا يعتمد على اختيار يدوي.
exports.updateProductSalesCounters = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const wasDelivered = String(before.status || "") === "delivered";
    const isDelivered = String(after.status || "") === "delivered";
    if (wasDelivered === isDelivered) return null;

    const direction = isDelivered ? 1 : -1;
    const items = Array.isArray(after.items) ? after.items : [];
    if (!items.length) return null;

    const db = getFirestore();
    const eventId = String(event.id || `${event.params.orderId}-${isDelivered}`);
    const markerRef = db.collection("sales_counter_events").doc(eventId);

    return db.runTransaction(async (transaction) => {
      const marker = await transaction.get(markerRef);
      if (marker.exists) return;

      for (const item of items) {
        const productId = String(item?.productId || "").trim();
        if (!productId) continue;
        const quantity = Math.max(1, Number(item?.quantity || 1));
        const productRef = db.collection("items").doc(productId);
        transaction.set(productRef, {
          salesCount: FieldValue.increment(direction * quantity),
          salesUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      transaction.set(markerRef, {
        orderId: event.params.orderId,
        direction,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  },
);

exports.createSequentialOrder = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in before ordering.");
  }
  const data = request.data || {};
  const items = Array.isArray(data.items) ? data.items : [];
  const total = Number(data.total);
  if (items.length === 0 || !Number.isFinite(total) || total < 0) {
    throw new HttpsError("invalid-argument", "Invalid order data.");
  }
  const db = getFirestore();
  const businessId = String(items[0]?.businessId || "");
  let business = null;
  if (businessId) {
    const businessSnapshot = await db.collection("items").doc(businessId).get();
    if (businessSnapshot.exists) business = businessSnapshot.data();
  }
  if (!business) {
    throw new HttpsError("failed-precondition", "The restaurant is unavailable.");
  }
  const scheduledForMillis = Number(data.scheduledForMillis || 0);
  const scheduledFor = scheduledForMillis > Date.now()
    ? new Date(scheduledForMillis)
    : null;
  if (business.businessStatus === "closed" && !scheduledFor) {
    throw new HttpsError("failed-precondition", "The restaurant is closed.");
  }
  const preparationMinutes = Math.max(1, Number(business.preparationMinutes || 30));
  const counterRef = db.collection("system_counters").doc("orders");
  const orderRef = db.collection("orders").doc();
  let orderNumber;
  await db.runTransaction(async (transaction) => {
    const counter = await transaction.get(counterRef);
    const current = counter.exists ? Number(counter.data().count || 1000) : 1000;
    const next = current + 1;
    orderNumber = `BRK-${String(next).padStart(6, "0")}`;
    transaction.set(counterRef, {
      count: next,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(orderRef, {
      orderNumber,
      orderSequence: next,
      customerId: request.auth.uid,
      customerEmail: data.customerEmail || request.auth.token.email || null,
      customerPhone: data.customerPhone || request.auth.token.phone_number || null,
      items,
      total,
      deliveryMethod: String(data.deliveryMethod || "delivery"),
      paymentMethod: String(data.paymentMethod || "cash"),
      status: scheduledFor ? "scheduled" : "new",
      businessId,
      businessTitle: business.title || null,
      restaurantLatitude: Number(business.latitude),
      restaurantLongitude: Number(business.longitude),
      preparationMinutes,
      estimatedReadyAt: new Date(Date.now() + preparationMinutes * 60 * 1000),
      scheduledFor,
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  return {orderId: orderRef.id, orderNumber};
});



function orderStatusNotification(status) {
  switch (String(status || "")) {
    case "accepted":
      return {
        title: "تم قبول طلبك ✅",
        body: "المحل استلم طلبك وبدأ بتجهيزه.",
      };

    case "preparing":
      return {
        title: "طلبك قيد التحضير 👨‍🍳",
        body: "يتم تجهيز طلبك الآن.",
      };

    case "ready":
      return {
        title: "طلبك جاهز 🎉",
        body: "أصبح طلبك جاهزًا للمرحلة التالية.",
      };

    case "awaiting_driver":
      return {
        title: "بانتظار سائق 🚗",
        body: "نبحث الآن عن سائق متاح لطلبك.",
      };

    case "driver_assigned":
      return {
        title: "تم تعيين سائق 🚗",
        body: "تم تعيين سائق لتوصيل طلبك.",
      };

    case "picked_up":
      return {
        title: "طلبك مع السائق 🛵",
        body: "السائق استلم طلبك وهو في الطريق إليك.",
      };

    case "delivered":
      return {
        title: "اكتمل طلبك ✅",
        body: "تم تسليم طلبك. صحة وهنا من بركة 💛",
      };

    case "rejected":
      return {
        title: "تعذر قبول الطلب",
        body: "اعتذر المحل عن تنفيذ طلبك.",
      };

    case "cancelled":
    case "canceled":
      return {
        title: "تم إلغاء الطلب",
        body: "تم إلغاء طلبك بنجاح.",
      };

    default:
      return null;
  }
}

async function tokensForUser(db, uid) {
  if (!uid) return [];

  const snapshot = await db
    .collection("users")
    .doc(String(uid))
    .get();

  if (!snapshot.exists) return [];

  const tokens = snapshot.data()?.fcmTokens;

  if (!Array.isArray(tokens)) return [];

  return [
    ...new Set(
      tokens
        .map((value) => String(value || "").trim())
        .filter(Boolean),
    ),
  ];
}

async function sendPushToTokens(tokens, notification, data = {}) {
  if (!tokens.length || !notification) return;

  const messaging = getMessaging();

  for (let start = 0; start < tokens.length; start += 500) {
    const chunk = tokens.slice(start, start + 500);

    const response = await messaging.sendEachForMulticast({
      tokens: chunk,

      notification,

      data: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [
          key,
          String(value ?? ""),
        ]),
      ),

      android: {
        priority: "high",
      },

      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
        headers: {
          "apns-priority": "10",
        },
      },

      webpush: {
        notification: {
          icon: "/icons/Icon-192.png",
          badge: "/icons/Icon-192.png",
        },
        fcmOptions: {
          link: "/",
        },
      },
    });

    response.responses.forEach((result, index) => {
      if (!result.success) {
        console.error(
          "Push failed",
          chunk[index],
          result.error?.code,
          result.error?.message,
        );
      }
    });
  }
}

exports.notifyCustomerOnOrderStatus = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};

    if (before.status === after.status) return;

    const notification = orderStatusNotification(after.status);

    if (!notification) return;

    const db = getFirestore();

    const tokens = await tokensForUser(
      db,
      after.customerId,
    );

    await sendPushToTokens(
      tokens,
      notification,
      {
        type: "order_status",
        orderId: event.params.orderId,
        orderNumber: after.orderNumber || "",
        status: after.status || "",
      },
    );
  },
);

exports.notifyAdminsOnNewOrder = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const order = event.data?.data() || {};

    const db = getFirestore();

    const adminDocs = new Map();

    const [roleAdmins, flagAdmins] = await Promise.all([
      db.collection("users")
        .where("role", "==", "admin")
        .get(),

      db.collection("users")
        .where("isAdmin", "==", true)
        .get(),
    ]);

    for (const doc of [
      ...roleAdmins.docs,
      ...flagAdmins.docs,
    ]) {
      adminDocs.set(doc.id, doc);
    }

    const tokens = [
      ...new Set(
        [...adminDocs.values()]
          .flatMap((doc) => {
            const raw = doc.data()?.fcmTokens;

            return Array.isArray(raw)
              ? raw.map(
                  (value) =>
                    String(value || "").trim(),
                )
              : [];
          })
          .filter(Boolean),
      ),
    ];

    await sendPushToTokens(
      tokens,
      {
        title: "يوجد طلب جديد 🛍️",
        body:
          `طلب ${
            order.orderNumber || event.params.orderId
          } بانتظار المتابعة.`,
      },
      {
        type: "new_order",
        orderId: event.params.orderId,
        orderNumber: order.orderNumber || "",
        status: order.status || "new",
      },
    );
  },
);

// عند إنشاء أي طلب، ينسخ الخادم بيانات التوصيل الحالية من ملف الزبون
// إلى الطلب نفسه حتى تظهر للسائق المعيّن فقط.
exports.attachCustomerDeliveryProfile = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const orderSnapshot = event.data;
    if (!orderSnapshot || !orderSnapshot.exists) return;

    const order = orderSnapshot.data() || {};
    const customerId = String(order.customerId || "").trim();

    if (!customerId) return;

    const db = getFirestore();
    const userSnapshot = await db.collection("users").doc(customerId).get();

    if (!userSnapshot.exists) return;

    const user = userSnapshot.data() || {};

    const customerName =
      user.displayName ||
      user.fullName ||
      user.name ||
      order.customerName ||
      null;

    const customerPhone =
      user.phone ||
      order.customerPhone ||
      null;

    const deliveryAddress =
      user.address ||
      order.deliveryAddress ||
      null;

    const latitude = Number(user.agentLatitude);
    const longitude = Number(user.agentLongitude);

    const patch = {
      customerName,
      customerPhone,
      deliveryAddress,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (Number.isFinite(latitude)) {
      patch.deliveryLatitude = latitude;
    }

    if (Number.isFinite(longitude)) {
      patch.deliveryLongitude = longitude;
    }

    await orderSnapshot.ref.set(patch, {merge: true});
  },
);

// كل طلب فعّال يفتح ثلاث مهام. كل مهمة تُحتسب مرة واحدة وتمنح نقطتين.

function distanceKm(lat1, lon1, lat2, lon2) {
  const toRad = (value) => value * Math.PI / 180;
  const earthRadiusKm = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// عند جاهزية الطلب يحجز الخادم أقرب سائق متاح بصورة ذرية.
// وعند التسليم يمنح الزبون نقاطًا حسب قيمة الطلب وإعدادات الولاء ويعيد السائق إلى حالة متاح.
exports.coordinateDelivery = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const orderRef = event.data.after.ref;
  const db = getFirestore();

  if (before.status !== "ready" && after.status === "ready" && !after.driverId) {
    const restaurantLat = Number(after.restaurantLatitude);
    const restaurantLon = Number(after.restaurantLongitude);
    if (Number.isFinite(restaurantLat) && Number.isFinite(restaurantLon)) {
      const driverSnapshot = await db.collection("users")
        .where("role", "==", "driver").get();
      const candidates = driverSnapshot.docs
        .map((doc) => ({doc, data: doc.data()}))
        .filter(({data}) => data.driverAvailable === true &&
          Number.isFinite(Number(data.driverLatitude)) &&
          Number.isFinite(Number(data.driverLongitude)))
        .map(({doc, data}) => ({
          doc,
          data,
          distance: distanceKm(restaurantLat, restaurantLon,
            Number(data.driverLatitude), Number(data.driverLongitude)),
        }))
        .sort((a, b) => a.distance - b.distance);
      for (const candidate of candidates) {
        const assigned = await db.runTransaction(async (transaction) => {
          const [freshOrder, freshDriver] = await Promise.all([
            transaction.get(orderRef),
            transaction.get(candidate.doc.ref),
          ]);
          if (!freshOrder.exists || freshOrder.data().driverId ||
              freshOrder.data().status !== "ready" ||
              !freshDriver.exists || freshDriver.data().driverAvailable !== true) {
            return false;
          }
          transaction.update(orderRef, {
            driverId: candidate.doc.id,
            driverName: candidate.data.displayName || candidate.data.email || "سائق بركة",
            driverPhone: candidate.data.driverPhone || candidate.data.phone || null,
            driverDistanceKm: candidate.distance,
            status: "driver_assigned",
            assignedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          transaction.update(candidate.doc.ref, {
            driverAvailable: false,
            driverBusy: true,
            activeOrderId: orderRef.id,
          });
          return true;
        });
        if (assigned) break;
      }
    }
  }

  if (before.status !== "delivered" && after.status === "delivered") {
    await db.runTransaction(async (transaction) => {
      const freshOrder = await transaction.get(orderRef);
      if (!freshOrder.exists || freshOrder.data().rewardGranted === true) return;
      const order = freshOrder.data();
      const userRef = db.collection("users").doc(order.customerId);
      const settingsRef = db.collection("app_settings").doc("loyalty");
      const [userSnapshot, settingsSnapshot] = await Promise.all([
        transaction.get(userRef),
        transaction.get(settingsRef),
      ]);
      const oldPoints = Number(userSnapshot.data()?.loyaltyPoints || 0);
      const orderTotal = Math.max(0, Number(
        order.total ?? order.grandTotal ?? order.orderTotal ?? order.amount ?? 0,
      ));
      const pointsPerShekel = Math.max(1,
        Number(settingsSnapshot.data()?.pointsPerShekel || 2));
      const earnedPoints = Math.round(orderTotal * pointsPerShekel);
      const newPoints = oldPoints + earnedPoints;
      const pointsPerCoupon = Math.max(1,
        Number(settingsSnapshot.data()?.pointsPerCoupon || 100));
      const discountPercent = Math.min(100, Math.max(1,
        Number(settingsSnapshot.data()?.discountPercent || 10)));
      transaction.set(userRef, {
        loyaltyPoints: newPoints,
        completedPurchases: FieldValue.increment(1),
      }, {merge: true});
      transaction.update(orderRef, {
        rewardGranted: true,
        rewardGrantedAt: FieldValue.serverTimestamp(),
        loyaltyPointsAwarded: earnedPoints,
        loyaltyPointsPerShekel: pointsPerShekel,
        loyaltyRewardOrderTotal: orderTotal,
      });
      if (Math.floor(newPoints / pointsPerCoupon) >
          Math.floor(oldPoints / pointsPerCoupon)) {
        const couponRef = db.collection("coupons").doc();
        transaction.set(couponRef, {
          customerId: order.customerId,
          code: `BARAKAH-${couponRef.id.substring(0, 6).toUpperCase()}`,
          discountPercent,
          pointsRequired: pointsPerCoupon,
          status: "active",
          source: "loyalty",
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      if (order.driverId) {
        transaction.set(db.collection("users").doc(order.driverId), {
          driverAvailable: true,
          driverBusy: false,
          activeOrderId: null,
        }, {merge: true});
      }
    });
  }
});

exports.aggregateBusinessRating = onDocumentWritten(
  "business_ratings/{businessId}/votes/{userId}",
  async (event) => {
    const businessId = event.params.businessId;
    const db = getFirestore();
    const votes = await db.collection("business_ratings")
      .doc(businessId).collection("votes").get();
    const values = votes.docs
      .map((doc) => Number(doc.data().value))
      .filter((value) => value >= 1 && value <= 5);
    const count = values.length;
    const average = count === 0
      ? 0
      : values.reduce((sum, value) => sum + value, 0) / count;
    await db.collection("rating_summaries").doc(businessId).set({
      average,
      count,
      updatedAt: FieldValue.serverTimestamp(),
    });
    const itemRef = db.collection("items").doc(businessId);
    const item = await itemRef.get();
    if (item.exists) {
      await itemRef.set({
        rating: average,
        ratingCount: count,
        // أربعة نجوم فأعلى ينقل المحل تلقائيًا إلى الترندات.
        isTrending: item.data().kind !== "product" && count > 0 && average >= 4,
      }, {merge: true});
    }
  },
);
