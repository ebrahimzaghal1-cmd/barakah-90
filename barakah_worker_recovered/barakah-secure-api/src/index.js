var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.js
var JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
var MAX_ITEMS = 50;
var index_default = {
  async fetch(request, env) {
    const cors = corsHeaders(request, env);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        return json({ ok: true, service: "barakah-secure-api" }, 200, cors);
      }
      if (request.method === "POST" && url.pathname === "/v1/partner-applications") {
        return json(
          await createPartnerApplication(request, env),
          201,
          cors
        );
      }
      const user = await authenticate(request, env);
      if (request.method === "POST" && url.pathname === "/v1/support/messages") {
        return json(await sendSupportMessage(request, env, user), 201, cors);
      }
      if (request.method === "POST" && url.pathname === "/v1/admin/new-request") {
        return json(
          await notifyAdminsAboutVerifiedRequest(request, env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/media/upload-auth") {
        return json(
          await createImageKitUploadAuth(env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/recover-admin") {
        const allowedUid = "Y3YeLin9gYTbqN4if72o3iTrUSn2";
        const allowedEmail = "ebrahimzaghal1@gmail.com";
        if (user.uid !== allowedUid || String(user.email || "").toLowerCase() !== allowedEmail) {
          fail(403, "permission-denied", "\u063A\u064A\u0631 \u0645\u0633\u0645\u0648\u062D.");
        }
        const token = await serviceToken(env);
        const current = await firestoreGet(
          env,
          token,
          `users/${encodeURIComponent(user.uid)}`
        );
        if (!current) {
          fail(404, "user-not-found", "\u062D\u0633\u0627\u0628 \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F.");
        }
        const result = await firestoreCommit(env, token, [
          updateWrite(
            env,
            `users/${encodeURIComponent(user.uid)}`,
            {
              role: "admin",
              driverAvailable: false,
              driverBusy: false,
              activeOrderId: null,
              updatedAt: /* @__PURE__ */ new Date()
            },
            current.updateTime
          )
        ]);
        if (!result) {
          fail(409, "user-changed", "\u062A\u063A\u064A\u0651\u0631\u062A \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u062D\u0633\u0627\u0628. \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627.");
        }
        return json(
          {
            ok: true,
            uid: user.uid,
            role: "admin"
          },
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/account/delete") {
        return json(
          await deleteCurrentAccount(env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/admin/account/delete") {
        const body = await readJson(request);
        const targetUid = String(body?.userId || "").trim();

        if (!targetUid) {
          fail(400, "missing-user-id", "معرّف المستخدم مطلوب.");
        }

        const token = await serviceToken(env);
        const actor = await firestoreGet(
          env,
          token,
          `users/${encodeURIComponent(user.uid)}`
        );

        if (actor?.role !== "admin") {
          fail(403, "permission-denied", "غير مسموح بتنفيذ حذف الحسابات.");
        }

        const deletionRequest = await firestoreGet(
          env,
          token,
          `account_deletion_requests/${encodeURIComponent(targetUid)}`
        );

        if (
          !deletionRequest ||
          deletionRequest.userId !== targetUid ||
          deletionRequest.status !== "pending"
        ) {
          fail(
            409,
            "deletion-request-not-pending",
            "لا يوجد طلب حذف معلّق لهذا الحساب."
          );
        }

        return json(
          await deleteCurrentAccount(env, user, targetUid, true),
          200,
          cors
        );
      }

      if (request.method === "POST" && url.pathname === "/v1/barakah-card/reset-pin") {
        return json(
          await resetBarakahPin(request, env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/barakah-card/change-pin") {
        return json(
          await changeBarakahPin(request, env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/merchant/products") {
        return json(
          await createMerchantProduct(request, env, user),
          201,
          cors
        );
      }
      const merchantProductUpdateMatch = url.pathname.match(
        /^\/v1\/merchant\/products\/([^/]+)\/update$/
      );
      if (request.method === "POST" && merchantProductUpdateMatch) {
        return json(
          await updateMerchantProduct(
            request,
            env,
            user,
            decodeURIComponent(merchantProductUpdateMatch[1])
          ),
          200,
          cors
        );
      }
      const merchantProductDeleteMatch = url.pathname.match(
        /^\/v1\/merchant\/products\/([^/]+)\/delete$/
      );
      if (request.method === "POST" && merchantProductDeleteMatch) {
        return json(
          await deleteMerchantProduct(
            env,
            user,
            decodeURIComponent(merchantProductDeleteMatch[1])
          ),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/orders") {
        return json(await createOrder(request, env, user), 201, cors);
      }
      if (request.method === "GET" && url.pathname === "/v1/driver/orders/available") {
        return json(
          await listAvailableDriverOrders(env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/driver/availability") {
        return json(
          await setDriverAvailability(request, env, user),
          200,
          cors
        );
      }
      const claimDriverMatch = url.pathname.match(
        /^\/v1\/orders\/([^/]+)\/claim-driver$/
      );
      if (request.method === "POST" && claimDriverMatch) {
        return json(
          await claimDriverOrder(
            env,
            user,
            decodeURIComponent(claimDriverMatch[1])
          ),
          200,
          cors
        );
      }
      const statusMatch = url.pathname.match(/^\/v1\/orders\/([^/]+)\/status$/);
      if (request.method === "POST" && statusMatch) {
        return json(await updateOrderStatus(
          request,
          env,
          user,
          decodeURIComponent(statusMatch[1])
        ), 200, cors);
      }
      const cancelOrderMatch = url.pathname.match(
        /^\/v1\/orders\/([^/]+)\/cancel$/
      );
      if (request.method === "POST" && cancelOrderMatch) {
        return json(
          await cancelCustomerOrder(
            env,
            user,
            decodeURIComponent(cancelOrderMatch[1])
          ),
          200,
          cors
        );
      }
      const playSessionMatch = url.pathname.match(
        /^\/v1\/orders\/([^/]+)\/play-sessions\/([^/]+)$/
      );
      if (request.method === "POST" && playSessionMatch) {
        return json(await startPlayTask(
          request,
          env,
          user,
          decodeURIComponent(playSessionMatch[1]),
          decodeURIComponent(playSessionMatch[2])
        ), 200, cors);
      }
      const playRewardMatch = url.pathname.match(
        /^\/v1\/orders\/([^/]+)\/play-rewards\/([^/]+)$/
      );
      if (request.method === "POST" && playRewardMatch) {
        return json(await claimPlayTask(
          request,
          env,
          user,
          decodeURIComponent(playRewardMatch[1]),
          decodeURIComponent(playRewardMatch[2])
        ), 200, cors);
      }
      return json({ error: "not-found" }, 404, cors);
    } catch (error) {
      const status = Number(error.status || 500);
      if (status >= 500) console.error("request_failed", error.message);
      return json({
        error: error.code || "server-error",
        message: status >= 500 ? "\u062A\u0639\u0630\u0631 \u062A\u0646\u0641\u064A\u0630 \u0627\u0644\u0639\u0645\u0644\u064A\u0629 \u0627\u0644\u0622\u0646." : error.message
      }, status, cors);
    }
  }
};
function json(value, status = 200, extra = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...JSON_HEADERS, ...extra }
  });
}
__name(json, "json");
function corsHeaders(request, env) {
  const origin = request.headers.get("origin");
  const allowed = String(env.ALLOWED_ORIGINS || "").split(",").map((value) => value.trim()).filter(Boolean);
  const isLocalDevelopment = origin && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
  if (!origin || !allowed.includes(origin) && !isLocalDevelopment) {
    return {};
  }
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "authorization,content-type,idempotency-key",
    "access-control-max-age": "86400",
    "vary": "Origin"
  };
}
__name(corsHeaders, "corsHeaders");
function fail(status, code, message) {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  throw error;
}
__name(fail, "fail");
async function readJson(request) {
  const length = Number(request.headers.get("content-length") || 0);
  if (length > 128e3) fail(413, "payload-too-large", "\u0627\u0644\u0637\u0644\u0628 \u0643\u0628\u064A\u0631 \u062C\u062F\u064B\u0627.");
  try {
    return await request.json();
  } catch (_) {
    fail(400, "invalid-json", "\u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0635\u062D\u064A\u062D\u0629.");
  }
}
__name(readJson, "readJson");
async function authenticate(request, env) {
  const header = request.headers.get("authorization") || "";
  if (!header.startsWith("Bearer ")) fail(401, "unauthenticated", "\u0633\u062C\u0651\u0644 \u0627\u0644\u062F\u062E\u0648\u0644 \u0623\u0648\u0644\u064B\u0627.");
  const idToken = header.substring(7).trim();
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`,
    { method: "POST", headers: JSON_HEADERS, body: JSON.stringify({ idToken }) }
  );
  if (!response.ok) fail(401, "invalid-token", "\u0627\u0646\u062A\u0647\u062A \u062C\u0644\u0633\u0629 \u0627\u0644\u062F\u062E\u0648\u0644. \u0627\u062F\u062E\u0644 \u0645\u062C\u062F\u062F\u064B\u0627.");
  const result = await response.json();
  const account = result.users?.[0];
  if (!account?.localId) fail(401, "invalid-token", "\u062C\u0644\u0633\u0629 \u0627\u0644\u062F\u062E\u0648\u0644 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D\u0629.");
  let authTime = 0;
  try {
    const payloadPart = idToken.split(".")[1] || "";
    const padded = payloadPart.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(payloadPart.length / 4) * 4, "=");
    const payload = JSON.parse(atob(padded));
    authTime = Number(payload.auth_time || 0);
  } catch (_) {
    authTime = 0;
  }
  return {
    uid: account.localId,
    email: account.email || null,
    phone: account.phoneNumber || null,
    authTime,
    idToken
  };
}
__name(authenticate, "authenticate");
async function serviceToken(env) {
  if (!env.FIREBASE_CLIENT_EMAIL || !env.FIREBASE_PRIVATE_KEY) {
    fail(503, "service-not-configured", "\u0627\u0644\u062E\u062F\u0645\u0629 \u0627\u0644\u0622\u0645\u0646\u0629 \u0644\u0645 \u062A\u064F\u0631\u0628\u0637 \u0628\u0642\u0627\u0639\u062F\u0629 \u0627\u0644\u0628\u064A\u0627\u0646\u0627\u062A \u0628\u0639\u062F.");
  }
  const now = Math.floor(Date.now() / 1e3);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64url(JSON.stringify({
    iss: env.FIREBASE_CLIENT_EMAIL,
    sub: env.FIREBASE_CLIENT_EMAIL,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/identitytoolkit"
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(env.FIREBASE_PRIVATE_KEY),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claim}`)
  );
  const assertion = `${header}.${claim}.${base64url(signature)}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion
    })
  });
  if (!response.ok) fail(503, "firebase-auth-failed", "\u062A\u0639\u0630\u0631 \u0627\u0644\u0627\u062A\u0635\u0627\u0644 \u0627\u0644\u0622\u0645\u0646 \u0628\u0642\u0627\u0639\u062F\u0629 \u0627\u0644\u0628\u064A\u0627\u0646\u0627\u062A.");
  return (await response.json()).access_token;
}
__name(serviceToken, "serviceToken");
function pemBytes(pem) {
  const raw = String(pem).replace(/\\n/g, "\n").replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const binary = atob(raw);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}
__name(pemBytes, "pemBytes");
function base64url(value) {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : new Uint8Array(value);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}
__name(base64url, "base64url");
function firestoreBase(env) {
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/databases/(default)/documents`;
}
__name(firestoreBase, "firestoreBase");
async function firestoreGet(env, token, path) {
  const response = await fetch(`${firestoreBase(env)}/${path}`, {
    headers: { authorization: `Bearer ${token}` }
  });
  if (response.status === 404) return null;
  if (!response.ok) fail(502, "firestore-read-failed", "\u062A\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0628\u064A\u0627\u0646\u0627\u062A.");
  return decodeDocument(await response.json());
}
__name(firestoreGet, "firestoreGet");
async function createImageKitUploadAuth(env, user) {
  if (!env.IMAGEKIT_PRIVATE_KEY || !env.IMAGEKIT_PUBLIC_KEY) {
    fail(503, "media-not-configured", "خدمة رفع الصور غير مهيأة بعد.");
  }
  const serviceAccessToken = await serviceToken(env);
  const actor = await firestoreGet(
    env,
    serviceAccessToken,
    `users/${encodeURIComponent(user.uid)}`
  );
  if (!canUploadMedia(actor)) {
    fail(403, "permission-denied", "غير مسموح لهذا الحساب برفع الصور.");
  }
  const uploadToken = crypto.randomUUID();
  const expire = Math.floor(Date.now() / 1e3) + 30 * 60;
  const signature = await createImageKitSignature(
    env.IMAGEKIT_PRIVATE_KEY,
    uploadToken,
    expire
  );
  return {
    token: uploadToken,
    expire,
    signature,
    publicKey: env.IMAGEKIT_PUBLIC_KEY
  };
}
__name(createImageKitUploadAuth, "createImageKitUploadAuth");
function canUploadMedia(actor) {
  // يتطلب المزاد رفع الصور من الزبائن أيضاً، لذلك نسمح لأي حساب مسجل
  // يملك ملف مستخدم ودوراً معروفاً، لا للأدمن والتاجر فقط.
  return !!actor && typeof actor === "object" && typeof actor.role === "string" && actor.role.trim().length > 0;
}
__name(canUploadMedia, "canUploadMedia");
async function createImageKitSignature(privateKey, token, expire) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(privateKey),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${token}${expire}`)
  );
  const signature = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return signature;
}
__name(createImageKitSignature, "createImageKitSignature");
async function firestoreCreate(env, token, collection, documentId, data) {
  const url = `${firestoreBase(env)}/${collection}?documentId=${encodeURIComponent(documentId)}`;
  const response = await fetch(url, {
    method: "POST",
    headers: { ...JSON_HEADERS, authorization: `Bearer ${token}` },
    body: JSON.stringify({ fields: encodeFields(data) })
  });
  if (!response.ok) fail(502, "firestore-write-failed", "\u062A\u0639\u0630\u0631 \u062D\u0641\u0638 \u0627\u0644\u0637\u0644\u0628.");
  return decodeDocument(await response.json());
}
__name(firestoreCreate, "firestoreCreate");
async function firestoreCommit(env, token, writes) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: { ...JSON_HEADERS, authorization: `Bearer ${token}` },
      body: JSON.stringify({ writes })
    }
  );
  const responseText = await response.text();
  if (response.status === 409 || response.status === 412) {
    console.error(
      "firestore_commit_conflict",
      response.status,
      responseText
    );
    return null;
  }
  if (!response.ok) {
    console.error(
      "firestore_commit_failed",
      response.status,
      responseText,
      JSON.stringify(writes)
    );
    fail(
      502,
      "firestore-write-failed",
      "\u062A\u0639\u0630\u0631 \u062A\u062D\u062F\u064A\u062B \u0627\u0644\u0637\u0644\u0628."
    );
  }
  return responseText ? JSON.parse(responseText) : {};
}
__name(firestoreCommit, "firestoreCommit");
async function firestoreQuery(env, token, collectionId, filters = []) {
  const where = filters.length === 1 ? filters[0] : {
    compositeFilter: { op: "AND", filters }
  };
  const response = await fetch(`${firestoreBase(env)}:runQuery`, {
    method: "POST",
    headers: { ...JSON_HEADERS, authorization: `Bearer ${token}` },
    body: JSON.stringify({ structuredQuery: {
      from: [{ collectionId }],
      where,
      limit: 100
    } })
  });
  if (!response.ok) fail(502, "firestore-query-failed", "\u062A\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0628\u064A\u0627\u0646\u0627\u062A.");
  const rows = await response.json();
  return rows.filter((row) => row.document).map((row) => decodeDocument(row.document));
}
__name(firestoreQuery, "firestoreQuery");
function fieldEquals(fieldPath, value) {
  return { fieldFilter: { field: { fieldPath }, op: "EQUAL", value: encodeValue(value) } };
}
__name(fieldEquals, "fieldEquals");
async function sendPushToTokens(env, token, deviceTokens, { title, body, data = {} }) {
  const uniqueTokens = [...new Set((deviceTokens || []).filter((value) => typeof value === "string" && value.length > 20))];
  if (!uniqueTokens.length) return;
  await Promise.all(
    uniqueTokens.slice(0, 100).map(async (deviceToken) => {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/messages:send`,
        {
          method: "POST",
          headers: {
            ...JSON_HEADERS,
            authorization: `Bearer ${token}`
          },
          body: JSON.stringify({
            message: {
              token: deviceToken,
              notification: {
                title,
                body
              },
              data,
              android: {
                priority: "HIGH",
                notification: {
                  sound: "default",
                  channel_id: "barakah_orders"
                }
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1
                  }
                }
              },
              webpush: {
                notification: {
                  icon: "/icons/Icon-192.png",
                  badge: "/icons/Icon-192.png",
                  dir: "rtl",
                  lang: "ar"
                },
                fcm_options: {
                  link: "https://barakah-new.web.app/"
                }
              }
            }
          })
        }
      );
      if (!response.ok) {
        console.error(
          "push_notification_failed",
          response.status,
          (await response.text()).substring(0, 300)
        );
      }
    })
  );
}
__name(sendPushToTokens, "sendPushToTokens");
async function userPushTokens(env, token, uid) {
  if (!uid) return [];
  const profile = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(uid)}`
  );
  return Array.isArray(profile?.fcmTokens) ? profile.fcmTokens : [];
}
__name(userPushTokens, "userPushTokens");
async function notifyCustomerOrderStatus(env, token, order, orderId, status) {
  const labels = {
    accepted: "\u062A\u0645 \u0642\u0628\u0648\u0644 \u0637\u0644\u0628\u0643 \u2705",
    preparing: "\u0628\u062F\u0623 \u062A\u062C\u0647\u064A\u0632 \u0637\u0644\u0628\u0643 \u{1F468}\u200D\u{1F373}",
    ready: "\u0637\u0644\u0628\u0643 \u0623\u0635\u0628\u062D \u062C\u0627\u0647\u0632\u064B\u0627 \u{1F4E6}",
    driver_assigned: "\u062A\u0645 \u062A\u0639\u064A\u064A\u0646 \u0633\u0627\u0626\u0642 \u0644\u0637\u0644\u0628\u0643 \u{1F697}",
    picked_up: "\u0637\u0644\u0628\u0643 \u0641\u064A \u0627\u0644\u0637\u0631\u064A\u0642 \u0625\u0644\u064A\u0643 \u{1F6F5}",
    delivered: "\u062A\u0645 \u062A\u0633\u0644\u064A\u0645 \u0637\u0644\u0628\u0643 \u0628\u0646\u062C\u0627\u062D \u{1F389}",
    rejected: "\u062A\u0645 \u0631\u0641\u0636 \u0627\u0644\u0637\u0644\u0628"
  };
  const title = labels[status];
  if (!title || !order?.customerId) return;
  const orderLabel = String(
    order.orderNumber || orderId.substring(0, 6).toUpperCase()
  );
  const tokens = await userPushTokens(
    env,
    token,
    order.customerId
  );
  await sendPushToTokens(
    env,
    token,
    tokens,
    {
      title,
      body: `\u0637\u0644\u0628 \u0628\u0631\u0643\u0629 #${orderLabel}`,
      data: {
        type: "order_status",
        orderId,
        orderNumber: orderLabel,
        status
      }
    }
  );
}
__name(notifyCustomerOrderStatus, "notifyCustomerOrderStatus");
async function notifyAdminsAboutOrder(env, token, orderId, order) {
  const admins = await firestoreQuery(
    env,
    token,
    "users",
    [fieldEquals("role", "admin")]
  );
  const adminTokens = admins.flatMap(
    (admin) => Array.isArray(admin.fcmTokens) ? admin.fcmTokens : []
  );
  let merchantTokens = [];
  if (order.businessId) {
    const business = await firestoreGet(
      env,
      token,
      `items/${encodeURIComponent(order.businessId)}`
    );
    if (business?.ownerId) {
      merchantTokens = await userPushTokens(
        env,
        token,
        business.ownerId
      );
    }
  }
  const orderLabel = String(
    order.orderNumber || orderId.substring(0, 6).toUpperCase()
  );
  await sendPushToTokens(
    env,
    token,
    [
      ...adminTokens,
      ...merchantTokens
    ],
    {
      title: "\u0637\u0644\u0628 \u062C\u062F\u064A\u062F \u0641\u064A \u0628\u0631\u0643\u0629",
      body: `\u0627\u0644\u0637\u0644\u0628 #${orderLabel} \u0645\u0646 ${order.businessTitle || "\u0623\u062D\u062F \u0627\u0644\u0645\u062D\u0644\u0627\u062A"} \u0628\u0642\u064A\u0645\u0629 ${order.total} \u20AA`,
      data: {
        type: "new_order",
        orderId,
        orderNumber: orderLabel
      }
    }
  );
}
__name(notifyAdminsAboutOrder, "notifyAdminsAboutOrder");
async function createPartnerApplication(request, env) {
  const data = await readJson(request);
  const required = [
    "businessName",
    "ownerName",
    "email",
    "phone",
    "activityType",
    "businessCategory",
    "area"
  ];
  for (const field of required) {
    if (!String(data?.[field] || "").trim()) {
      fail(400, "missing-field", "بيانات طلب الشريك غير مكتملة.");
    }
  }
  const latitude = Number(data.latitude);
  const longitude = Number(data.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    fail(400, "invalid-location", "موقع المحل غير صالح.");
  }
  if (data.acceptedPartnerAgreement !== true || data.acceptedPrivacyPolicy !== true) {
    fail(400, "agreements-required", "يجب قبول الاتفاقية وسياسة الخصوصية.");
  }

  const text = (value, limit = 500) => String(value || "").trim().slice(0, limit);
  const applicationId = crypto.randomUUID().replace(/-/g, "");
  const token = await serviceToken(env);
  const record = {
    businessName: text(data.businessName, 120),
    ownerName: text(data.ownerName, 120),
    email: text(data.email, 180),
    phone: text(data.phone, 40),
    nationalId: text(data.nationalId, 80),
    activityType: text(data.activityType, 80),
    businessCategory: text(data.businessCategory, 120),
    area: text(data.area, 160),
    description: text(data.description, 1500),
    locationUrl: text(data.locationUrl, 500),
    latitude,
    longitude,
    payoutOwnerName: text(data.payoutOwnerName, 120),
    payoutMethod: text(data.payoutMethod, 80),
    payoutAccount: text(data.payoutAccount, 180),
    identityDocumentRef: text(data.identityDocumentRef, 500),
    businessDocumentRef: text(data.businessDocumentRef, 500),
    payoutDocumentRef: text(data.payoutDocumentRef, 500),
    commissionRate: 10,
    commissionAppliesTo: "products_only",
    subscriptionFee: 0,
    acceptedPartnerAgreement: true,
    acceptedPrivacyPolicy: true,
    agreementVersion: text(data.agreementVersion, 80),
    agreementAcceptedAt: new Date(),
    identityVerified: false,
    businessVerified: false,
    payoutVerified: false,
    merchantEnabled: false,
    status: "pending",
    source: "partner_web",
    createdAt: new Date(),
    updatedAt: new Date()
  };
  await firestoreCreate(
    env,
    token,
    "merchant_applications",
    applicationId,
    record
  );

  const [roleAdmins, flagAdmins] = await Promise.all([
    firestoreQuery(env, token, "users", [fieldEquals("role", "admin")]),
    firestoreQuery(env, token, "users", [fieldEquals("isAdmin", true)])
  ]);
  const adminTokens = [...roleAdmins, ...flagAdmins].flatMap(
    (admin) => Array.isArray(admin.fcmTokens) ? admin.fcmTokens : []
  );
  await sendPushToTokens(env, token, adminTokens, {
    title: "طلب انضمام شريك جديد 🤝",
    body: `${record.businessName} بانتظار المراجعة.`,
    data: {
      type: "partner_application",
      applicationId
    }
  });
  return { applicationId, status: "pending" };
}
__name(createPartnerApplication, "createPartnerApplication");
async function adminPushTokens(env, token) {
  const [roleAdmins, flagAdmins] = await Promise.all([
    firestoreQuery(env, token, "users", [fieldEquals("role", "admin")]),
    firestoreQuery(env, token, "users", [fieldEquals("isAdmin", true)])
  ]);
  return [...roleAdmins, ...flagAdmins].flatMap(
    (admin) => Array.isArray(admin.fcmTokens) ? admin.fcmTokens : []
  );
}
__name(adminPushTokens, "adminPushTokens");
async function notifyAdminsAboutVerifiedRequest(request, env, user) {
  const body = await readJson(request);
  const requestType = String(body?.type || "").trim();
  const documentId = String(body?.documentId || "").trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(documentId)) {
    fail(400, "invalid-request-id", "معرّف الطلب غير صالح.");
  }
  const definitions = {
    auction_request: {
      collection: "auction_requests",
      title: "طلب مزاد جديد 🔨",
      label: (record) => record.itemName || "إعلان مزاد جديد"
    },
    driver_application: {
      collection: "driver_applications",
      title: "طلب انضمام سائق جديد 🚗",
      label: (record) => record.fullName || "متقدم جديد"
    },
    customer_service_application: {
      collection: "customer_service_applications",
      title: "طلب توظيف خدمة عملاء جديد 🎧",
      label: (record) => record.fullName || "متقدم جديد"
    },
    account_deletion_request: {
      collection: "account_deletion_requests",
      title: "طلب حذف حساب جديد",
      label: (record) => record.email || "أحد المستخدمين"
    }
  };
  const definition = definitions[requestType];
  if (!definition) {
    fail(400, "invalid-request-type", "نوع الطلب غير مدعوم.");
  }
  const token = await serviceToken(env);
  const record = await firestoreGet(
    env,
    token,
    `${definition.collection}/${encodeURIComponent(documentId)}`
  );
  if (!record || record.userId !== user.uid || record.status !== "pending") {
    fail(403, "request-not-owned", "تعذر التحقق من الطلب الجديد.");
  }
  const tokens = await adminPushTokens(env, token);
  await sendPushToTokens(env, token, tokens, {
    title: definition.title,
    body: `${String(definition.label(record)).slice(0, 160)} بانتظار المراجعة.`,
    data: {
      type: requestType,
      documentId
    }
  });
  return { ok: true, type: requestType, documentId };
}
__name(notifyAdminsAboutVerifiedRequest, "notifyAdminsAboutVerifiedRequest");
async function sendSupportMessage(request, env, user) {
  const body = await readJson(request);
  const threadId = String(body?.threadId || "").trim();
  const message = String(body?.text || "").trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(threadId)) {
    fail(400, "invalid-thread", "محادثة خدمة العملاء غير صالحة.");
  }
  if (!message || message.length > 4e3) {
    fail(400, "invalid-message", "الرسالة فارغة أو طويلة جدًا.");
  }
  const token = await serviceToken(env);
  const [thread, actor] = await Promise.all([
    firestoreGet(env, token, `support_threads/${encodeURIComponent(threadId)}`),
    firestoreGet(env, token, `users/${encodeURIComponent(user.uid)}`)
  ]);
  if (!thread || !actor) {
    fail(404, "support-thread-not-found", "محادثة خدمة العملاء غير موجودة.");
  }
  let senderRole;
  let senderName;
  let recipientTokens = [];
  let notificationTitle;
  if (thread.customerId === user.uid) {
    senderRole = "customer";
    senderName = String(actor.displayName || thread.customerName || "عميل بركة");
    notificationTitle = "رسالة جديدة لخدمة العملاء 💬";
    if (thread.assignedAgentId) {
      recipientTokens.push(
        ...await userPushTokens(env, token, thread.assignedAgentId)
      );
    } else {
      const agents = await firestoreQuery(
        env,
        token,
        "users",
        [fieldEquals("role", "customer_service")]
      );
      recipientTokens.push(
        ...agents.filter((agent) => agent.customerServiceEnabled === true).flatMap(
          (agent) => Array.isArray(agent.fcmTokens) ? agent.fcmTokens : []
        )
      );
    }
    recipientTokens.push(...await adminPushTokens(env, token));
  } else if (
    actor.role === "customer_service" &&
    actor.customerServiceEnabled === true &&
    thread.assignedAgentId === user.uid
  ) {
    senderRole = "customer_service";
    senderName = String(actor.displayName || "خدمة عملاء بركة");
    notificationTitle = "رد جديد من خدمة عملاء بركة 💬";
    recipientTokens = await userPushTokens(env, token, thread.customerId);
  } else if (actor.role === "admin" || actor.isAdmin === true) {
    senderRole = "admin";
    senderName = String(actor.displayName || "إدارة بركة");
    notificationTitle = "رد جديد من إدارة بركة 💬";
    recipientTokens = await userPushTokens(env, token, thread.customerId);
  } else {
    fail(403, "support-permission-denied", "غير مسموح بإرسال رسالة في هذه المحادثة.");
  }
  const messageId = crypto.randomUUID().replace(/-/g, "");
  const shouldSendWelcome = senderRole === "customer" &&
    thread.autoWelcomeSent !== true &&
    !String(thread.lastMessage || "").trim();
  const welcomeMessage = "أهلًا وسهلًا بك في خدمة عملاء بركة 🌟\nتم استلام رسالتك بنجاح، وسيقوم أحد أعضاء فريقنا بالرد عليك بأقرب وقت. شكرًا لاختيارك بركة.";
  const writes = [
    createWrite(
      env,
      `support_threads/${encodeURIComponent(threadId)}/messages/${messageId}`,
      {
        senderId: user.uid,
        senderRole,
        senderName,
        text: message,
        createdAt: new Date()
      }
    ),
    updateWrite(
      env,
      `support_threads/${encodeURIComponent(threadId)}`,
      {
        lastMessage: message,
        lastMessageAt: new Date(),
        updatedAt: new Date(),
        status: senderRole === "customer" ? "open" : "active",
        ...(shouldSendWelcome ? {
          autoWelcomeSent: true,
          autoWelcomeAt: new Date()
        } : {})
      },
      thread.updateTime
    )
  ];
  if (shouldSendWelcome) {
    writes.push(createWrite(
      env,
      `support_threads/${encodeURIComponent(threadId)}/messages/${crypto.randomUUID().replace(/-/g, "")}`,
      {
        senderId: "barakah_support_bot",
        senderRole: "system",
        senderName: "مساعد بركة",
        text: welcomeMessage,
        createdAt: new Date(Date.now() + 1)
      }
    ));
  }
  const commit = await firestoreCommit(env, token, writes);
  if (!commit) {
    fail(409, "support-thread-changed", "وصلت رسالة أخرى؛ حاول الإرسال مجددًا.");
  }
  await sendPushToTokens(env, token, recipientTokens, {
    title: notificationTitle,
    body: `${senderName}: ${message.slice(0, 180)}`,
    data: {
      type: "support_message",
      threadId,
      senderRole
    }
  });
  if (shouldSendWelcome) {
    await sendPushToTokens(
      env,
      token,
      await userPushTokens(env, token, thread.customerId),
      {
        title: "أهلًا بك في خدمة عملاء بركة 🌟",
        body: "تم استلام رسالتك وسيقوم فريقنا بالرد عليك بأقرب وقت.",
        data: {
          type: "support_message",
          threadId,
          senderRole: "system"
        }
      }
    );
  }
  return { ok: true, threadId, messageId };
}
__name(sendSupportMessage, "sendSupportMessage");
function documentName(env, path) {
  return `projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/databases/(default)/documents/${path}`;
}
__name(documentName, "documentName");
function updateWrite(env, path, data, updateTime, transforms = []) {
  const write = {
    update: { name: documentName(env, path), fields: encodeFields(data) },
    updateMask: { fieldPaths: Object.keys(data) }
  };
  if (updateTime) write.currentDocument = { updateTime };
  if (transforms.length) write.updateTransforms = transforms;
  return write;
}
__name(updateWrite, "updateWrite");
function deleteWrite(env, path) {
  return {
    delete: documentName(env, path)
  };
}
__name(deleteWrite, "deleteWrite");

function createWrite(env, path, data) {
  return {
    update: {
      name: documentName(env, path),
      fields: encodeFields(data)
    },
    currentDocument: { exists: false }
  };
}
__name(createWrite, "createWrite");
function loyaltyTransactionWrite(env, transactionId, {
  customerId,
  type,
  pointsDelta,
  balanceBefore,
  balanceAfter,
  orderId = null,
  orderNumber = null,
  source,
  description,
  metadata = {}
}) {
  return createWrite(
    env,
    `loyalty_transactions/${encodeURIComponent(transactionId)}`,
    {
      customerId,
      type,
      pointsDelta,
      balanceBefore,
      balanceAfter,
      orderId,
      orderNumber,
      source,
      description,
      metadata,
      createdAt: /* @__PURE__ */ new Date()
    }
  );
}
__name(loyaltyTransactionWrite, "loyaltyTransactionWrite");
function decodeDocument(document) {
  return {
    id: document.name?.split("/").pop(),
    name: document.name,
    createTime: document.createTime,
    updateTime: document.updateTime,
    ...decodeFields(document.fields || {})
  };
}
__name(decodeDocument, "decodeDocument");
function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}
__name(decodeFields, "decodeFields");
function decodeValue(value) {
  if ("nullValue" in value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) return (value.arrayValue.values || []).map(decodeValue);
  if ("mapValue" in value) return decodeFields(value.mapValue.fields || {});
  return null;
}
__name(decodeValue, "decodeValue");
function encodeFields(data) {
  return Object.fromEntries(Object.entries(data).filter(([, value]) => value !== void 0).map(([key, value]) => [key, encodeValue(value)]));
}
__name(encodeFields, "encodeFields");
function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (!Number.isFinite(value)) fail(400, "invalid-number", "\u0642\u064A\u0645\u0629 \u0631\u0642\u0645\u064A\u0629 \u063A\u064A\u0631 \u0635\u062D\u064A\u062D\u0629.");
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === "object") return { mapValue: { fields: encodeFields(value) } };
  return { stringValue: String(value) };
}
__name(encodeValue, "encodeValue");
async function deleteCurrentAccount(env, user, targetUid = user.uid, adminDelete = false) {
  // Firebase considers deletion sensitive. Require a recent sign-in so a
  // stolen long-lived session cannot permanently remove an account.
  const nowSeconds = Math.floor(Date.now() / 1e3);
  if (
    !adminDelete &&
    (!user.authTime || nowSeconds - user.authTime > 600)
  ) {
    fail(
      401,
      "recent-login-required",
      "\u0644\u062d\u0630\u0641 \u0627\u0644\u062d\u0633\u0627\u0628 \u0646\u0647\u0627\u0626\u064a\u064b\u0627\u060c \u0633\u062c\u0651\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0645\u062c\u062f\u062f\u064b\u0627 \u062b\u0645 \u0623\u0639\u062f \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629."
    );
  }

  const token = await serviceToken(env);

  const profile = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(targetUid)}`
  );

  if (profile?.role === "admin") {
    fail(
      403,
      "admin-account-protected",
      "\u0644\u0627 \u064a\u0645\u0643\u0646 \u062d\u0630\u0641 \u062d\u0633\u0627\u0628 \u0627\u0644\u0625\u062f\u0627\u0631\u0629 \u0645\u0646 \u0647\u0630\u0647 \u0627\u0644\u062e\u062f\u0645\u0629."
    );
  }

  const [
    orders,
    coupons,
    driverApplications,
    merchantApplications,
    auctionRequests,
    auctionSalesBuyer,
    auctionSalesSeller
  ] = await Promise.all([
    firestoreQuery(env, token, "orders", [
      fieldEquals("customerId", targetUid)
    ]),
    firestoreQuery(env, token, "coupons", [
      fieldEquals("customerId", targetUid)
    ]),
    firestoreQuery(env, token, "driver_applications", [
      fieldEquals("userId", targetUid)
    ]),
    firestoreQuery(env, token, "merchant_applications", [
      fieldEquals("userId", targetUid)
    ]).catch(() => []),
    firestoreQuery(env, token, "auction_requests", [
      fieldEquals("userId", targetUid)
    ]),
    firestoreQuery(env, token, "auction_sales", [
      fieldEquals("buyerId", targetUid)
    ]),
    firestoreQuery(env, token, "auction_sales", [
      fieldEquals("sellerId", targetUid)
    ])
  ]);

  // Random anonymous identifier: it preserves accounting/history integrity
  // without retaining the Firebase UID.
  const anonymousId =
    `deleted_${crypto.randomUUID().replace(/-/g, "")}`;

  const writes = [];

  // Orders can be financial/accounting records, so keep the transaction
  // itself but permanently remove customer-identifying fields.
  for (const order of orders) {
    writes.push(
      updateWrite(
        env,
        `orders/${encodeURIComponent(order.id)}`,
        {
          customerId: anonymousId,
          customerName: null,
          customerEmail: null,
          customerPhone: null,
          deliveryAddress: null,
          deliveryLatitude: null,
          deliveryLongitude: null,
          deletedCustomer: true,
          customerDeletedAt: new Date(),
          updatedAt: new Date()
        },
        order.updateTime
      )
    );
  }

  // Auction records may also need to remain for transaction/accounting
  // integrity, so anonymize them rather than deleting completed history.
  for (const request of auctionRequests) {
    writes.push(
      updateWrite(
        env,
        `auction_requests/${encodeURIComponent(request.id)}`,
        {
          userId: anonymousId,
          userEmail: null,
          contactPhone: null,
          deletedUser: true,
          userDeletedAt: new Date(),
          updatedAt: new Date()
        },
        request.updateTime
      )
    );
  }

  for (const sale of auctionSalesBuyer) {
    writes.push(
      updateWrite(
        env,
        `auction_sales/${encodeURIComponent(sale.id)}`,
        {
          buyerId: anonymousId,
          buyerEmail: null,
          buyerPhone: null,
          buyerDeleted: true,
          updatedAt: new Date()
        },
        sale.updateTime
      )
    );
  }

  for (const sale of auctionSalesSeller) {
    writes.push(
      updateWrite(
        env,
        `auction_sales/${encodeURIComponent(sale.id)}`,
        {
          sellerId: anonymousId,
          sellerEmail: null,
          sellerPhone: null,
          sellerDeleted: true,
          updatedAt: new Date()
        },
        sale.updateTime
      )
    );
  }

  // Non-essential user-specific records can be deleted completely.
  for (const coupon of coupons) {
    writes.push(
      deleteWrite(
        env,
        `coupons/${encodeURIComponent(coupon.id)}`
      )
    );
  }

  for (const application of driverApplications) {
    writes.push(
      deleteWrite(
        env,
        `driver_applications/${encodeURIComponent(application.id)}`
      )
    );
  }

  for (const application of merchantApplications) {
    writes.push(
      deleteWrite(
        env,
        `merchant_applications/${encodeURIComponent(application.id)}`
      )
    );
  }

  if (profile) {
    writes.push(
      deleteWrite(
        env,
        `users/${encodeURIComponent(targetUid)}`
      )
    );
  }

  if (writes.length > 0) {
    // Firestore commit supports up to 500 writes.
    if (writes.length > 450) {
      fail(
        409,
        "account-too-many-records",
        "\u064a\u062d\u062a\u0648\u064a \u0627\u0644\u062d\u0633\u0627\u0628 \u0639\u0644\u0649 \u0639\u062f\u062f \u0643\u0628\u064a\u0631 \u0645\u0646 \u0627\u0644\u0633\u062c\u0644\u0627\u062a. \u062a\u0648\u0627\u0635\u0644 \u0645\u0639 \u0628\u0631\u0643\u0629 \u0644\u0625\u0643\u0645\u0627\u0644 \u0627\u0644\u062d\u0630\u0641."
      );
    }

    const result = await firestoreCommit(env, token, writes);

    if (!result) {
      fail(
        409,
        "account-data-changed",
        "\u062a\u063a\u064a\u0651\u0631\u062a \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628\u061b \u062d\u0627\u0648\u0644 \u0645\u062c\u062f\u062f\u064b\u0627."
      );
    }
  }

  // Finally delete the Firebase Authentication identity.
  const deleteResponse = adminDelete
      ? await fetch(
          `https://identitytoolkit.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/accounts:delete`,
          {
            method: "POST",
            headers: {
              ...JSON_HEADERS,
              authorization: `Bearer ${token}`
            },
            body: JSON.stringify({
              localId: targetUid
            })
          }
        )
      : await fetch(
          `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${encodeURIComponent(env.FIREBASE_WEB_API_KEY)}`,
          {
            method: "POST",
            headers: JSON_HEADERS,
            body: JSON.stringify({
              idToken: user.idToken
            })
          }
        );

    if (!deleteResponse.ok) {
    const message = await deleteResponse.text();

    console.error(
      "firebase_account_delete_failed",
      deleteResponse.status,
      message.substring(0, 500)
    );

    fail(
      502,
      "auth-account-delete-failed",
      "\u062a\u0645 \u062a\u0646\u0638\u064a\u0641 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628\u060c \u0644\u0643\u0646 \u062a\u0639\u0630\u0631 \u0625\u0646\u0647\u0627\u0621 \u062d\u0633\u0627\u0628 \u0627\u0644\u062f\u062e\u0648\u0644. \u062a\u0648\u0627\u0635\u0644 \u0645\u0639 \u0628\u0631\u0643\u0629."
    );
  }

  if (adminDelete) {
      try {
        await firestoreCommit(env, token, [
          deleteWrite(
            env,
            `account_deletion_requests/${encodeURIComponent(targetUid)}`
          )
        ]);
      } catch (error) {
        console.error(
          "account_deletion_request_cleanup_failed",
          targetUid,
          String(error)
        );
      }
    }

    return {
    ok: true,
    accountDeleted: true
  };
}
__name(deleteCurrentAccount, "deleteCurrentAccount");

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value)
  );
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
__name(sha256Hex, "sha256Hex");
async function verifyBarakahPin(userId, customer, pin) {
  if (customer.barakahCardActive !== true) {
    fail(409, "barakah-card-inactive", "\u0628\u0637\u0627\u0642\u0629 \u0628\u0631\u0643\u0629 \u063A\u064A\u0631 \u0645\u0641\u0639\u0644\u0629.");
  }
  if (!/^\d{4}$/.test(pin)) {
    fail(
      400,
      "invalid-barakah-pin",
      "\u0623\u062F\u062E\u0644 \u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A \u0627\u0644\u0645\u0643\u0648\u0651\u0646 \u0645\u0646 4 \u0623\u0631\u0642\u0627\u0645."
    );
  }
  const salt = String(customer.barakahPinSalt || "").trim();
  const storedHash = String(customer.barakahPinHash || "").trim().toLowerCase();
  if (!salt || !storedHash) {
    fail(
      409,
      "barakah-pin-missing",
      "\u0644\u0645 \u064A\u062A\u0645 \u0625\u0639\u062F\u0627\u062F \u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A \u0644\u0628\u0637\u0627\u0642\u0629 \u0628\u0631\u0643\u0629 \u0628\u0639\u062F."
    );
  }
  const calculatedHash = await sha256Hex(`${userId}:${salt}:${pin}`);
  if (calculatedHash !== storedHash) {
    fail(
      403,
      "wrong-barakah-pin",
      "\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A \u0644\u0628\u0637\u0627\u0642\u0629 \u0628\u0631\u0643\u0629 \u063A\u064A\u0631 \u0635\u062D\u064A\u062D."
    );
  }
}
__name(verifyBarakahPin, "verifyBarakahPin");
async function resetBarakahPin(request, env, user) {
  const data = await readJson(request);
  const newPin = String(data.newPin || "").trim();
  if (!/^\d{4}$/.test(newPin)) {
    fail(
      400,
      "invalid-new-pin",
      "\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A \u0627\u0644\u062C\u062F\u064A\u062F \u064A\u062C\u0628 \u0623\u0646 \u064A\u062A\u0643\u0648\u0651\u0646 \u0645\u0646 4 \u0623\u0631\u0642\u0627\u0645."
    );
  }
  const authTimeMillis = Number(user.authTime || 0) * 1e3;
  const recentLimitMillis = 5 * 60 * 1e3;
  if (!authTimeMillis || Date.now() - authTimeMillis > recentLimitMillis) {
    fail(
      401,
      "recent-login-required",
      "\u0644\u0623\u0645\u0627\u0646 \u0628\u0637\u0627\u0642\u062A\u0643\u060C \u0633\u062C\u0651\u0644 \u0627\u0644\u062E\u0631\u0648\u062C \u062B\u0645 \u0627\u062F\u062E\u0644 \u0625\u0644\u0649 \u062D\u0633\u0627\u0628\u0643 \u0645\u062C\u062F\u062F\u064B\u0627 \u0642\u0628\u0644 \u0625\u0639\u0627\u062F\u0629 \u062A\u0639\u064A\u064A\u0646 PIN."
    );
  }
  const token = await serviceToken(env);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const customer = await firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    );
    if (!customer) {
      fail(
        404,
        "customer-missing",
        "\u062D\u0633\u0627\u0628 \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F."
      );
    }
    if (customer.barakahCardActive !== true) {
      fail(
        409,
        "barakah-card-inactive",
        "\u0628\u0637\u0627\u0642\u0629 \u0628\u0631\u0643\u0629 \u063A\u064A\u0631 \u0645\u0641\u0639\u0644\u0629."
      );
    }
    const newSalt = crypto.randomUUID().replace(/-/g, "");
    const newHash = await sha256Hex(
      `${user.uid}:${newSalt}:${newPin}`
    );
    const result = await firestoreCommit(
      env,
      token,
      [
        updateWrite(
          env,
          `users/${encodeURIComponent(user.uid)}`,
          {
            barakahPinHash: newHash,
            barakahPinSalt: newSalt,
            barakahPinResetAt: /* @__PURE__ */ new Date(),
            updatedAt: /* @__PURE__ */ new Date()
          },
          customer.updateTime
        )
      ]
    );
    if (result) {
      return {
        ok: true,
        reset: true
      };
    }
  }
  fail(
    409,
    "pin-conflict",
    "\u062A\u063A\u064A\u0651\u0631\u062A \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u062D\u0633\u0627\u0628 \u0623\u062B\u0646\u0627\u0621 \u0625\u0639\u0627\u062F\u0629 \u062A\u0639\u064A\u064A\u0646 PIN. \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627."
  );
}
__name(resetBarakahPin, "resetBarakahPin");
async function changeBarakahPin(request, env, user) {
  const data = await readJson(request);
  const currentPin = String(data.currentPin || "").trim();
  const newPin = String(data.newPin || "").trim();
  if (!/^\d{4}$/.test(currentPin)) {
    fail(
      400,
      "invalid-current-pin",
      "\u0623\u062F\u062E\u0644 \u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A \u0627\u0644\u062D\u0627\u0644\u064A \u0627\u0644\u0645\u0643\u0648\u0651\u0646 \u0645\u0646 4 \u0623\u0631\u0642\u0627\u0645."
    );
  }
  if (!/^\d{4}$/.test(newPin)) {
    fail(
      400,
      "invalid-new-pin",
      "\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A \u0627\u0644\u062C\u062F\u064A\u062F \u064A\u062C\u0628 \u0623\u0646 \u064A\u062A\u0643\u0648\u0651\u0646 \u0645\u0646 4 \u0623\u0631\u0642\u0627\u0645."
    );
  }
  if (currentPin === newPin) {
    fail(
      400,
      "same-pin",
      "\u0627\u062E\u062A\u0631 \u0631\u0642\u0645\u064B\u0627 \u0633\u0631\u064A\u064B\u0627 \u062C\u062F\u064A\u062F\u064B\u0627 \u0645\u062E\u062A\u0644\u0641\u064B\u0627 \u0639\u0646 \u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u062D\u0627\u0644\u064A."
    );
  }
  const token = await serviceToken(env);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const customer = await firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    );
    if (!customer) {
      fail(
        404,
        "customer-missing",
        "\u062D\u0633\u0627\u0628 \u0627\u0644\u0645\u0633\u062A\u062E\u062F\u0645 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F."
      );
    }
    await verifyBarakahPin(
      user.uid,
      customer,
      currentPin
    );
    const newSalt = crypto.randomUUID().replace(/-/g, "");
    const newHash = await sha256Hex(
      `${user.uid}:${newSalt}:${newPin}`
    );
    const result = await firestoreCommit(
      env,
      token,
      [
        updateWrite(
          env,
          `users/${encodeURIComponent(user.uid)}`,
          {
            barakahPinHash: newHash,
            barakahPinSalt: newSalt,
            barakahPinChangedAt: /* @__PURE__ */ new Date(),
            updatedAt: /* @__PURE__ */ new Date()
          },
          customer.updateTime
        )
      ]
    );
    if (result) {
      return {
        ok: true,
        changed: true
      };
    }
  }
  fail(
    409,
    "pin-conflict",
    "\u062A\u063A\u064A\u0651\u0631\u062A \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u062D\u0633\u0627\u0628 \u0623\u062B\u0646\u0627\u0621 \u062A\u063A\u064A\u064A\u0631 \u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0633\u0631\u064A. \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627."
  );
}
__name(changeBarakahPin, "changeBarakahPin");
async function createMerchantProduct(request, env, user) {
  const data = await readJson(request);
  const businessId = String(data.businessId || "").trim();
  const title = String(data.title || "").trim();
  const description = String(data.description || "").trim();
  const image = String(data.image || "").trim();
  const price = Number(data.price);
  const stock = Number(data.stock);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(businessId)) {
    fail(
      400,
      "invalid-business",
      "\u0627\u0644\u0645\u062A\u062C\u0631 \u0627\u0644\u0645\u062D\u062F\u062F \u063A\u064A\u0631 \u0635\u0627\u0644\u062D."
    );
  }
  if (title.length < 2 || title.length > 120) {
    fail(
      400,
      "invalid-product-title",
      "\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u062A\u062C \u064A\u062C\u0628 \u0623\u0646 \u064A\u0643\u0648\u0646 \u0628\u064A\u0646 \u062D\u0631\u0641\u064A\u0646 \u0648120 \u062D\u0631\u0641\u064B\u0627."
    );
  }
  if (description.length > 1500) {
    fail(
      400,
      "invalid-description",
      "\u0648\u0635\u0641 \u0627\u0644\u0645\u0646\u062A\u062C \u0637\u0648\u064A\u0644 \u062C\u062F\u064B\u0627."
    );
  }
  if (image.length > 2500) {
    fail(
      400,
      "invalid-image-url",
      "\u0631\u0627\u0628\u0637 \u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u0646\u062A\u062C \u063A\u064A\u0631 \u0635\u0627\u0644\u062D."
    );
  }
  if (!Number.isFinite(price) || price < 0 || price > 1e6) {
    fail(
      400,
      "invalid-product-price",
      "\u0633\u0639\u0631 \u0627\u0644\u0645\u0646\u062A\u062C \u063A\u064A\u0631 \u0635\u0627\u0644\u062D."
    );
  }
  if (!Number.isInteger(stock) || stock < 0 || stock > 999999) {
    fail(
      400,
      "invalid-product-stock",
      "\u0643\u0645\u064A\u0629 \u0627\u0644\u0645\u0646\u062A\u062C \u064A\u062C\u0628 \u0623\u0646 \u062A\u0643\u0648\u0646 \u0631\u0642\u0645\u064B\u0627 \u0635\u062D\u064A\u062D\u064B\u0627 \u0645\u0646 0 \u0625\u0644\u0649 999999."
    );
  }
  const token = await serviceToken(env);
  const [actor, business] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(
      env,
      token,
      `items/${encodeURIComponent(businessId)}`
    )
  ]);
  if (!actor || actor.role !== "merchant" || actor.merchantEnabled !== true) {
    fail(
      403,
      "merchant-not-authorized",
      "\u0647\u0630\u0627 \u0627\u0644\u062D\u0633\u0627\u0628 \u063A\u064A\u0631 \u0645\u0641\u0648\u0636 \u0644\u0625\u062F\u0627\u0631\u0629 \u0645\u062A\u062C\u0631."
    );
  }
  if (!business || business.kind === "product" || business.ownerId !== user.uid) {
    fail(
      403,
      "business-not-owned",
      "\u0644\u0627 \u064A\u0645\u0643\u0646\u0643 \u0625\u0636\u0627\u0641\u0629 \u0645\u0646\u062A\u062C\u0627\u062A \u0625\u0644\u0649 \u0647\u0630\u0627 \u0627\u0644\u0645\u062A\u062C\u0631."
    );
  }
  const productId = crypto.randomUUID().replace(/-/g, "");
  const product = {
    title,
    description,
    image,
    kind: "product",
    businessId,
    businessTitle: String(business.title || ""),
    category: String(business.category || ""),
    type: String(business.type || ""),
    price: Math.round(price * 100) / 100,
    stock,
    soldOut: stock <= 0,
    ownerId: user.uid,
    ownerEmail: user.email || null,
    isActive: true,
    createdAt: /* @__PURE__ */ new Date(),
    updatedAt: /* @__PURE__ */ new Date()
  };
  await firestoreCreate(
    env,
    token,
    "items",
    productId,
    product
  );
  console.log("MERCHANT_PRODUCT_CREATED", {
    productId,
    businessId,
    merchantUid: user.uid,
    title
  });
  return {
    ok: true,
    productId,
    businessId,
    title,
    price: product.price
  };
}
__name(createMerchantProduct, "createMerchantProduct");
async function requireOwnedMerchantProduct(env, token, user, productId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(productId)) {
    fail(400, "invalid-product", "\u0631\u0642\u0645 \u0627\u0644\u0645\u0646\u062A\u062C \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  }
  const [actor, product] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(
      env,
      token,
      `items/${encodeURIComponent(productId)}`
    )
  ]);
  if (!actor || actor.role !== "merchant" || actor.merchantEnabled !== true) {
    fail(
      403,
      "merchant-not-authorized",
      "\u0647\u0630\u0627 \u0627\u0644\u062D\u0633\u0627\u0628 \u063A\u064A\u0631 \u0645\u0641\u0648\u0636 \u0644\u0625\u062F\u0627\u0631\u0629 \u0645\u062A\u062C\u0631."
    );
  }
  if (!product || product.kind !== "product" || product.ownerId !== user.uid) {
    fail(
      403,
      "product-not-owned",
      "\u0644\u0627 \u064A\u0645\u0643\u0646\u0643 \u0625\u062F\u0627\u0631\u0629 \u0647\u0630\u0627 \u0627\u0644\u0645\u0646\u062A\u062C."
    );
  }
  const business = await firestoreGet(
    env,
    token,
    `items/${encodeURIComponent(product.businessId || "")}`
  );
  if (!business || business.ownerId !== user.uid) {
    fail(
      403,
      "business-not-owned",
      "\u0627\u0644\u0645\u0646\u062A\u062C \u063A\u064A\u0631 \u0645\u0631\u062A\u0628\u0637 \u0628\u0645\u062A\u062C\u0631 \u062A\u0645\u0644\u0643\u0647."
    );
  }
  return { product, business };
}
__name(requireOwnedMerchantProduct, "requireOwnedMerchantProduct");
async function updateMerchantProduct(request, env, user, productId) {
  const data = await readJson(request);
  const title = String(data.title || "").trim();
  const description = String(data.description || "").trim();
  const image = String(data.image || "").trim();
  const price = Number(data.price);
  const stock = Number(data.stock);
  if (title.length < 2 || title.length > 120) {
    fail(
      400,
      "invalid-product-title",
      "\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u062A\u062C \u064A\u062C\u0628 \u0623\u0646 \u064A\u0643\u0648\u0646 \u0628\u064A\u0646 \u062D\u0631\u0641\u064A\u0646 \u0648120 \u062D\u0631\u0641\u064B\u0627."
    );
  }
  if (description.length > 1500) {
    fail(
      400,
      "invalid-description",
      "\u0648\u0635\u0641 \u0627\u0644\u0645\u0646\u062A\u062C \u0637\u0648\u064A\u0644 \u062C\u062F\u064B\u0627."
    );
  }
  if (image.length > 2500) {
    fail(
      400,
      "invalid-image-url",
      "\u0631\u0627\u0628\u0637 \u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u0646\u062A\u062C \u063A\u064A\u0631 \u0635\u0627\u0644\u062D."
    );
  }
  if (!Number.isFinite(price) || price < 0 || price > 1e6) {
    fail(
      400,
      "invalid-product-price",
      "\u0633\u0639\u0631 \u0627\u0644\u0645\u0646\u062A\u062C \u063A\u064A\u0631 \u0635\u0627\u0644\u062D."
    );
  }
  if (!Number.isInteger(stock) || stock < 0 || stock > 999999) {
    fail(
      400,
      "invalid-product-stock",
      "\u0643\u0645\u064A\u0629 \u0627\u0644\u0645\u0646\u062A\u062C \u064A\u062C\u0628 \u0623\u0646 \u062A\u0643\u0648\u0646 \u0631\u0642\u0645\u064B\u0627 \u0635\u062D\u064A\u062D\u064B\u0627 \u0645\u0646 0 \u0625\u0644\u0649 999999."
    );
  }
  const token = await serviceToken(env);
  const { product, business } = await requireOwnedMerchantProduct(
    env,
    token,
    user,
    productId
  );
  const result = await firestoreCommit(
    env,
    token,
    [
      updateWrite(
        env,
        `items/${encodeURIComponent(productId)}`,
        {
          title,
          description,
          image,
          price: Math.round(price * 100) / 100,
          stock,
          soldOut: stock <= 0,
          businessId: product.businessId,
          businessTitle: String(business.title || ""),
          category: String(business.category || ""),
          type: String(business.type || ""),
          ownerId: user.uid,
          kind: "product",
          updatedAt: /* @__PURE__ */ new Date()
        },
        product.updateTime
      )
    ]
  );
  if (!result) {
    fail(
      409,
      "product-changed",
      "\u062A\u063A\u064A\u0651\u0631 \u0627\u0644\u0645\u0646\u062A\u062C. \u062D\u062F\u0651\u062B \u0627\u0644\u0635\u0641\u062D\u0629 \u0648\u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627."
    );
  }
  console.log("MERCHANT_PRODUCT_UPDATED", {
    productId,
    merchantUid: user.uid
  });
  return {
    ok: true,
    productId
  };
}
__name(updateMerchantProduct, "updateMerchantProduct");
async function deleteMerchantProduct(env, user, productId) {
  const token = await serviceToken(env);
  const { product } = await requireOwnedMerchantProduct(
    env,
    token,
    user,
    productId
  );
  const response = await fetch(
    `${firestoreBase(env)}/items/${encodeURIComponent(productId)}`,
    {
      method: "DELETE",
      headers: {
        authorization: `Bearer ${token}`,
        "if-match": "*"
      }
    }
  );
  if (!response.ok) {
    const body = await response.text();
    console.error(
      "merchant_product_delete_failed",
      response.status,
      body,
      product.id
    );
    fail(
      502,
      "product-delete-failed",
      "\u062A\u0639\u0630\u0631 \u062D\u0630\u0641 \u0627\u0644\u0645\u0646\u062A\u062C."
    );
  }
  await response.body?.cancel();
  console.log("MERCHANT_PRODUCT_DELETED", {
    productId,
    merchantUid: user.uid
  });
  return {
    ok: true,
    productId
  };
}
__name(deleteMerchantProduct, "deleteMerchantProduct");
async function createOrder(request, env, user) {
  const idempotencyKey = (request.headers.get("idempotency-key") || "").trim();
  if (!/^[A-Za-z0-9_-]{16,100}$/.test(idempotencyKey)) {
    fail(400, "missing-idempotency-key", "\u062A\u0639\u0630\u0631 \u062A\u062B\u0628\u064A\u062A \u0627\u0644\u0637\u0644\u0628. \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627.");
  }
  const existing = await env.DB.prepare(
    "SELECT order_id, order_number FROM idempotency_keys WHERE user_id=? AND request_key=?"
  ).bind(user.uid, idempotencyKey).first();
  if (existing?.order_id) return {
    orderId: existing.order_id,
    orderNumber: existing.order_number,
    repeated: true
  };
  const data = await readJson(request);
  const rawRequestedBarakahPoints = Number(data.barakahPointsToUse || 0);
  if (!Number.isFinite(rawRequestedBarakahPoints) || rawRequestedBarakahPoints < 0) {
    fail(400, "invalid-barakah-points", "\u0639\u062F\u062F \u0646\u0642\u0627\u0637 \u0628\u0631\u0643\u0629 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  }
  const requestedBarakahPoints = Math.floor(rawRequestedBarakahPoints);
  const barakahPin = String(data.barakahPin || "").trim();
  const rawItems = Array.isArray(data.items) ? data.items : [];
  if (!rawItems.length || rawItems.length > MAX_ITEMS) {
    fail(400, "invalid-items", "\u0627\u0644\u0633\u0644\u0629 \u0641\u0627\u0631\u063A\u0629 \u0623\u0648 \u062A\u062D\u062A\u0648\u064A \u0623\u0635\u0646\u0627\u0641\u064B\u0627 \u0643\u062B\u064A\u0631\u0629.");
  }
  const requested = rawItems.map((item) => ({
    productId: String(item.productId || "").trim(),
    quantity: Number(item.quantity)
  }));
  if (requested.some((item) => !/^[A-Za-z0-9_-]{1,128}$/.test(item.productId) || !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 99)) {
    fail(400, "invalid-items", "\u0623\u062D\u062F \u0623\u0635\u0646\u0627\u0641 \u0627\u0644\u0633\u0644\u0629 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  }
  if (new Set(requested.map((item) => item.productId)).size !== requested.length) {
    fail(400, "duplicate-items", "\u064A\u0648\u062C\u062F \u0635\u0646\u0641 \u0645\u0643\u0631\u0631 \u0641\u064A \u0627\u0644\u0633\u0644\u0629.");
  }
  const token = await serviceToken(env);
  const products = await Promise.all(requested.map((item) => firestoreGet(env, token, `items/${encodeURIComponent(item.productId)}`)));
  if (products.some((product) => !product || product.kind !== "product")) {
    fail(409, "product-unavailable", "\u0623\u062D\u062F \u0627\u0644\u0623\u0635\u0646\u0627\u0641 \u0644\u0645 \u064A\u0639\u062F \u0645\u062A\u0627\u062D\u064B\u0627.");
  }
  for (let index = 0; index < products.length; index += 1) {
    const product = products[index];
    const requestedQuantity = requested[index].quantity;
    const hasManagedStock = Number.isInteger(Number(product.stock));
    if (product.soldOut === true) {
      fail(
        409,
        "product-sold-out",
        `${String(product.title || "\u0627\u0644\u0645\u0646\u062A\u062C")} \u0646\u0641\u062F \u0645\u0646 \u0627\u0644\u0645\u062E\u0632\u0648\u0646.`
      );
    }
    if (hasManagedStock) {
      const availableStock = Math.max(0, Math.floor(Number(product.stock)));
      if (availableStock < requestedQuantity) {
        fail(
          409,
          "insufficient-stock",
          availableStock <= 0 ? `${String(product.title || "\u0627\u0644\u0645\u0646\u062A\u062C")} \u0646\u0641\u062F \u0645\u0646 \u0627\u0644\u0645\u062E\u0632\u0648\u0646.` : `\u0627\u0644\u0645\u062A\u0648\u0641\u0631 \u0645\u0646 ${String(product.title || "\u0627\u0644\u0645\u0646\u062A\u062C")} \u0647\u0648 ${availableStock} \u0641\u0642\u0637.`
        );
      }
    }
  }
  const businessIds = new Set(products.map((product) => String(product.businessId || "")));
  if (businessIds.size !== 1 || ![...businessIds][0]) {
    fail(400, "mixed-businesses", "\u064A\u062C\u0628 \u0623\u0646 \u062A\u0643\u0648\u0646 \u0623\u0635\u0646\u0627\u0641 \u0627\u0644\u0637\u0644\u0628 \u0645\u0646 \u0645\u062D\u0644 \u0648\u0627\u062D\u062F.");
  }
  const businessId = [...businessIds][0];
  let business = await firestoreGet(env, token, `items/${encodeURIComponent(businessId)}`);
  if (!business) {
    const legacyTitles = new Set(products.map((product) => String(product.businessTitle || "").trim()).filter(Boolean));
    if (legacyTitles.size !== 1) {
      fail(409, "business-unavailable", "\u0627\u0644\u0645\u062D\u0644 \u0627\u0644\u0645\u0631\u062A\u0628\u0637 \u0628\u0647\u0630\u0647 \u0627\u0644\u0623\u0635\u0646\u0627\u0641 \u063A\u064A\u0631 \u0645\u062A\u0627\u062D.");
    }
    business = {
      title: [...legacyTitles][0],
      businessStatus: "open",
      deliveryFee: 0,
      preparationMinutes: 30,
      commissionRate: 10,
      legacyRecovered: true
    };
  }
  if (business.kind === "product") {
    fail(409, "business-unavailable", "\u0627\u0644\u0645\u062D\u0644 \u063A\u064A\u0631 \u0645\u062A\u0627\u062D.");
  }
  const scheduledMillis = Number(data.scheduledForMillis || 0);
  const scheduledFor = scheduledMillis > Date.now() + 6e4 ? new Date(scheduledMillis) : null;
  if (business.businessStatus === "closed" && !scheduledFor) {
    fail(409, "business-closed", "\u0627\u0644\u0645\u062D\u0644 \u0645\u063A\u0644\u0642 \u0627\u0644\u0622\u0646\u061B \u064A\u0645\u0643\u0646\u0643 \u062C\u062F\u0648\u0644\u0629 \u0627\u0644\u0637\u0644\u0628.");
  }
  const items = products.map((product, index) => {
    const price = Number(product.price);
    if (!Number.isFinite(price) || price < 0) fail(409, "invalid-product-price", "\u0633\u0639\u0631 \u0623\u062D\u062F \u0627\u0644\u0623\u0635\u0646\u0627\u0641 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
    return {
      productId: requested[index].productId,
      title: String(product.title || "\u0645\u0646\u062A\u062C"),
      price,
      quantity: requested[index].quantity,
      businessId,
      businessTitle: String(business.title || "")
    };
  });
  const subtotal = money(items.reduce((sum, item) => sum + item.price * item.quantity, 0));
  const deliveryMethod = data.deliveryMethod === "pickup" ? "pickup" : "delivery";
  const paymentMethod = data.paymentMethod === "cash" ? "cash" : "cash";
  const deliveryFee = deliveryMethod === "delivery" ? money(Number(business.deliveryFee || 0)) : 0;
  const total = money(subtotal + Math.max(0, deliveryFee));
  const [customer, loyaltySettings] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(env, token, "app_settings/loyalty")
  ]);
  if (!customer) {
    fail(409, "customer-missing", "\u062D\u0633\u0627\u0628 \u0627\u0644\u0632\u0628\u0648\u0646 \u063A\u064A\u0631 \u0645\u062A\u0627\u062D.");
  }
  const redemptionPoints = Math.max(
    1,
    Math.floor(Number(loyaltySettings?.redemptionPoints || 1e3))
  );
  const redemptionValue = Math.max(
    0.01,
    Number(loyaltySettings?.redemptionValue || 10)
  );
  const availablePoints = Math.max(
    0,
    Math.floor(Number(customer.loyaltyPoints || 0))
  );
  if (requestedBarakahPoints > 0) {
    await verifyBarakahPin(user.uid, customer, barakahPin);
    if (requestedBarakahPoints > availablePoints) {
      fail(
        409,
        "insufficient-barakah-points",
        "\u0631\u0635\u064A\u062F \u0646\u0642\u0627\u0637 \u0628\u0631\u0643\u0629 \u063A\u064A\u0631 \u0643\u0627\u0641\u064D."
      );
    }
    if (requestedBarakahPoints % redemptionPoints !== 0) {
      fail(
        400,
        "invalid-redemption-step",
        "\u0627\u0633\u062A\u062E\u062F\u0645 \u0627\u0644\u0646\u0642\u0627\u0637 \u0628\u062D\u0633\u0628 \u0641\u0626\u0629 \u0627\u0644\u0627\u0633\u062A\u0628\u062F\u0627\u0644 \u0627\u0644\u0645\u062D\u062F\u062F\u0629 \u0641\u064A \u0628\u0631\u0643\u0629."
      );
    }
  }
  const rawPointsDiscount = requestedBarakahPoints > 0 ? requestedBarakahPoints / redemptionPoints * redemptionValue : 0;
  if (requestedBarakahPoints > 0 && rawPointsDiscount > total + 1e-4) {
    fail(
      400,
      "barakah-points-exceed-total",
      "\u0639\u062F\u062F \u0627\u0644\u0646\u0642\u0627\u0637 \u0627\u0644\u0645\u062E\u062A\u0627\u0631 \u0623\u0643\u0628\u0631 \u0645\u0646 \u0642\u064A\u0645\u0629 \u0627\u0644\u0637\u0644\u0628."
    );
  }
  const pointsDiscount = money(
    Math.min(total, rawPointsDiscount)
  );
  const payableTotal = money(
    Math.max(0, total - pointsDiscount)
  );
  const remainingLoyaltyPoints = availablePoints - requestedBarakahPoints;
  const configuredCommissionRate = Number(business.commissionRate);
  const commissionRate = Number.isFinite(configuredCommissionRate) && configuredCommissionRate >= 0 && configuredCommissionRate <= 100 ? configuredCommissionRate : 10;
  const commissionAmount = money(subtotal * commissionRate / 100);
  const businessNet = money(subtotal - commissionAmount);
  const claim = await env.DB.prepare(
    "INSERT OR IGNORE INTO idempotency_keys (user_id, request_key) VALUES (?, ?)"
  ).bind(user.uid, idempotencyKey).run();
  if (Number(claim?.meta?.changes || 0) !== 1) {
    for (let attempt = 0; attempt < 8; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 250));
      const pending = await env.DB.prepare(
        "SELECT order_id, order_number FROM idempotency_keys WHERE user_id=? AND request_key=?"
      ).bind(user.uid, idempotencyKey).first();
      if (pending?.order_id) return {
        orderId: pending.order_id,
        orderNumber: pending.order_number,
        repeated: true
      };
    }
    fail(409, "order-in-progress", "\u0627\u0644\u0637\u0644\u0628 \u0646\u0641\u0633\u0647 \u0642\u064A\u062F \u0627\u0644\u062A\u062B\u0628\u064A\u062A. \u0627\u0646\u062A\u0638\u0631 \u0644\u062D\u0638\u0627\u062A.");
  }
  const counter = await env.DB.prepare(
    "UPDATE counters SET value=value+1 WHERE name='orders' RETURNING value"
  ).first();
  if (!counter?.value) fail(503, "counter-unavailable", "\u062A\u0639\u0630\u0631 \u0625\u0646\u0634\u0627\u0621 \u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628.");
  const sequence = Number(counter.value);
  const orderNumber = `BRK-${String(sequence).padStart(6, "0")}`;
  const orderId = crypto.randomUUID().replace(/-/g, "");
  const preparationMinutes = Math.max(1, Math.min(240, Number(business.preparationMinutes || 30)));
  const customerPhone = String(
    data.customerPhone || customer.phone || user.phone || ""
  ).trim();
  const deliveryAddress = String(
    data.deliveryAddress || customer.address || ""
  ).trim();
  const deliveryLatitude = finiteOrNull(
    data.deliveryLatitude ?? customer.agentLatitude
  );
  const deliveryLongitude = finiteOrNull(
    data.deliveryLongitude ?? customer.agentLongitude
  );
  if (deliveryMethod === "delivery") {
    if (!customerPhone) {
      fail(
        400,
        "customer-phone-required",
        "\u0623\u0636\u0641 \u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062A\u0641 \u0625\u0644\u0649 \u062D\u0633\u0627\u0628\u0643 \u0642\u0628\u0644 \u0637\u0644\u0628 \u0627\u0644\u062A\u0648\u0635\u064A\u0644."
      );
    }
    if (!deliveryAddress) {
      fail(
        400,
        "delivery-address-required",
        "\u0623\u0636\u0641 \u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u062A\u0648\u0635\u064A\u0644 \u0625\u0644\u0649 \u062D\u0633\u0627\u0628\u0643 \u0642\u0628\u0644 \u0645\u062A\u0627\u0628\u0639\u0629 \u0627\u0644\u0637\u0644\u0628."
      );
    }
    if (deliveryLatitude === null || deliveryLongitude === null) {
      fail(
        400,
        "delivery-location-required",
        "\u062D\u062F\u062F \u0645\u0648\u0642\u0639 \u0627\u0644\u062A\u0648\u0635\u064A\u0644 \u0639\u0644\u0649 \u0627\u0644\u062E\u0631\u064A\u0637\u0629 \u0642\u0628\u0644 \u0645\u062A\u0627\u0628\u0639\u0629 \u0627\u0644\u0637\u0644\u0628."
      );
    }
  }
  const orderRecord = {
    orderNumber,
    orderSequence: sequence,
    customerId: user.uid,
    customerEmail: user.email,
    customerPhone: customerPhone || null,
    deliveryAddress: deliveryAddress || null,
    deliveryLatitude,
    deliveryLongitude,
    items,
    subtotal,
    deliveryFee,
    total,
    deliveryMethod,
    paymentMethod,
    barakahPointsUsed: requestedBarakahPoints,
    barakahPointsDiscount: pointsDiscount,
    payableTotal,
    barakahCardLast4: requestedBarakahPoints > 0 ? String(customer.barakahCardNumber || "").replace(/\D/g, "").slice(-4) : null,
    barakahRedemptionPoints: redemptionPoints,
    barakahRedemptionValue: redemptionValue,
    commissionRate,
    commissionAmount,
    businessNet,
    status: scheduledFor ? "scheduled" : "new",
    businessId,
    businessTitle: business.title || null,
    restaurantLatitude: finiteOrNull(business.latitude),
    restaurantLongitude: finiteOrNull(business.longitude),
    preparationMinutes,
    estimatedReadyAt: new Date(Date.now() + preparationMinutes * 6e4),
    scheduledFor,
    rewardGranted: false,
    createdAt: /* @__PURE__ */ new Date(),
    updatedAt: /* @__PURE__ */ new Date()
  };
  const writes = [
    createWrite(
      env,
      `orders/${encodeURIComponent(orderId)}`,
      orderRecord
    )
  ];
  products.forEach((product, index) => {
    if (!Number.isInteger(Number(product.stock))) return;
    const currentStock = Math.max(0, Math.floor(Number(product.stock)));
    const nextStock = currentStock - requested[index].quantity;
    writes.push(
      updateWrite(
        env,
        `items/${encodeURIComponent(requested[index].productId)}`,
        {
          stock: nextStock,
          soldOut: nextStock <= 0,
          updatedAt: /* @__PURE__ */ new Date()
        },
        product.updateTime
      )
    );
  });
  if (requestedBarakahPoints > 0) {
    writes.push(
      updateWrite(
        env,
        `users/${encodeURIComponent(user.uid)}`,
        {
          loyaltyPoints: remainingLoyaltyPoints,
          updatedAt: /* @__PURE__ */ new Date()
        },
        customer.updateTime
      )
    );
    writes.push(
      loyaltyTransactionWrite(
        env,
        `order_USE_${orderId}`,
        {
          customerId: user.uid,
          type: "redeem",
          pointsDelta: -requestedBarakahPoints,
          balanceBefore: availablePoints,
          balanceAfter: remainingLoyaltyPoints,
          orderId,
          orderNumber,
          source: "order_payment",
          description: `\u0627\u0633\u062A\u062E\u062F\u0627\u0645 ${requestedBarakahPoints} \u0646\u0642\u0637\u0629 \u0641\u064A \u0627\u0644\u0637\u0644\u0628 ${orderNumber}`,
          metadata: {
            discountValue: pointsDiscount
          }
        }
      )
    );
  }
  const commitResult = await firestoreCommit(env, token, writes);
  if (!commitResult) {
    await env.DB.prepare(
      "DELETE FROM idempotency_keys WHERE user_id=? AND request_key=? AND order_id IS NULL"
    ).bind(user.uid, idempotencyKey).run();
    fail(
      409,
      "order-stock-conflict",
      "\u062A\u063A\u064A\u0651\u0631\u062A \u0643\u0645\u064A\u0629 \u0623\u062D\u062F \u0627\u0644\u0645\u0646\u062A\u062C\u0627\u062A \u0623\u062B\u0646\u0627\u0621 \u0627\u0644\u0637\u0644\u0628. \u062D\u062F\u0651\u062B \u0627\u0644\u0633\u0644\u0629 \u0648\u062D\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062E\u0631\u0649."
    );
  }
  await env.DB.prepare(
    "UPDATE idempotency_keys SET order_id=?, order_number=? WHERE user_id=? AND request_key=?"
  ).bind(orderId, orderNumber, user.uid, idempotencyKey).run();
  try {
    await notifyAdminsAboutOrder(env, token, orderId, orderRecord);
  } catch (error) {
    console.error("admin_notification_failed", error.message);
  }
  return {
    orderId,
    orderNumber,
    total,
    payableTotal,
    barakahPointsUsed: requestedBarakahPoints,
    barakahPointsDiscount: pointsDiscount
  };
}
__name(createOrder, "createOrder");
async function cancelCustomerOrder(env, user, orderId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(orderId)) {
    fail(400, "invalid-order", "\u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  }
  const token = await serviceToken(env);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const order = await firestoreGet(
      env,
      token,
      `orders/${encodeURIComponent(orderId)}`
    );
    if (!order) {
      fail(404, "order-not-found", "\u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F.");
    }
    if (order.customerId !== user.uid) {
      fail(
        403,
        "permission-denied",
        "\u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628 \u0644\u0627 \u064A\u062E\u0635 \u062D\u0633\u0627\u0628\u0643."
      );
    }
    if (order.status === "cancelled" || order.status === "canceled") {
      const pointsUsed2 = Math.max(
        0,
        Math.floor(Number(order.barakahPointsUsed || 0))
      );
      if (pointsUsed2 <= 0 || order.barakahPointsRefunded === true || !order.customerId) {
        return {
          orderId,
          status: "cancelled",
          pointsRefunded: order.barakahPointsRefundedAmount || 0
        };
      }
      const customer = await firestoreGet(
        env,
        token,
        `users/${encodeURIComponent(order.customerId)}`
      );
      if (!customer) {
        fail(
          409,
          "refund-data-missing",
          "\u062A\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0631\u0635\u064A\u062F \u0646\u0642\u0627\u0637 \u0628\u0631\u0643\u0629."
        );
      }
      const currentPoints = Math.max(
        0,
        Math.floor(Number(customer.loyaltyPoints || 0))
      );
      const repairResult = await firestoreCommit(
        env,
        token,
        [
          updateWrite(
            env,
            `users/${encodeURIComponent(order.customerId)}`,
            {
              loyaltyPoints: currentPoints + pointsUsed2,
              updatedAt: /* @__PURE__ */ new Date()
            },
            customer.updateTime
          ),
          updateWrite(
            env,
            `orders/${encodeURIComponent(orderId)}`,
            {
              barakahPointsRefunded: true,
              barakahPointsRefundedAmount: pointsUsed2,
              barakahPointsRefundedAt: /* @__PURE__ */ new Date(),
              updatedAt: /* @__PURE__ */ new Date()
            },
            order.updateTime
          )
        ]
      );
      if (!repairResult) {
        continue;
      }
      return {
        orderId,
        status: "cancelled",
        pointsRefunded: pointsUsed2,
        repairedRefund: true
      };
    }
    if (!(/* @__PURE__ */ new Set(["new", "scheduled"])).has(order.status)) {
      fail(
        409,
        "order-cannot-cancel",
        "\u0644\u0627 \u064A\u0645\u0643\u0646 \u0625\u0644\u063A\u0627\u0621 \u0627\u0644\u0637\u0644\u0628 \u0628\u0639\u062F \u0642\u0628\u0648\u0644 \u0627\u0644\u0645\u062A\u062C\u0631 \u0644\u0647."
      );
    }
    const pointsUsed = Math.max(
      0,
      Math.floor(Number(order.barakahPointsUsed || 0))
    );
    const writes = [];
    if (pointsUsed > 0 && order.barakahPointsRefunded !== true && order.customerId) {
      const customer = await firestoreGet(
        env,
        token,
        `users/${encodeURIComponent(order.customerId)}`
      );
      if (!customer) {
        fail(
          409,
          "refund-data-missing",
          "\u062A\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0631\u0635\u064A\u062F \u0646\u0642\u0627\u0637 \u0628\u0631\u0643\u0629."
        );
      }
      const currentPoints = Math.max(
        0,
        Math.floor(Number(customer.loyaltyPoints || 0))
      );
      writes.push(
        updateWrite(
          env,
          `users/${encodeURIComponent(order.customerId)}`,
          {
            loyaltyPoints: currentPoints + pointsUsed,
            updatedAt: /* @__PURE__ */ new Date()
          },
          customer.updateTime
        )
      );
    }
    writes.push(
      updateWrite(
        env,
        `orders/${encodeURIComponent(orderId)}`,
        {
          status: "cancelled",
          cancelledBy: "customer",
          cancelledAt: /* @__PURE__ */ new Date(),
          barakahPointsRefunded: pointsUsed > 0 ? true : order.barakahPointsRefunded === true,
          barakahPointsRefundedAmount: pointsUsed > 0 ? pointsUsed : Number(order.barakahPointsRefundedAmount || 0),
          ...pointsUsed > 0 ? { barakahPointsRefundedAt: /* @__PURE__ */ new Date() } : {},
          updatedAt: /* @__PURE__ */ new Date()
        },
        order.updateTime
      )
    );
    const result = await firestoreCommit(
      env,
      token,
      writes
    );
    if (result) {
      return {
        orderId,
        status: "cancelled",
        pointsRefunded: pointsUsed
      };
    }
  }
  fail(
    409,
    "order-changed",
    "\u062A\u063A\u064A\u0651\u0631\u062A \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u0637\u0644\u0628 \u0623\u0648 \u0627\u0644\u0646\u0642\u0627\u0637\u061B \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627."
  );
}
__name(cancelCustomerOrder, "cancelCustomerOrder");
async function updateOrderStatus(request, env, user, orderId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(orderId)) fail(400, "invalid-order", "\u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  const data = await readJson(request);
  const allowed = /* @__PURE__ */ new Set(["accepted", "preparing", "ready", "rejected", "picked_up", "delivered"]);
  if (!allowed.has(data.status)) fail(400, "invalid-status", "\u062D\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D\u0629.");
  const token = await serviceToken(env);
  const [actor, order] = await Promise.all([
    firestoreGet(env, token, `users/${encodeURIComponent(user.uid)}`),
    firestoreGet(env, token, `orders/${encodeURIComponent(orderId)}`)
  ]);
  if (!order) fail(404, "order-not-found", "\u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F.");
  const isAdmin = actor?.role === "admin";
  const isMerchant = actor?.role === "merchant" && order.businessId && (await firestoreGet(env, token, `items/${encodeURIComponent(order.businessId)}`))?.ownerId === user.uid;
  const isDriver = actor?.role === "driver" && order.driverId === user.uid;
  const merchantStates = /* @__PURE__ */ new Set(["accepted", "preparing", "ready", "rejected"]);
  const driverStates = /* @__PURE__ */ new Set(["picked_up", "delivered"]);
  if (!isAdmin && !(isMerchant && merchantStates.has(data.status)) && !(isDriver && driverStates.has(data.status))) {
    fail(403, "permission-denied", "\u0644\u0627 \u062A\u0645\u0644\u0643 \u0635\u0644\u0627\u062D\u064A\u0629 \u062A\u063A\u064A\u064A\u0631 \u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628.");
  }
  const transitions = {
    new: /* @__PURE__ */ new Set(["accepted", "rejected"]),
    scheduled: /* @__PURE__ */ new Set(["accepted", "rejected"]),
    accepted: /* @__PURE__ */ new Set(["preparing", "rejected"]),
    preparing: /* @__PURE__ */ new Set(["ready", "rejected"]),
    ready: /* @__PURE__ */ new Set([]),
    driver_assigned: /* @__PURE__ */ new Set(["picked_up"]),
    picked_up: /* @__PURE__ */ new Set(["delivered"])
  };
  const adminTransitions = {
    new: /* @__PURE__ */ new Set(["accepted", "rejected"]),
    scheduled: /* @__PURE__ */ new Set(["accepted", "rejected"]),
    accepted: /* @__PURE__ */ new Set(["preparing", "rejected"]),
    preparing: /* @__PURE__ */ new Set(["ready", "rejected"]),
    ready: /* @__PURE__ */ new Set([]),
    driver_assigned: /* @__PURE__ */ new Set(["picked_up"]),
    picked_up: /* @__PURE__ */ new Set(["delivered"])
  };
  if (isAdmin) {
    final:
      if (order.status === "ready" && data.status === "delivered" && order.deliveryMethod === "pickup") {
      } else if (!adminTransitions[order.status]?.has(data.status)) {
        fail(
          409,
          "invalid-transition",
          "\u0637\u0644\u0628 \u0627\u0644\u062A\u0648\u0635\u064A\u0644 \u064A\u062C\u0628 \u0623\u0646 \u064A\u0645\u0631 \u0628\u0627\u0644\u0633\u0627\u0626\u0642 \u0642\u0628\u0644 \u062A\u0623\u0643\u064A\u062F \u0627\u0644\u062A\u0633\u0644\u064A\u0645."
        );
      }
  } else if (!transitions[order.status]?.has(data.status)) {
    fail(409, "invalid-transition", "\u0644\u0627 \u064A\u0645\u0643\u0646 \u0646\u0642\u0644 \u0627\u0644\u0637\u0644\u0628 \u0625\u0644\u0649 \u0647\u0630\u0647 \u0627\u0644\u062D\u0627\u0644\u0629 \u0627\u0644\u0622\u0646.");
  }
  if (order.status === "scheduled" && order.scheduledFor && Date.parse(order.scheduledFor) > Date.now() && !isAdmin) {
    fail(409, "scheduled-order", "\u0644\u0645 \u064A\u062D\u0646 \u0645\u0648\u0639\u062F \u0627\u0644\u0637\u0644\u0628 \u0627\u0644\u0645\u062C\u062F\u0648\u0644 \u0628\u0639\u062F.");
  }
  if (data.status === "ready") {
    return publishOrderToDrivers(env, token, order, orderId);
  }
  if (data.status === "delivered") {
    return completeDelivery(env, token, order, orderId, user.uid, isAdmin);
  }
  const timestampField = data.status === "accepted" ? { acceptedAt: /* @__PURE__ */ new Date() } : {};
  const result = await firestoreCommit(env, token, [updateWrite(
    env,
    `orders/${encodeURIComponent(orderId)}`,
    { status: data.status, updatedAt: /* @__PURE__ */ new Date(), ...timestampField },
    order.updateTime
  )]);
  if (!result) {
    fail(
      409,
      "order-changed",
      "\u062A\u063A\u064A\u0651\u0631\u062A \u062D\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628\u061B \u062D\u062F\u0651\u062B \u0627\u0644\u0635\u0641\u062D\u0629."
    );
  }
  try {
    await notifyCustomerOrderStatus(
      env,
      token,
      { ...order, status: data.status },
      orderId,
      data.status
    );
  } catch (error) {
    console.error(
      "customer_status_notification_failed",
      error.message
    );
  }
  return {
    orderId,
    status: data.status
  };
}
__name(updateOrderStatus, "updateOrderStatus");
async function publishOrderToDrivers(env, token, order, orderId) {
  if (order.deliveryMethod === "pickup") {
    const result2 = await firestoreCommit(env, token, [
      updateWrite(
        env,
        `orders/${encodeURIComponent(orderId)}`,
        {
          status: "ready",
          awaitingDriver: false,
          updatedAt: /* @__PURE__ */ new Date()
        },
        order.updateTime
      )
    ]);
    if (!result2) {
      fail(409, "order-changed", "\u062A\u063A\u064A\u0651\u0631\u062A \u062D\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628\u061B \u062D\u062F\u0651\u062B \u0627\u0644\u0635\u0641\u062D\u0629.");
    }
    return {
      orderId,
      status: "ready",
      awaitingDriver: false
    };
  }
  const drivers = await firestoreQuery(env, token, "users", [
    fieldEquals("role", "driver"),
    fieldEquals("driverAvailable", true)
  ]);
  const availableDrivers = drivers.filter((driver) => driver.driverBusy !== true && Number.isFinite(Number(driver.driverLatitude)) && Number.isFinite(Number(driver.driverLongitude)));
  const result = await firestoreCommit(env, token, [
    updateWrite(
      env,
      `orders/${encodeURIComponent(orderId)}`,
      {
        status: "awaiting_driver",
        awaitingDriver: true,
        availableDriverCount: availableDrivers.length,
        driverBroadcastAt: /* @__PURE__ */ new Date(),
        updatedAt: /* @__PURE__ */ new Date()
      },
      order.updateTime
    )
  ]);
  if (!result) {
    fail(409, "order-changed", "\u062A\u063A\u064A\u0651\u0631\u062A \u062D\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628\u061B \u062D\u062F\u0651\u062B \u0627\u0644\u0635\u0641\u062D\u0629.");
  }
  const driverTokens = availableDrivers.flatMap((driver) => Array.isArray(driver.fcmTokens) ? driver.fcmTokens : []);
  if (driverTokens.length > 0) {
    const orderLabel = String(
      order.orderNumber || orderId.substring(0, 6).toUpperCase()
    );
    try {
      await sendPushToTokens(
        env,
        token,
        driverTokens,
        {
          title: "\u0637\u0644\u0628 \u062A\u0648\u0635\u064A\u0644 \u062C\u062F\u064A\u062F \u{1F697}",
          body: `\u0637\u0644\u0628 #${orderLabel} \u062C\u0627\u0647\u0632 \u0645\u0646 ${order.businessTitle || "\u0623\u062D\u062F \u0627\u0644\u0645\u062D\u0644\u0627\u062A"}. \u0627\u0641\u062A\u062D \u0644\u0648\u062D\u0629 \u0627\u0644\u0633\u0627\u0626\u0642 \u0644\u0642\u0628\u0648\u0644\u0647.`,
          data: {
            type: "driver_order_available",
            orderId,
            orderNumber: orderLabel
          }
        }
      );
    } catch (error) {
      console.error(
        "driver_broadcast_notification_failed",
        error.message
      );
    }
  }
  console.log("DRIVER_BROADCAST_RESULT", {
    orderId,
    availableDrivers: availableDrivers.length,
    pushTokens: driverTokens.length
  });
  return {
    orderId,
    status: "awaiting_driver",
    awaitingDriver: true,
    availableDrivers: availableDrivers.length
  };
}
__name(publishOrderToDrivers, "publishOrderToDrivers");
async function listAvailableDriverOrders(env, user) {
  const token = await serviceToken(env);
  const driver = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );
  if (!driver || driver.role !== "driver") {
    fail(403, "permission-denied", "\u0647\u0630\u0647 \u0627\u0644\u062E\u062F\u0645\u0629 \u0645\u062A\u0627\u062D\u0629 \u0644\u0644\u0633\u0627\u0626\u0642\u064A\u0646 \u0641\u0642\u0637.");
  }
  if (driver.driverAvailable !== true || driver.driverBusy === true) {
    return { orders: [] };
  }
  const orders = await firestoreQuery(env, token, "orders", [
    fieldEquals("status", "awaiting_driver")
  ]);
  return {
    orders: orders.filter((order) => order.deliveryMethod !== "pickup").map((order) => ({
      id: order.id,
      orderNumber: order.orderNumber || null,
      businessTitle: order.businessTitle || null,
      total: Number(order.total || 0)
    })).slice(0, 30)
  };
}
__name(listAvailableDriverOrders, "listAvailableDriverOrders");
async function waitingDriverOrders(env, token) {
  const orders = await firestoreQuery(env, token, "orders", [
    fieldEquals("status", "awaiting_driver")
  ]);
  return orders.filter(
    (order) => order.deliveryMethod !== "pickup" && !order.driverId
  );
}
__name(waitingDriverOrders, "waitingDriverOrders");
async function notifyDriverAboutWaitingOrders(env, token, driver, orders) {
  const waitingOrders = orders ?? await waitingDriverOrders(env, token);
  const driverTokens = Array.isArray(driver?.fcmTokens) ? driver.fcmTokens : [];
  if (!waitingOrders.length || !driverTokens.length) return waitingOrders.length;
  const firstOrder = waitingOrders[0];
  const orderLabel = String(
    firstOrder.orderNumber || firstOrder.id?.substring(0, 6).toUpperCase() || "جديد"
  );
  await sendPushToTokens(env, token, driverTokens, {
    title: "طلب بحاجة لسائق 🚗",
    body: waitingOrders.length === 1
      ? `الطلب #${orderLabel} جاهز. افتح لوحة السائق للموافقة عليه.`
      : `يوجد ${waitingOrders.length} طلبات جاهزة بانتظار سائق. افتح لوحة السائق للموافقة.`,
    data: {
      type: "driver_order_available",
      orderId: String(firstOrder.id || ""),
      waitingOrderCount: String(waitingOrders.length)
    }
  });
  return waitingOrders.length;
}
__name(notifyDriverAboutWaitingOrders, "notifyDriverAboutWaitingOrders");
async function setDriverAvailability(request, env, user) {
  const body = await readJson(request);
  const available = body?.available === true;
  const token = await serviceToken(env);
  const driver = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );
  if (!driver || driver.role !== "driver") {
    fail(403, "permission-denied", "هذه الخدمة متاحة للسائقين فقط.");
  }
  if (available && driver.activeOrderId) {
    fail(409, "driver-has-active-order", "أكمل الطلب الحالي قبل استقبال طلب جديد.");
  }
  const latitude = Number(body?.latitude);
  const longitude = Number(body?.longitude);
  if (
    available &&
    (!Number.isFinite(latitude) || !Number.isFinite(longitude))
  ) {
    fail(400, "driver-location-required", "يجب تحديد موقع السائق أولًا.");
  }
  const result = await firestoreCommit(env, token, [
    updateWrite(
      env,
      `users/${encodeURIComponent(user.uid)}`,
      {
        driverAvailable: available,
        driverBusy: false,
        ...(available ? {
          driverLatitude: latitude,
          driverLongitude: longitude
        } : {}),
        driverLocationUpdatedAt: /* @__PURE__ */ new Date(),
        updatedAt: /* @__PURE__ */ new Date()
      },
      driver.updateTime
    )
  ]);
  if (!result) {
    fail(409, "driver-changed", "تغيّرت حالة السائق. حاول مجددًا.");
  }
  let waitingOrderCount = 0;
  if (available) {
    waitingOrderCount = await notifyDriverAboutWaitingOrders(
      env,
      token,
      driver
    );
  }
  return { available, waitingOrderCount };
}
__name(setDriverAvailability, "setDriverAvailability");
async function claimDriverOrder(env, user, orderId) {
  const token = await serviceToken(env);
  const [driver, order] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(
      env,
      token,
      `orders/${encodeURIComponent(orderId)}`
    )
  ]);
  if (!driver || driver.role !== "driver") {
    fail(403, "permission-denied", "\u0647\u0630\u0647 \u0627\u0644\u062E\u062F\u0645\u0629 \u0645\u062A\u0627\u062D\u0629 \u0644\u0644\u0633\u0627\u0626\u0642\u064A\u0646 \u0641\u0642\u0637.");
  }
  if (driver.driverAvailable !== true || driver.driverBusy === true) {
    fail(409, "driver-unavailable", "\u0641\u0639\u0651\u0644 \u062D\u0627\u0644\u0629 \u0645\u062A\u0627\u062D \u0642\u0628\u0644 \u0642\u0628\u0648\u0644 \u0627\u0644\u0637\u0644\u0628.");
  }
  if (!order) {
    fail(404, "order-not-found", "\u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F.");
  }
  if (order.status !== "awaiting_driver" || order.driverId) {
    fail(409, "order-taken", "\u0633\u0628\u0642 \u0623\u0646 \u0627\u0633\u062A\u0644\u0645 \u0633\u0627\u0626\u0642 \u0622\u062E\u0631 \u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628.");
  }
  const result = await firestoreCommit(env, token, [
    updateWrite(
      env,
      `orders/${encodeURIComponent(orderId)}`,
      {
        status: "driver_assigned",
        awaitingDriver: false,
        driverId: user.uid,
        driverName: driver.fullName || driver.displayName || driver.email || "\u0633\u0627\u0626\u0642 \u0628\u0631\u0643\u0629",
        driverPhone: driver.driverPhone || driver.phone || null,
        driverAcceptedAt: /* @__PURE__ */ new Date(),
        updatedAt: /* @__PURE__ */ new Date()
      },
      order.updateTime
    ),
    updateWrite(
      env,
      `users/${encodeURIComponent(user.uid)}`,
      {
        driverAvailable: false,
        driverBusy: true,
        activeOrderId: orderId,
        updatedAt: /* @__PURE__ */ new Date()
      },
      driver.updateTime
    )
  ]);
  if (!result) {
    fail(409, "order-taken", "\u0633\u0628\u0642 \u0623\u0646 \u0627\u0633\u062A\u0644\u0645 \u0633\u0627\u0626\u0642 \u0622\u062E\u0631 \u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628.");
  }
  console.log("DRIVER_CLAIM_RESULT", {
    orderId,
    driverId: user.uid
  });
  return {
    orderId,
    status: "driver_assigned",
    driverId: user.uid
  };
}
__name(claimDriverOrder, "claimDriverOrder");
async function completeDelivery(env, token, initialOrder, orderId, actorId, isAdmin = false) {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const order = attempt === 0 ? initialOrder : await firestoreGet(env, token, `orders/${encodeURIComponent(orderId)}`);
    if (!order) fail(404, "order-not-found", "\u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F.");
    if (order.rewardGranted === true && order.status === "delivered") {
      return { orderId, status: "delivered", repeated: true };
    }
    if (!isAdmin && (order.driverId !== actorId || order.status !== "picked_up")) {
      fail(409, "invalid-transition", "\u0644\u0627 \u064A\u0645\u0643\u0646 \u0625\u062A\u0645\u0627\u0645 \u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628 \u0627\u0644\u0622\u0646.");
    }
    const assignedDriverId = String(order.driverId || "").trim();
    const [customer, settings, driver] = await Promise.all([
      firestoreGet(env, token, `users/${encodeURIComponent(order.customerId)}`),
      firestoreGet(env, token, "app_settings/loyalty"),
      assignedDriverId ? firestoreGet(env, token, `users/${encodeURIComponent(assignedDriverId)}`) : Promise.resolve(null)
    ]);
    if (!customer) fail(409, "customer-missing", "\u062D\u0633\u0627\u0628 \u0627\u0644\u0632\u0628\u0648\u0646 \u063A\u064A\u0631 \u0645\u062A\u0627\u062D.");
    const oldPoints = Math.max(
      0,
      Number(customer.loyaltyPoints || 0)
    );
    const orderTotal = Math.max(
      0,
      Number(order.total ?? 0)
    );
    const pointsPerShekel = Math.max(
      1,
      Number(settings?.pointsPerShekel || 2)
    );
    const earnedPoints = Math.round(
      orderTotal * pointsPerShekel
    );
    const newPoints = oldPoints + earnedPoints;
    const threshold = Math.max(
      1,
      Number(settings?.pointsPerCoupon || 100)
    );
    const discount = Math.min(100, Math.max(1, Number(settings?.discountPercent || 10)));
    const writes = [
      updateWrite(env, `orders/${encodeURIComponent(orderId)}`, {
        status: "delivered",
        rewardGranted: true,
        deliveredAt: /* @__PURE__ */ new Date(),
        rewardGrantedAt: /* @__PURE__ */ new Date(),
        accountingFinalizedAt: /* @__PURE__ */ new Date(),
        loyaltyPointsAwarded: earnedPoints,
        loyaltyPointsPerShekel: pointsPerShekel,
        loyaltyRewardOrderTotal: orderTotal,
        updatedAt: /* @__PURE__ */ new Date()
      }, order.updateTime),
      updateWrite(env, `users/${encodeURIComponent(order.customerId)}`, {
        loyaltyPoints: newPoints,
        completedPurchases: Number(customer.completedPurchases || 0) + 1,
        updatedAt: /* @__PURE__ */ new Date()
      }, customer.updateTime),
      loyaltyTransactionWrite(
        env,
        `order_REWARD_${orderId}`,
        {
          customerId: order.customerId,
          type: "earn",
          pointsDelta: earnedPoints,
          balanceBefore: oldPoints,
          balanceAfter: newPoints,
          orderId,
          orderNumber: order.orderNumber || null,
          source: "completed_order",
          description: `\u0645\u0643\u0627\u0641\u0623\u0629 ${earnedPoints} \u0646\u0642\u0637\u0629 \u0628\u0639\u062F \u062A\u0633\u0644\u064A\u0645 \u0627\u0644\u0637\u0644\u0628`,
          metadata: {
            orderTotal,
            pointsPerShekel
          }
        }
      )
    ];
    if (driver && assignedDriverId) writes.push(updateWrite(
      env,
      `users/${encodeURIComponent(assignedDriverId)}`,
      {
        driverAvailable: true,
        driverBusy: false,
        activeOrderId: null,
        updatedAt: /* @__PURE__ */ new Date()
      },
      driver.updateTime
    ));
    if (Math.floor(newPoints / threshold) > Math.floor(oldPoints / threshold)) {
      const couponId = crypto.randomUUID().replace(/-/g, "");
      writes.push({ update: {
        name: documentName(env, `coupons/${couponId}`),
        fields: encodeFields({
          customerId: order.customerId,
          code: `BARAKAH-${couponId.substring(0, 6).toUpperCase()}`,
          discountPercent: discount,
          pointsRequired: threshold,
          status: "active",
          source: "loyalty",
          createdAt: /* @__PURE__ */ new Date()
        })
      }, currentDocument: { exists: false } });
    }
    const result = await firestoreCommit(env, token, writes);
    if (result) {
      try {
        await notifyCustomerOrderStatus(
          env,
          token,
          order,
          orderId,
          "delivered"
        );
      } catch (error) {
        console.error(
          "customer_status_notification_failed",
          error.message
        );
      }
      if (driver && assignedDriverId) {
        try {
          await notifyDriverAboutWaitingOrders(env, token, driver);
        } catch (error) {
          console.error(
            "waiting_driver_notification_failed",
            error.message
          );
        }
      }
      return {
        orderId,
        status: "delivered",
        loyaltyPoints: newPoints
      };
    }
  }
  fail(409, "reward-conflict", "\u062A\u063A\u064A\u0651\u0631\u062A \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u0646\u0642\u0627\u0637\u061B \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627.");
}
__name(completeDelivery, "completeDelivery");
function validatePlayTask(orderId, taskId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(orderId)) {
    fail(400, "invalid-order", "\u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  }
  const allowedTasks = /* @__PURE__ */ new Set(["snakes", "istighfar", "goldWorm"]);
  if (!allowedTasks.has(taskId)) {
    fail(400, "invalid-task", "\u0627\u0644\u0645\u0647\u0645\u0629 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D\u0629.");
  }
}
__name(validatePlayTask, "validatePlayTask");
function assertRewardOrder(order, user) {
  if (!order || order.customerId !== user.uid) {
    fail(403, "permission-denied", "\u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628 \u0644\u0627 \u064A\u062E\u0635 \u062D\u0633\u0627\u0628\u0643.");
  }
  if ((/* @__PURE__ */ new Set([
    "rejected",
    "cancelled",
    "canceled",
    "delivered",
    "completed",
    "finished"
  ])).has(order.status)) {
    fail(409, "order-inactive", "\u064A\u062C\u0628 \u0625\u0643\u0645\u0627\u0644 \u0627\u0644\u0645\u0647\u0645\u0629 \u0642\u0628\u0644 \u0627\u0646\u062A\u0647\u0627\u0621 \u0627\u0644\u0637\u0644\u0628.");
  }
}
__name(assertRewardOrder, "assertRewardOrder");
function orderRewardDeadline(order) {
  const orderCreatedAt = Date.parse(order.createdAt || order.createTime || "");
  if (!Number.isFinite(orderCreatedAt)) {
    fail(409, "order-time-missing", "\u062A\u0639\u0630\u0631 \u062A\u062B\u0628\u064A\u062A \u0648\u0642\u062A \u0627\u0644\u0637\u0644\u0628.");
  }
  return orderCreatedAt + 30 * 60 * 1e3;
}
__name(orderRewardDeadline, "orderRewardDeadline");
async function startPlayTask(request, env, user, orderId, taskId) {
  validatePlayTask(orderId, taskId);
  const data = await readJson(request);
  if (Number(data.rulesVersion) !== 5) {
    fail(409, "outdated-game", "\u062D\u062F\u0651\u062B \u0627\u0644\u062A\u0637\u0628\u064A\u0642 \u0644\u0628\u062F\u0621 \u062A\u062D\u062F\u064A \u0627\u0644\u0646\u0642\u0627\u0637.");
  }
  const token = await serviceToken(env);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const order = await firestoreGet(
      env,
      token,
      `orders/${encodeURIComponent(orderId)}`
    );
    assertRewardOrder(order, user);
    if (order.playRewardTasks?.[taskId] === true) {
      fail(409, "task-completed", "\u0647\u0630\u0647 \u0627\u0644\u0645\u0647\u0645\u0629 \u0645\u062D\u0633\u0648\u0628\u0629 \u0633\u0627\u0628\u0642\u064B\u0627.");
    }
    const now = Date.now();
    const orderDeadline = orderRewardDeadline(order);
    if (now > orderDeadline) {
      fail(
        409,
        "reward-window-ended",
        "\u0627\u0646\u062A\u0647\u062A \u0645\u0647\u0644\u0629 \u0646\u0642\u0627\u0637 \u0627\u0644\u0644\u0639\u0628\u061B \u062A\u064F\u062D\u062A\u0633\u0628 \u0627\u0644\u0645\u0647\u0627\u0645 \u062E\u0644\u0627\u0644 \u0623\u0648\u0644 30 \u062F\u0642\u064A\u0642\u0629 \u0641\u0642\u0637."
      );
    }
    const sessions = order.playTaskSessions || {};
    const existing = sessions[taskId];
    if (existing?.sessionId) {
      const expiresAt2 = Date.parse(existing.expiresAt || "");
      if (Number.isFinite(expiresAt2) && now <= expiresAt2) {
        return {
          sessionId: existing.sessionId,
          startedAt: existing.startedAt,
          expiresAt: existing.expiresAt,
          resumed: true
        };
      }
      fail(
        409,
        "task-window-ended",
        "\u0627\u0646\u062A\u0647\u062A \u0627\u0644\u062F\u0642\u0627\u0626\u0642 \u0627\u0644\u0639\u0634\u0631 \u0644\u0647\u0630\u0647 \u0627\u0644\u0645\u0647\u0645\u0629. \u062C\u0631\u0651\u0628 \u0645\u0647\u0645\u0629 \u0623\u062E\u0631\u0649."
      );
    }
    const startedAt = new Date(now);
    const expiresAt = new Date(Math.min(now + 10 * 60 * 1e3, orderDeadline));
    const session = {
      sessionId: crypto.randomUUID().replace(/-/g, ""),
      rulesVersion: 5,
      startedAt,
      expiresAt
    };
    const result = await firestoreCommit(env, token, [updateWrite(
      env,
      `orders/${encodeURIComponent(orderId)}`,
      {
        playTaskSessions: { ...sessions, [taskId]: session },
        updatedAt: /* @__PURE__ */ new Date()
      },
      order.updateTime
    )]);
    if (result) {
      return {
        sessionId: session.sessionId,
        startedAt: startedAt.toISOString(),
        expiresAt: expiresAt.toISOString(),
        resumed: false
      };
    }
  }
  fail(409, "session-conflict", "\u062A\u0639\u0630\u0631 \u062A\u062B\u0628\u064A\u062A \u0639\u062F\u0627\u062F \u0627\u0644\u0645\u0647\u0645\u0629\u061B \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627.");
}
__name(startPlayTask, "startPlayTask");
async function claimPlayTask(request, env, user, orderId, taskId) {
  validatePlayTask(orderId, taskId);
  const data = await readJson(request);
  const token = await serviceToken(env);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const [order, customer, settings] = await Promise.all([
      firestoreGet(env, token, `orders/${encodeURIComponent(orderId)}`),
      firestoreGet(env, token, `users/${encodeURIComponent(user.uid)}`),
      firestoreGet(env, token, "app_settings/loyalty")
    ]);
    assertRewardOrder(order, user);
    if (!customer) fail(409, "customer-missing", "\u062D\u0633\u0627\u0628 \u0627\u0644\u0632\u0628\u0648\u0646 \u063A\u064A\u0631 \u0645\u062A\u0627\u062D.");
    const completed = order.playRewardTasks || {};
    const oldPoints = Math.max(0, Number(customer.loyaltyPoints || 0));
    if (completed[taskId] === true) {
      return { alreadyClaimed: true, loyaltyPoints: oldPoints };
    }
    const orderDeadline = orderRewardDeadline(order);
    if (Date.now() > orderDeadline) {
      fail(
        409,
        "reward-window-ended",
        "\u0627\u0646\u062A\u0647\u062A \u0645\u0647\u0644\u0629 \u0646\u0642\u0627\u0637 \u0627\u0644\u0644\u0639\u0628\u061B \u062A\u064F\u062D\u062A\u0633\u0628 \u0627\u0644\u0645\u0647\u0627\u0645 \u062E\u0644\u0627\u0644 \u0623\u0648\u0644 30 \u062F\u0642\u064A\u0642\u0629 \u0645\u0646 \u0627\u0644\u0637\u0644\u0628 \u0641\u0642\u0637."
      );
    }
    const sessions = order.playTaskSessions || {};
    const session = sessions[taskId];
    const sessionExpiresAt = Date.parse(session?.expiresAt || "");
    if (!session || session.sessionId !== String(data.sessionId || "") || Number(data.rulesVersion) !== 5 || Number(data.successfulUnits) !== 5) {
      fail(
        409,
        "invalid-game-proof",
        "\u062A\u0639\u0630\u0631 \u0627\u0644\u062A\u062D\u0642\u0642 \u0645\u0646 \u0625\u0646\u062C\u0627\u0632 \u0627\u0644\u062C\u0648\u0644\u0627\u062A \u0627\u0644\u062E\u0645\u0633 \u0644\u0647\u0630\u0647 \u0627\u0644\u0645\u0647\u0645\u0629."
      );
    }
    if (!Number.isFinite(sessionExpiresAt) || Date.now() > sessionExpiresAt + 5e3) {
      fail(
        409,
        "task-window-ended",
        "\u0627\u0646\u062A\u0647\u062A \u0627\u0644\u062F\u0642\u0627\u0626\u0642 \u0627\u0644\u0639\u0634\u0631 \u0642\u0628\u0644 \u062A\u0633\u062C\u064A\u0644 \u0625\u0646\u062C\u0627\u0632 \u0627\u0644\u0645\u0647\u0645\u0629."
      );
    }
    const earnedPoints = 2;
    const newPoints = oldPoints + earnedPoints;
    const threshold = Math.max(1, Number(settings?.pointsPerCoupon || 100));
    const discount = Math.min(
      100,
      Math.max(1, Number(settings?.discountPercent || 10))
    );
    const writes = [
      updateWrite(env, `orders/${encodeURIComponent(orderId)}`, {
        playRewardTasks: { ...completed, [taskId]: true },
        playTaskSessions: {
          ...sessions,
          [taskId]: { ...session, claimedAt: /* @__PURE__ */ new Date() }
        },
        playRewardPointsAwarded: Number(order.playRewardPointsAwarded || 0) + earnedPoints,
        updatedAt: /* @__PURE__ */ new Date()
      }, order.updateTime),
      updateWrite(env, `users/${encodeURIComponent(user.uid)}`, {
        loyaltyPoints: newPoints,
        playRewardPoints: Number(customer.playRewardPoints || 0) + earnedPoints,
        updatedAt: /* @__PURE__ */ new Date()
      }, customer.updateTime),
      loyaltyTransactionWrite(
        env,
        `game_${orderId}_${taskId}`,
        {
          customerId: user.uid,
          type: "game_reward",
          pointsDelta: earnedPoints,
          balanceBefore: oldPoints,
          balanceAfter: newPoints,
          orderId,
          orderNumber: order.orderNumber || null,
          source: "play_reward",
          description: `\u0645\u0643\u0627\u0641\u0623\u0629 \u0644\u0639\u0628\u0629: +${earnedPoints} \u0646\u0642\u0637\u0629`,
          metadata: {
            taskId
          }
        }
      )
    ];
    if (Math.floor(newPoints / threshold) > Math.floor(oldPoints / threshold)) {
      const couponId = crypto.randomUUID().replace(/-/g, "");
      writes.push({ update: {
        name: documentName(env, `coupons/${couponId}`),
        fields: encodeFields({
          customerId: user.uid,
          code: `BARAKAH-${couponId.substring(0, 6).toUpperCase()}`,
          discountPercent: discount,
          pointsRequired: threshold,
          status: "active",
          source: "play_reward",
          createdAt: /* @__PURE__ */ new Date()
        })
      }, currentDocument: { exists: false } });
    }
    const result = await firestoreCommit(env, token, writes);
    if (result) {
      return { alreadyClaimed: false, earnedPoints, loyaltyPoints: newPoints };
    }
  }
  fail(409, "reward-conflict", "\u062A\u063A\u064A\u0651\u0631\u062A \u0628\u064A\u0627\u0646\u0627\u062A \u0627\u0644\u0646\u0642\u0627\u0637\u061B \u062D\u0627\u0648\u0644 \u0645\u062C\u062F\u062F\u064B\u0627.");
}
__name(claimPlayTask, "claimPlayTask");
function money(value) {
  if (!Number.isFinite(value)) fail(409, "invalid-total", "\u062A\u0639\u0630\u0631 \u062D\u0633\u0627\u0628 \u0627\u0644\u0645\u062C\u0645\u0648\u0639.");
  return Math.round(value * 100) / 100;
}
__name(money, "money");
function finiteOrNull(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
__name(finiteOrNull, "finiteOrNull");
export {
  canUploadMedia,
  createImageKitSignature,
  index_default as default
};
