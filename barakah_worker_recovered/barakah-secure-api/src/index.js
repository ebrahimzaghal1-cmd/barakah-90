import { createFirestoreStore } from './security/store.js';
import { createAppointment, updateAppointment } from './security/appointments.js';
import { createTaxiOrder, updateTaxiOrder, availableTaxiOrders, acceptTaxiOrder } from './security/taxi.js';
var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// src/index.js
var JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };
var MAX_ITEMS = 50;
var PRIMARY_ADMIN_UID = "Y3YeLin9gYTbqN4if72o3iTrUSn2";
function isPrimaryAdmin(user, actor) {
  return user?.uid === PRIMARY_ADMIN_UID && actor?.role === "admin";
}
__name(isPrimaryAdmin, "isPrimaryAdmin");
var index_default = {
  async scheduled(controller, env, ctx) {
    ctx.waitUntil(
      processNotificationOutbox(env).catch((error) => {
        console.error(
          "notification_outbox_scheduled_failed",
          String(error?.message || error)
        );
      })
    );
  },

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

      // ===== BARAKAH COMMUNICATION CAMPAIGNS =====
      if (
        request.method === "POST" &&
        url.pathname === "/v1/admin/communications/campaigns"
      ) {
        return json(
          await createCommunicationCampaign(request, env, user),
          201,
          cors
        );
      }

      if (
        request.method === "POST" &&
        url.pathname === "/v1/admin/communications/campaigns/process"
      ) {
        return json(
          await processCommunicationCampaign(request, env, user),
          200,
          cors
        );
      }

      if (
        request.method === "POST" &&
        url.pathname === "/v1/admin/communications/fcm-cleanup"
      ) {
        return json(
          await cleanupCurrentAdminFcmTokens(request, env, user),
          200,
          cors
        );
      }

      if (request.method === "POST" && url.pathname === "/v1/barber-bookings") {
        const store = createFirestoreStore({ baseUrl: firestoreBase(env), token: await serviceToken(env) });
        return json(await createAppointment(store, user, await readJson(request), { primaryAdminUid: PRIMARY_ADMIN_UID }), 201, cors);
      }
      const appointmentStatusMatch = url.pathname.match(/^\/v1\/barber-bookings\/([^/]+)\/status$/);
      if (request.method === "POST" && appointmentStatusMatch) {
        const store = createFirestoreStore({ baseUrl: firestoreBase(env), token: await serviceToken(env) });
        const input = await readJson(request);
        return json(await updateAppointment(store, user, decodeURIComponent(appointmentStatusMatch[1]), input.status, { primaryAdminUid: PRIMARY_ADMIN_UID }), 200, cors);
      }

      if (request.method === "GET" && url.pathname === "/v1/taxi-driver/orders/available") {
        const store = createFirestoreStore({ baseUrl: firestoreBase(env), token: await serviceToken(env) });
        return json(await availableTaxiOrders(store, user), 200, cors);
      }

      if (request.method === "POST" && url.pathname === "/v1/taxi-orders") {
        const token = await serviceToken(env);
        const store = createFirestoreStore({
          baseUrl: firestoreBase(env),
          token
        });
        const input = await readJson(request);

        const result = await createTaxiOrder(
          store,
          user,
          input,
          { primaryAdminUid: PRIMARY_ADMIN_UID }
        );

        try {
          const order = await firestoreGet(
            env,
            token,
            `taxi_orders/${encodeURIComponent(result.orderId)}`
          );

          await notifyTaxiLifecycle(
            env,
            token,
            order,
            "created",
            user.uid
          );
        } catch (error) {
          console.error(
            "taxi_create_post_notification_failed",
            String(error?.message || error)
          );
        }

        return json(result, 201, cors);
      }

      const taxiOrderActionMatch = url.pathname.match(
        /^\/v1\/taxi-orders\/([^/]+)\/action$/
      );

      if (request.method === "POST" && taxiOrderActionMatch) {
        const token = await serviceToken(env);
        const store = createFirestoreStore({
          baseUrl: firestoreBase(env),
          token
        });

        const orderId =
          decodeURIComponent(taxiOrderActionMatch[1]);

        const input = await readJson(request);
        const action = String(input?.action || "").trim();

        const result = action === "accept"
          ? await acceptTaxiOrder(store, user, orderId)
          : await updateTaxiOrder(
          store,
          user,
          orderId,
          input,
          { primaryAdminUid: PRIMARY_ADMIN_UID }
        );

        if (action !== "update_location") {
          try {
            const order = await firestoreGet(
              env,
              token,
              `taxi_orders/${encodeURIComponent(orderId)}`
            );

            await notifyTaxiLifecycle(
              env,
              token,
              order,
              action === "accept" ? "dispatch" : action,
              user.uid
            );
          } catch (error) {
            console.error(
              "taxi_action_post_notification_failed",
              String(error?.message || error)
            );
          }
        }

        return json(result, 200, cors);
      }


      if (
        request.method === "POST" &&
        url.pathname === "/v1/taxi/drivers/list"
      ) {
        return json(
          await listTaxiOfficeDrivers(
            request,
            env,
            user
          ),
          200,
          cors
        );
      }

      if (request.method === "POST" && url.pathname === "/v1/support/messages") {
        return json(await sendSupportMessage(request, env, user), 201, cors);
      }
      if (request.method === "GET" && url.pathname === "/v1/order-supervisor/orders") {
        return json(await listOrderSupervisorOrders(env, user), 200, cors);
      }
      if (request.method === "POST" && url.pathname === "/v1/admin/new-request") {
        return json(
          await notifyAdminsAboutVerifiedRequest(request, env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/admin/auction/status-notification") {
        return json(
          await notifyAuctionStatus(request, env, user),
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
        const directAdminDelete = body?.directAdminDelete === true;

        if (!targetUid) {
          fail(400, "missing-user-id", "معرّف المستخدم مطلوب.");
        }

        const token = await serviceToken(env);
        const actor = await firestoreGet(
          env,
          token,
          `users/${encodeURIComponent(user.uid)}`
        );

        if (!isPrimaryAdmin(user, actor)) {
          fail(403, "permission-denied", "غير مسموح بتنفيذ حذف الحسابات.");
        }

        if (targetUid === user.uid) {
          fail(403, "admin-account-protected", "لا يمكن للأدمن حذف حسابه من لوحة المستخدمين.");
        }

        const deletionRequest = await firestoreGet(
          env,
          token,
          `account_deletion_requests/${encodeURIComponent(targetUid)}`
        );

        if (
          !directAdminDelete &&
          (
            !deletionRequest ||
            deletionRequest.userId !== targetUid ||
            deletionRequest.status !== "pending"
          )
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
      if (request.method === "POST" && url.pathname === "/v1/merchant/managers") {
        return json(
          await updateBusinessManager(request, env, user),
          200,
          cors
        );
      }
      if (request.method === "POST" && url.pathname === "/v1/admin/taxi/drivers/assign") {
        return json(
          await assignTaxiDriver(request, env, user),
          200,
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
      if (request.method === "POST" && url.pathname === "/v1/agent-orders") {
        return json(await createAgentOrder(request, env, user), 201, cors);
      }

    const agentOrderAcceptMatch = url.pathname.match(
      /^\/v1\/agent-orders\/([^/]+)\/accept$/
    );
    if (request.method === "POST" && agentOrderAcceptMatch) {
      return json(
        await updateAgentOrderStatus(
          env,
          user,
          decodeURIComponent(agentOrderAcceptMatch[1]),
          "accepted"
        ),
        200,
        cors
      );
    }

    const agentOrderRejectMatch = url.pathname.match(
      /^\/v1\/agent-orders\/([^/]+)\/reject$/
    );
    if (request.method === "POST" && agentOrderRejectMatch) {
      return json(
        await updateAgentOrderStatus(
          env,
          user,
          decodeURIComponent(agentOrderRejectMatch[1]),
          "rejected"
        ),
        200,
        cors
      );
    }

  
    const agentOrderDeliveryCodeMatch = url.pathname.match(
      /^\/v1\/agent-orders\/([^/]+)\/delivery-code$/
    );
    if (request.method === "GET" && agentOrderDeliveryCodeMatch) {
      return json(
        await getAgentOrderDeliveryCode(
          env,
          user,
          decodeURIComponent(agentOrderDeliveryCodeMatch[1])
        ),
        200,
        cors
      );
    }


    const agentOrderDisputeMatch = url.pathname.match(
      /^\/v1\/agent-orders\/([^/]+)\/dispute$/
    );
    if (request.method === "POST" && agentOrderDisputeMatch) {
      return json(
        await createAgentOrderDispute(
          request,
          env,
          user,
          decodeURIComponent(agentOrderDisputeMatch[1])
        ),
        201,
        cors
      );
    }

    const agentOrderResolveDisputeMatch = url.pathname.match(
      /^\/v1\/agent-orders\/([^/]+)\/resolve-dispute$/
    );
    if (request.method === "POST" && agentOrderResolveDisputeMatch) {
      return json(
        await resolveAgentOrderDispute(
          request,
          env,
          user,
          decodeURIComponent(agentOrderResolveDisputeMatch[1])
        ),
        200,
        cors
      );
    }

    const agentOrderSettleMatch = url.pathname.match(
      /^\/v1\/agent-orders\/([^/]+)\/settle$/
    );
    if (request.method === "POST" && agentOrderSettleMatch) {
      return json(
        await settleAgentOrderEarning(
          env,
          user,
          decodeURIComponent(agentOrderSettleMatch[1])
        ),
        200,
        cors
      );
    }

    const agentOrderCompleteMatch = url.pathname.match(
      /^\/v1\/agent-orders\/([^/]+)\/complete$/
    );
    if (request.method === "POST" && agentOrderCompleteMatch) {
      return json(
        await completeAgentOrder(
          request,
          env,
          user,
          decodeURIComponent(agentOrderCompleteMatch[1])
        ),
        200,
        cors
      );
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
  const maxBytes = 128e3;
  const length = Number(request.headers.get("content-length") || 0);
  if (length > maxBytes) fail(413, "payload-too-large", "الطلب كبير جدًا.");
  const reader = request.body?.getReader();
  if (!reader) fail(400, "invalid-json", "بيانات الطلب غير صحيحة.");
  const chunks = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel().catch(() => {});
        fail(413, "payload-too-large", "الطلب كبير جدًا.");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch (_) {
    fail(400, "invalid-json", "بيانات الطلب غير صحيحة.");
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
      response.status
    );
    return null;
  }
  if (!response.ok) {
    console.error(
      "firestore_commit_failed",
      response.status
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
async function firestoreQuery(env, token, collectionId, filters = [], decode = decodeDocument) {
  const where = filters.length === 0 ? null : filters.length === 1 ? filters[0] : {
    compositeFilter: { op: "AND", filters }
  };
  const response = await fetch(`${firestoreBase(env)}:runQuery`, {
    method: "POST",
    headers: { ...JSON_HEADERS, authorization: `Bearer ${token}` },
    body: JSON.stringify({ structuredQuery: {
      from: [{ collectionId }],
      ...(where ? { where } : {}),
      limit: 100
    } })
  });
  if (!response.ok) fail(502, "firestore-query-failed", "\u062A\u0639\u0630\u0631 \u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0628\u064A\u0627\u0646\u0627\u062A.");
  const rows = await response.json();
  return rows.filter((row) => row.document).map((row) => decode(row.document));
}
__name(firestoreQuery, "firestoreQuery");
function fieldEquals(fieldPath, value) {
  return { fieldFilter: { field: { fieldPath }, op: "EQUAL", value: encodeValue(value) } };
}
__name(fieldEquals, "fieldEquals");
function fieldArrayContains(fieldPath, value) {
  return { fieldFilter: { field: { fieldPath }, op: "ARRAY_CONTAINS", value: encodeValue(value) } };
}
__name(fieldArrayContains, "fieldArrayContains");

// ===== BARAKAH COMMUNICATION CAMPAIGNS =====

function communicationCampaignProgress(campaign) {
  return {
    campaignId: String(campaign?.id || ""),
    complete: campaign?.complete === true,
    recipientCount: Number(campaign?.recipientCount || 0),
    scannedCount: Number(campaign?.scannedCount || 0),
    pushTargetCount: Number(campaign?.pushTargetCount || 0),
    pageCount: Number(campaign?.pageCount || 0),
    pushSuccessCount: Number(campaign?.pushSuccessCount || 0),
    pushFailureCount: Number(campaign?.pushFailureCount || 0),
    pushUnknownCount: Number(campaign?.pushUnknownCount || 0)
  };
}
__name(communicationCampaignProgress, "communicationCampaignProgress");

async function communicationSha256Hex(value) {
  const bytes = new TextEncoder().encode(String(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}
__name(communicationSha256Hex, "communicationSha256Hex");

function normalizeCommunicationCampaignInput(raw) {
  const title = String(raw?.title || "").trim();
  const body = String(raw?.body || "").trim();
  const audience = String(raw?.audience || "").trim();
  const type = String(raw?.type || "").trim();
  const imageUrl = String(raw?.imageUrl || "").trim();
  const videoUrl = String(raw?.videoUrl || "").trim();
  const mediaType = String(raw?.mediaType || "").trim();

  const allowedAudiences = new Set([
    "admin_only",
    "all",
    "customers",
    "merchants",
    "delivery_drivers",
    "taxi_drivers",
    "agents",
    "customer_service"
  ]);

  const allowedTypes = new Set([
    "message",
    "offer",
    "ad",
    "alert"
  ]);

  if (!title || title.length > 120) {
    fail(400, "invalid-campaign-title", "عنوان الحملة غير صالح.");
  }

  if (body.length > 4000) {
    fail(400, "campaign-body-too-long", "نص الحملة أطول من الحد المسموح.");
  }

  if (!body && !imageUrl && !videoUrl) {
    fail(400, "campaign-content-required", "أضف نصًا أو صورة أو فيديو للحملة.");
  }

  if (!allowedAudiences.has(audience)) {
    fail(400, "invalid-campaign-audience", "جمهور الحملة غير صالح.");
  }

  if (!allowedTypes.has(type)) {
    fail(400, "invalid-campaign-type", "نوع الحملة غير صالح.");
  }

  if (imageUrl && (!/^https:\/\//i.test(imageUrl) || imageUrl.length > 2000)) {
    fail(400, "invalid-campaign-image", "رابط صورة الحملة غير صالح.");
  }

  if (videoUrl && (!/^https:\/\//i.test(videoUrl) || videoUrl.length > 2000)) {
    fail(400, "invalid-campaign-video", "رابط فيديو الحملة غير صالح.");
  }

  if (mediaType && !["image", "video"].includes(mediaType)) {
    fail(400, "invalid-campaign-media-type", "نوع وسائط الحملة غير صالح.");
  }

  return {
    title,
    body,
    audience,
    type,
    imageUrl: imageUrl || null,
    videoUrl: videoUrl || null,
    mediaType: mediaType || null
  };
}
__name(normalizeCommunicationCampaignInput, "normalizeCommunicationCampaignInput");

function communicationAudienceMatches(profile, audience) {
  if (!profile || !profile.id) return false;

  const role = String(profile.role || "").trim();
  const agentNumber = String(profile.agentNumber || "").trim();

  if (audience === "admin_only") {
    return profile.id === PRIMARY_ADMIN_UID;
  }

  if (audience === "all") {
    return role.length > 0;
  }

  if (audience === "customers") {
    return role === "customer" && agentNumber.length === 0;
  }

  if (audience === "merchants") {
    return role === "merchant";
  }

  if (audience === "delivery_drivers") {
    return role === "driver" && profile.taxiDriverEnabled !== true;
  }

  if (audience === "taxi_drivers") {
    return profile.taxiDriverEnabled === true;
  }

  if (audience === "customer_service") {
    return role === "customer_service" &&
      profile.customerServiceEnabled === true;
  }

  return false;
}
__name(communicationAudienceMatches, "communicationAudienceMatches");

async function firestoreListPage(
  env,
  token,
  collectionId,
  pageToken = "",
  pageSize = 40
) {
  const params = new URLSearchParams();
  params.set("pageSize", String(Math.max(1, Math.min(100, pageSize))));
  params.set("orderBy", "__name__");

  if (pageToken) {
    params.set("pageToken", pageToken);
  }

  const response = await fetch(
    `${firestoreBase(env)}/${encodeURIComponent(collectionId)}?${params.toString()}`,
    {
      headers: {
        authorization: `Bearer ${token}`
      }
    }
  );

  if (!response.ok) {
    fail(
      502,
      "firestore-list-failed",
      "تعذر قراءة قائمة مستخدمي الحملة."
    );
  }

  const payload = await response.json();

  return {
    documents: Array.isArray(payload.documents)
      ? payload.documents.map(decodeDocument)
      : [],
    nextPageToken: String(payload.nextPageToken || "")
  };
}
__name(firestoreListPage, "firestoreListPage");


const CAMPAIGN_PAGE_SIZE = 3;
const CAMPAIGN_PUSH_TOKEN_LIMIT = 4;
const FCM_CLEANUP_BATCH_LIMIT = 8;

function selectCampaignPushTokens(deviceTokens) {
  const uniqueTokens = [
    ...new Set(
      (deviceTokens || []).filter(
        (value) => typeof value === "string" && value.length > 20
      )
    )
  ];

  return uniqueTokens.slice(-CAMPAIGN_PUSH_TOKEN_LIMIT);
}
__name(selectCampaignPushTokens, "selectCampaignPushTokens");

function isUnregisteredFcmError(responseText) {
  try {
    const payload = JSON.parse(String(responseText || ""));
    const details = payload?.error?.details;

    return Array.isArray(details) &&
      details.some(
        (detail) =>
          detail?.errorCode === "UNREGISTERED" ||
          detail?.errorCode === "registration-token-not-registered"
      );
  } catch (_) {
    return false;
  }
}
__name(isUnregisteredFcmError, "isUnregisteredFcmError");

function arrayRemoveTransform(fieldPath, values) {
  const uniqueValues = [
    ...new Set(
      (values || []).filter(
        (value) => typeof value === "string" && value.length > 0
      )
    )
  ];

  return {
    fieldPath,
    removeAllFromArray: {
      values: uniqueValues.map((value) => encodeValue(value))
    }
  };
}
__name(arrayRemoveTransform, "arrayRemoveTransform");

async function sendCampaignPushToTokens(
  env,
  token,
  deviceTokens,
  { title, body, data = {}, userId = null }
) {
  const sendable = selectCampaignPushTokens(deviceTokens);

  let successCount = 0;
  let failureCount = 0;
  let unknownCount = 0;
  const invalidTokens = [];

  await Promise.all(
    sendable.map(async (deviceToken) => {
      try {
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
                  body: body || title
                },
                data,
                android: {
                  priority: "HIGH",
                  notification: {
                    sound: "default",
                    channel_id: "barakah_orders",
                    notification_priority: "PRIORITY_HIGH",
                    default_vibrate_timings: true,
                    visibility: "PUBLIC"
                  }
                },
                apns: {
                  headers: {
                    "apns-priority": "10"
                  },
                  payload: {
                    aps: {
                      sound: "default",
                      badge: 1,
                      "interruption-level": "active"
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

        if (response.ok) {
          successCount += 1;
          return;
        }

        const responseText = await response.text();
        failureCount += 1;

        if (isUnregisteredFcmError(responseText)) {
          invalidTokens.push(deviceToken);
        }

        console.error(
          "campaign_push_failed",
          response.status,
          responseText.substring(0, 300)
        );
      } catch (error) {
        unknownCount += 1;
        console.error(
          "campaign_push_unknown",
          String(error?.message || error)
        );
      }
    })
  );

  if (userId && invalidTokens.length) {
    try {
      await firestoreCommit(
        env,
        token,
        [
          updateWrite(
            env,
            `users/${encodeURIComponent(userId)}`,
            {
              fcmTokenUpdatedAt: new Date()
            },
            undefined,
            [
              arrayRemoveTransform("fcmTokens", invalidTokens)
            ]
          )
        ]
      );
    } catch (error) {
      console.error(
        "campaign_invalid_token_cleanup_failed",
        userId,
        String(error?.message || error)
      );
    }
  }

  return {
    targetCount: sendable.length,
    successCount,
    failureCount,
    unknownCount,
    invalidTokenCount: invalidTokens.length
  };
}
__name(sendCampaignPushToTokens, "sendCampaignPushToTokens");

async function validateFcmRegistrationToken(
  env,
  serviceAccessToken,
  deviceToken
) {
  try {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(env.FIREBASE_PROJECT_ID)}/messages:send`,
      {
        method: "POST",
        headers: {
          ...JSON_HEADERS,
          authorization: `Bearer ${serviceAccessToken}`
        },
        body: JSON.stringify({
          validate_only: true,
          message: {
            token: deviceToken,
            data: {
              barakah_token_validation: "1"
            }
          }
        })
      }
    );

    if (response.ok) {
      return {
        state: "valid",
        status: response.status
      };
    }

    const responseText = await response.text();

    if (isUnregisteredFcmError(responseText)) {
      return {
        state: "unregistered",
        status: response.status
      };
    }

    return {
      state: "failed",
      status: response.status
    };
  } catch (_) {
    return {
      state: "unknown",
      status: 0
    };
  }
}
__name(validateFcmRegistrationToken, "validateFcmRegistrationToken");

async function cleanupCurrentAdminFcmTokens(request, env, user) {
  const token = await serviceToken(env);

  const actor = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );

  if (!isPrimaryAdmin(user, actor)) {
    fail(
      403,
      "permission-denied",
      "Primary admin access required."
    );
  }

  const input = await readJson(request);

  const apply = input?.apply === true;
  const rawOffset = Number(input?.offset ?? 0);

  if (!Number.isInteger(rawOffset) || rawOffset < 0) {
    fail(
      400,
      "invalid-offset",
      "Cleanup offset is invalid."
    );
  }

  const sourceTokens = Array.isArray(actor?.fcmTokens)
    ? actor.fcmTokens
    : [];

  const allTokens = [
    ...new Set(
      sourceTokens.filter(
        (value) =>
          typeof value === "string" &&
          value.length > 20
      )
    )
  ];

  const batch = allTokens.slice(
    rawOffset,
    rawOffset + FCM_CLEANUP_BATCH_LIMIT
  );

  const results = await Promise.all(
    batch.map((deviceToken) =>
      validateFcmRegistrationToken(
        env,
        token,
        deviceToken
      )
    )
  );

  const invalidTokens = [];
  let validCount = 0;
  let failedCount = 0;
  let unknownCount = 0;

  for (let index = 0; index < results.length; index += 1) {
    const result = results[index];

    if (result.state === "valid") {
      validCount += 1;
      continue;
    }

    if (result.state === "unregistered") {
      invalidTokens.push(batch[index]);
      continue;
    }

    if (result.state === "unknown") {
      unknownCount += 1;
      continue;
    }

    failedCount += 1;
  }

  let removedCount = 0;

  if (apply && invalidTokens.length) {
    await firestoreCommit(
      env,
      token,
      [
        updateWrite(
          env,
          `users/${encodeURIComponent(user.uid)}`,
          {
            fcmTokenUpdatedAt: new Date()
          },
          undefined,
          [
            arrayRemoveTransform(
              "fcmTokens",
              invalidTokens
            )
          ]
        )
      ]
    );

    removedCount = invalidTokens.length;
  }

  const remainingTokenCount =
    allTokens.length - removedCount;

  const nextOffset =
    rawOffset +
    batch.length -
    removedCount;

  return {
    mode: apply ? "apply" : "dry-run",
    totalTokenCount: allTokens.length,
    checkedCount: batch.length,
    validCount,
    unregisteredCount: invalidTokens.length,
    failedCount,
    unknownCount,
    removedCount,
    nextOffset,
    remainingTokenCount,
    complete:
      batch.length === 0 ||
      nextOffset >= remainingTokenCount
  };
}
__name(cleanupCurrentAdminFcmTokens, "cleanupCurrentAdminFcmTokens");

function campaignDeliveryCounters(delivery) {
  return {
    recipientCount: Number(delivery?.recipientCount || 0),
    pushTargetCount: Number(delivery?.pushTargetCount || 0),
    pushSuccessCount: Number(delivery?.pushSuccessCount || 0),
    pushFailureCount: Number(delivery?.pushFailureCount || 0),
    pushUnknownCount: Number(delivery?.pushUnknownCount || 0)
  };
}
__name(campaignDeliveryCounters, "campaignDeliveryCounters");

async function createCommunicationCampaign(request, env, user) {
  const token = await serviceToken(env);

  const actor = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );

  if (!isPrimaryAdmin(user, actor)) {
    fail(
      403,
      "permission-denied",
      "غير مسموح بإنشاء الحملات."
    );
  }

  const idempotencyKey =
    String(request.headers.get("idempotency-key") || "").trim();

  if (!/^[A-Za-z0-9._:-]{16,128}$/.test(idempotencyKey)) {
    fail(
      400,
      "invalid-idempotency-key",
      "مفتاح إنشاء الحملة غير صالح."
    );
  }

  const input = normalizeCommunicationCampaignInput(
    await readJson(request)
  );

  const payloadHash = await communicationSha256Hex(JSON.stringify(input));
  const creationHash = await communicationSha256Hex(
    `${user.uid}:${idempotencyKey}`
  );

  const campaignId = `cmp_${creationHash.slice(0, 32)}`;

  const existing = await firestoreGet(
    env,
    token,
    `communication_campaigns/${encodeURIComponent(campaignId)}`
  );

  if (existing) {
    if (
      existing.createdBy !== user.uid ||
      existing.payloadHash !== payloadHash
    ) {
      fail(
        409,
        "campaign-idempotency-conflict",
        "تم استخدام مفتاح الحملة لبيانات مختلفة."
      );
    }

    return communicationCampaignProgress(existing);
  }

  const now = new Date();

  const record = {
    ...input,
    createdBy: user.uid,
    payloadHash,
    status: "pending",
    complete: false,
    sourceCollection: input.audience === "agents"
      ? "agents"
      : "users",
    cursor: "",
    recipientCount: 0,
    scannedCount: 0,
    pushTargetCount: 0,
    pushSuccessCount: 0,
    pushFailureCount: 0,
    pushUnknownCount: 0,
    pageCount: 0,
    processingLeaseId: null,
    processingLeaseUntil: null,
    createdAt: now,
    updatedAt: now
  };

  const created = await firestoreCommit(
    env,
    token,
    [
      createWrite(
        env,
        `communication_campaigns/${encodeURIComponent(campaignId)}`,
        record
      )
    ]
  );

  if (!created) {
    const raced = await firestoreGet(
      env,
      token,
      `communication_campaigns/${encodeURIComponent(campaignId)}`
    );

    if (
      !raced ||
      raced.createdBy !== user.uid ||
      raced.payloadHash !== payloadHash
    ) {
      fail(
        409,
        "campaign-create-conflict",
        "تم إنشاء الحملة بالتزامن. حاول مجددًا."
      );
    }

    return communicationCampaignProgress(raced);
  }

  return {
    campaignId,
    complete: false,
    recipientCount: 0,
    scannedCount: 0,
    pushTargetCount: 0,
    pageCount: 0,
    pushSuccessCount: 0,
    pushFailureCount: 0,
    pushUnknownCount: 0
  };
}
__name(createCommunicationCampaign, "createCommunicationCampaign");

async function processCommunicationCampaign(request, env, user) {
  const token = await serviceToken(env);

  const actor = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );

  if (!isPrimaryAdmin(user, actor)) {
    fail(
      403,
      "permission-denied",
      "غير مسموح بمعالجة الحملات."
    );
  }

  const body = await readJson(request);
  const campaignId = String(body?.campaignId || "").trim();

  if (!/^cmp_[a-f0-9]{32}$/.test(campaignId)) {
    fail(
      400,
      "invalid-campaign-id",
      "معرّف الحملة غير صالح."
    );
  }

  let campaign = await firestoreGet(
    env,
    token,
    `communication_campaigns/${encodeURIComponent(campaignId)}`
  );

  if (!campaign) {
    fail(
      404,
      "campaign-not-found",
      "الحملة غير موجودة."
    );
  }

  if (campaign.complete === true) {
    return communicationCampaignProgress(campaign);
  }

  const existingLease = Date.parse(
    String(campaign.processingLeaseUntil || "")
  );

  if (
    Number.isFinite(existingLease) &&
    existingLease > Date.now()
  ) {
    fail(
      409,
      "campaign-busy",
      "الحملة قيد المعالجة الآن."
    );
  }

  const leaseId = crypto.randomUUID();
  const leaseUntil = new Date(Date.now() + 60_000);

  const locked = await firestoreCommit(
    env,
    token,
    [
      updateWrite(
        env,
        `communication_campaigns/${encodeURIComponent(campaignId)}`,
        {
          processingLeaseId: leaseId,
          processingLeaseUntil: leaseUntil,
          status: "processing",
          updatedAt: new Date()
        },
        campaign.updateTime
      )
    ]
  );

  if (!locked) {
    fail(
      409,
      "campaign-busy",
      "تم بدء معالجة الحملة من جلسة أخرى."
    );
  }

  campaign = await firestoreGet(
    env,
    token,
    `communication_campaigns/${encodeURIComponent(campaignId)}`
  );

  if (!campaign || campaign.processingLeaseId !== leaseId) {
    fail(
      409,
      "campaign-lock-lost",
      "تعذر تثبيت قفل معالجة الحملة."
    );
  }

  const sourceCollection =
    campaign.audience === "agents" ? "agents" : "users";

  const page = await firestoreListPage(
    env,
    token,
    sourceCollection,
    String(campaign.cursor || ""),
    CAMPAIGN_PAGE_SIZE
  );

  const recipients = [];

  if (sourceCollection === "agents") {
    const profiles = await Promise.all(
      page.documents.map(async (agent) => {
        const uid = String(
          agent.userId ||
          agent.agentId ||
          agent.id ||
          ""
        ).trim();

        if (!uid) return null;

        return firestoreGet(
          env,
          token,
          `users/${encodeURIComponent(uid)}`
        );
      })
    );

    for (const profile of profiles) {
      if (profile?.id) {
        recipients.push(profile);
      }
    }
  } else {
    for (const profile of page.documents) {
      if (
        communicationAudienceMatches(
          profile,
          String(campaign.audience || "")
        )
      ) {
        recipients.push(profile);
      }
    }
  }

  let pageRecipientCount = 0;
  let pagePushTargetCount = 0;
  let pagePushSuccessCount = 0;
  let pagePushFailureCount = 0;
  let pagePushUnknownCount = 0;

  for (const profile of recipients) {
    const uid = String(profile.id || "").trim();
    if (!uid) continue;

    const deliveryPath =
      `communication_campaigns/${encodeURIComponent(campaignId)}` +
      `/deliveries/${encodeURIComponent(uid)}`;

    const existingDelivery = await firestoreGet(
      env,
      token,
      deliveryPath
    );

    if (existingDelivery) {
      const counters = campaignDeliveryCounters(
        existingDelivery
      );

      pageRecipientCount += counters.recipientCount;
      pagePushTargetCount += counters.pushTargetCount;
      pagePushSuccessCount += counters.pushSuccessCount;
      pagePushFailureCount += counters.pushFailureCount;
      pagePushUnknownCount += counters.pushUnknownCount;
      continue;
    }

    const deviceTokens = [
      ...new Set(
        (Array.isArray(profile.fcmTokens)
          ? profile.fcmTokens
          : []
        ).filter(
          (value) =>
            typeof value === "string" &&
            value.length > 20
        )
      )
    ];

    const campaignDeviceTokens =
      selectCampaignPushTokens(deviceTokens);


    const now = new Date();

    const initialDelivery = {
      campaignId,
      userId: uid,
      recipientCount: 1,
      pushTargetCount: campaignDeviceTokens.length,
      pushSuccessCount: 0,
      pushFailureCount: 0,
      pushUnknownCount: campaignDeviceTokens.length,
      pushState: campaignDeviceTokens.length
        ? "claimed"
        : "no_tokens",
      createdAt: now,
      updatedAt: now
    };

    const inboxMessage = {
      campaignId,
      title: String(campaign.title || ""),
      body: String(campaign.body || ""),
      type: String(campaign.type || "message"),
      imageUrl: campaign.imageUrl || null,
      videoUrl: campaign.videoUrl || null,
      mediaType: campaign.mediaType || null,
      createdAt: now
    };

    const claimed = await firestoreCommit(
      env,
      token,
      [
        updateWrite(
          env,
          `user_inbox/${encodeURIComponent(uid)}` +
          `/messages/${encodeURIComponent(campaignId)}`,
          inboxMessage
        ),
        createWrite(
          env,
          deliveryPath,
          initialDelivery
        )
      ]
    );

    if (!claimed) {
      const racedDelivery = await firestoreGet(
        env,
        token,
        deliveryPath
      );

      if (racedDelivery) {
        const counters = campaignDeliveryCounters(
          racedDelivery
        );

        pageRecipientCount += counters.recipientCount;
        pagePushTargetCount += counters.pushTargetCount;
        pagePushSuccessCount += counters.pushSuccessCount;
        pagePushFailureCount += counters.pushFailureCount;
        pagePushUnknownCount += counters.pushUnknownCount;
      }

      continue;
    }

    let finalDelivery = initialDelivery;

    if (campaignDeviceTokens.length) {
      const push = await sendCampaignPushToTokens(
        env,
        token,
        campaignDeviceTokens,
        {
          userId: uid,
        title: String(campaign.title || ""),
          body: String(campaign.body || ""),
          data: {
            type: String(campaign.type || "message"),
            campaignId
          }
        }
      );

      finalDelivery = {
        ...initialDelivery,
        pushTargetCount: push.targetCount,
        pushSuccessCount: push.successCount,
        pushFailureCount: push.failureCount,
        pushUnknownCount: push.unknownCount,
        pushState: "complete",
        updatedAt: new Date()
      };

      await firestoreCommit(
        env,
        token,
        [
          updateWrite(
            env,
            deliveryPath,
            finalDelivery
          )
        ]
      );
    }

    const counters = campaignDeliveryCounters(
      finalDelivery
    );

    pageRecipientCount += counters.recipientCount;
    pagePushTargetCount += counters.pushTargetCount;
    pagePushSuccessCount += counters.pushSuccessCount;
    pagePushFailureCount += counters.pushFailureCount;
    pagePushUnknownCount += counters.pushUnknownCount;
  }

  const complete = !page.nextPageToken;

  const updatedRecord = {
    cursor: page.nextPageToken || "",
    complete,
    status: complete ? "completed" : "pending",
    recipientCount:
      Number(campaign.recipientCount || 0) +
      pageRecipientCount,
    scannedCount:
      Number(campaign.scannedCount || 0) +
      page.documents.length,
    pushTargetCount:
      Number(campaign.pushTargetCount || 0) +
      pagePushTargetCount,
    pushSuccessCount:
      Number(campaign.pushSuccessCount || 0) +
      pagePushSuccessCount,
    pushFailureCount:
      Number(campaign.pushFailureCount || 0) +
      pagePushFailureCount,
    pushUnknownCount:
      Number(campaign.pushUnknownCount || 0) +
      pagePushUnknownCount,
    pageCount:
      Number(campaign.pageCount || 0) + 1,
    processingLeaseId: null,
    processingLeaseUntil: null,
    updatedAt: new Date(),
    ...(complete ? { completedAt: new Date() } : {})
  };

  const progressSaved = await firestoreCommit(
    env,
    token,
    [
      updateWrite(
        env,
        `communication_campaigns/${encodeURIComponent(campaignId)}`,
        updatedRecord,
        campaign.updateTime
      )
    ]
  );

  if (!progressSaved) {
    fail(
      409,
      "campaign-progress-conflict",
      "تغيّر تقدم الحملة أثناء المعالجة. حاول الاستكمال."
    );
  }

  const finalCampaign = {
    ...campaign,
    ...updatedRecord,
    id: campaignId
  };

  return communicationCampaignProgress(finalCampaign);
}
__name(processCommunicationCampaign, "processCommunicationCampaign");

async function listOrderSupervisorOrders(env, user) {
  const token = await serviceToken(env);
  const actor = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );
  const allowed = isPrimaryAdmin(user, actor) ||
    (actor?.role === "order_supervisor" && actor?.adminPermissions?.manageOrders === true);
  if (!allowed) {
    fail(403, "permission-denied", "غير مسموح بعرض طلبات الإشراف.");
  }
  const orders = await firestoreQuery(env, token, "orders");
  orders.sort((left, right) => Date.parse(right.createdAt || 0) - Date.parse(left.createdAt || 0));
  return {
    orders: orders.map((order) => ({
      id: order.id,
      orderNumber: order.orderNumber || null,
      status: order.status || "new",
      deliveryMethod: order.deliveryMethod || "delivery",
      customerName: order.customerName || order.customerEmail || "عميل بركة",
      customerPhone: order.customerPhone || "",
      deliveryAddress: order.deliveryAddress || "",
      businessTitle: order.businessTitle || "",
      createdAt: order.createdAt || null,
      items: (Array.isArray(order.items) ? order.items : []).map((item) => ({
        title: item?.title || "صنف",
        quantity: Number(item?.quantity || 1),
        specialNote: String(item?.specialNote || "").trim()
      }))
    }))
  };
}
__name(listOrderSupervisorOrders, "listOrderSupervisorOrders");
const GENERIC_PUSH_CONCURRENCY = 4;
const GENERIC_PUSH_PER_USER_LIMIT = 4;

const GENERIC_PUSH_IMMEDIATE_LIMIT = 8;
const NOTIFICATION_OUTBOX_TOKEN_CHUNK = 8;
const NOTIFICATION_OUTBOX_BATCH_SIZE = 4;
const NOTIFICATION_OUTBOX_MAX_ATTEMPTS = 7;

function isRetryableFcmStatus(status) {
  const value = Number(status);

  return (
    value === 401 ||
    value === 408 ||
    value === 425 ||
    value === 429 ||
    value >= 500
  );
}
__name(isRetryableFcmStatus, "isRetryableFcmStatus");

function selectRecentPushTokens(deviceTokens) {
  // Every registered device remains eligible; delivery is already batched by
  // sendPushBestEffort and its durable outbox. Prefer newly registered devices.
  return [...new Set((deviceTokens || []).filter(
    (value) => typeof value === "string" && value.length > 20
  ))].reverse();
}
__name(selectRecentPushTokens, "selectRecentPushTokens");

async function sendPushToTokens(
  env,
  token,
  deviceTokens,
  { title, body, data = {} }
) {
  const uniqueTokens = [
    ...new Set(
      (deviceTokens || []).filter(
        (value) =>
          typeof value === "string" &&
          value.length > 20
      )
    )
  ];

  if (!uniqueTokens.length) {
    return {
      targetCount: 0,
      attemptedCount: 0,
      deferredCount: 0,
      successCount: 0,
      failureCount: 0,
      unknownCount: 0,
      unregisteredCount: 0,
      retryTokens: [],
      invalidTokens: []
    };
  }

  const immediateTokens = uniqueTokens.slice(
    0,
    GENERIC_PUSH_IMMEDIATE_LIMIT
  );

  const deferredTokens = uniqueTokens.slice(
    GENERIC_PUSH_IMMEDIATE_LIMIT
  );

  const usesCoinSound = [
    "new_order",
    "order_status",
    "driver_order_available",
    "new_taxi_order",
    "taxi_order"
  ].includes(data.type);

  const isUrgentOrder =
    data.type === "new_order" ||
    data.type === "driver_order_available" ||
    data.type === "new_taxi_order";

  let successCount = 0;
  let failureCount = 0;
  let unknownCount = 0;
  let unregisteredCount = 0;

  const retryTokens = [...deferredTokens];
  const invalidTokens = [];

  for (
    let start = 0;
    start < immediateTokens.length;
    start += GENERIC_PUSH_CONCURRENCY
  ) {
    const batch = immediateTokens.slice(
      start,
      start + GENERIC_PUSH_CONCURRENCY
    );

    const results = await Promise.all(
      batch.map(async (deviceToken) => {
        try {
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
                      sound: usesCoinSound
                        ? "barakah_coin"
                        : "default",
                      channel_id: usesCoinSound
                        ? (
                            isUrgentOrder
                              ? "barakah_urgent_orders_coin_v1"
                              : "barakah_orders_coin_v1"
                          )
                        : "barakah_orders",
                      notification_priority: isUrgentOrder
                        ? "PRIORITY_MAX"
                        : "PRIORITY_HIGH",
                      default_vibrate_timings: true,
                      visibility: "PUBLIC",
                      sticky: isUrgentOrder
                    }
                  },
                  apns: {
                    headers: {
                      "apns-priority": "10"
                    },
                    payload: {
                      aps: {
                        sound: usesCoinSound
                          ? "barakah_coin.wav"
                          : "default",
                        badge: 1,
                        "interruption-level": isUrgentOrder
                          ? "time-sensitive"
                          : "active"
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

          const responseText =
            await response.text();

          if (response.ok) {
            return {
              success: 1,
              failure: 0,
              unknown: 0,
              unregistered: 0,
              retryToken: null,
              invalidToken: null
            };
          }

          const unregistered =
            isUnregisteredFcmError(
              responseText
            );

          const retryable =
            !unregistered &&
            isRetryableFcmStatus(
              response.status
            );

          console.error(
            "push_notification_failed",
            response.status,
            responseText.substring(0, 300)
          );

          return {
            success: 0,
            failure: 1,
            unknown: 0,
            unregistered:
              unregistered ? 1 : 0,
            retryToken:
              retryable
                ? deviceToken
                : null,
            invalidToken:
              unregistered
                ? deviceToken
                : null
          };
        } catch (error) {
          console.error(
            "push_notification_unknown",
            String(
              error?.message || error
            )
          );

          return {
            success: 0,
            failure: 0,
            unknown: 1,
            unregistered: 0,
            retryToken: deviceToken,
            invalidToken: null
          };
        }
      })
    );

    for (const result of results) {
      successCount += result.success;
      failureCount += result.failure;
      unknownCount += result.unknown;
      unregisteredCount +=
        result.unregistered;

      if (result.retryToken) {
        retryTokens.push(
          result.retryToken
        );
      }

      if (result.invalidToken) {
        invalidTokens.push(
          result.invalidToken
        );
      }
    }
  }

  return {
    targetCount: uniqueTokens.length,
    attemptedCount:
      immediateTokens.length,
    deferredCount:
      deferredTokens.length,
    successCount,
    failureCount,
    unknownCount,
    unregisteredCount,
    retryTokens: [
      ...new Set(retryTokens)
    ],
    invalidTokens: [
      ...new Set(invalidTokens)
    ]
  };
}
__name(sendPushToTokens, "sendPushToTokens");

async function cleanupInvalidPushTokensBestEffort(env, token, invalidTokens) {
  const tokens = [...new Set(
    (Array.isArray(invalidTokens) ? invalidTokens : []).filter(
      (value) => typeof value === "string" && value.length > 20
    )
  )];

  for (const invalidToken of tokens) {
    try {
      const owners = await firestoreQuery(
        env,
        token,
        "users",
        [fieldArrayContains("fcmTokens", invalidToken)],
        // Keep Firestore metadata separate from profile fields such as id/name.
        (document) => document
      );
      const userPrefix = `${documentName(env, "users")}/`;

      for (const owner of owners) {
        try {
          const name = owner.name;
          const fcmTokens = decodeValue(owner.fields?.fcmTokens || { nullValue: null });
          if (typeof name !== "string" || !name.startsWith(userPrefix) ||
              !name.slice(userPrefix.length) || name.slice(userPrefix.length).includes("/") ||
              typeof owner.updateTime !== "string" || !owner.updateTime ||
              !Array.isArray(fcmTokens) || !fcmTokens.includes(invalidToken)) {
            continue;
          }

          const cleanupCommit = await firestoreCommit(env, token, [{
            transform: {
              document: name,
              fieldTransforms: [arrayRemoveTransform("fcmTokens", [invalidToken])]
            },
            // arrayRemove is concurrency-safe for this exact invalid token.
            // Require the account to still exist without conflicting with
            // unrelated profile updates.
            currentDocument: { exists: true }
          }]);

          if (!cleanupCommit) {
            console.error(
              "push_invalid_token_cleanup_write_conflict"
            );
          }
        } catch (error) {
          console.error(
            "push_invalid_token_cleanup_write_failed",
            String(error?.message || error)
          );
        }
      }
    } catch (error) {
      console.error(
        "push_invalid_token_cleanup_query_failed",
        String(error?.message || error)
      );
    }
  }
}
__name(cleanupInvalidPushTokensBestEffort, "cleanupInvalidPushTokensBestEffort");

async function notificationOutboxDedupeKey(
  payload,
  logKey,
  deviceTokens
) {
  const data =
    payload?.data &&
    typeof payload.data === "object" &&
    !Array.isArray(payload.data)
      ? payload.data
      : {};

  const sortedData = Object.fromEntries(
    Object.keys(data)
      .sort()
      .map((key) => [key, data[key]])
  );

  const recipients = [
    ...new Set(
      (deviceTokens || []).filter(
        (value) =>
          typeof value === "string" &&
          value.length > 20
      )
    )
  ].sort();

  const raw = JSON.stringify({
    logKey: String(logKey || ""),
    title: String(payload?.title || ""),
    body: String(payload?.body || ""),
    data: sortedData,
    recipients
  });

  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(raw)
  );

  return [...new Uint8Array(digest)]
    .map(
      (value) =>
        value.toString(16).padStart(2, "0")
    )
    .join("");
}
__name(
  notificationOutboxDedupeKey,
  "notificationOutboxDedupeKey"
);


async function enqueueNotificationOutbox(
  env,
  deviceTokens,
  payload,
  logKey
) {
  const tokens = [
    ...new Set(
      (deviceTokens || []).filter(
        (value) =>
          typeof value === "string" &&
          value.length > 20
      )
    )
  ].sort();

  if (!tokens.length) {
    return [];
  }

  const candidates = [];
  const statements = [];

  for (
    let start = 0;
    start < tokens.length;
    start += NOTIFICATION_OUTBOX_TOKEN_CHUNK
  ) {
    const chunk = tokens.slice(
      start,
      start + NOTIFICATION_OUTBOX_TOKEN_CHUNK
    );

    const dedupeKey =
      await notificationOutboxDedupeKey(
        payload,
        logKey,
        chunk
      );

    const id =
      crypto.randomUUID().replace(/-/g, "");

    candidates.push({
      id,
      tokens: chunk,
      attempts: 0
    });

    statements.push(
      env.DB.prepare(
        `INSERT OR IGNORE INTO notification_outbox (
          id,
          dedupe_key,
          tokens_json,
          payload_json,
          status,
          attempts,
          next_attempt_at,
          created_at,
          updated_at
        ) VALUES (
          ?, ?, ?, ?,
          'pending',
          0,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )`
      ).bind(
        id,
        dedupeKey,
        JSON.stringify(chunk),
        JSON.stringify(payload)
      )
    );
  }

  const results =
    await env.DB.batch(statements);

  return candidates.filter(
    (_, index) =>
      Number(
        results?.[index]?.meta?.changes || 0
      ) === 1
  );
}
__name(
  enqueueNotificationOutbox,
  "enqueueNotificationOutbox"
);



function notificationRetryDelaySeconds(attempt) {
  const delays = [
    60,
    180,
    600,
    1800,
    3600,
    21600
  ];

  const index = Math.max(
    0,
    Math.min(
      delays.length - 1,
      Number(attempt || 1) - 1
    )
  );

  return delays[index];
}
__name(
  notificationRetryDelaySeconds,
  "notificationRetryDelaySeconds"
);


async function finalizeNotificationOutboxAttempt(
  env,
  id,
  result,
  previousAttempts = 0
) {
  const attempts =
    Number(previousAttempts || 0) + 1;

  const retryTokens = [
    ...new Set(
      Array.isArray(result?.retryTokens)
        ? result.retryTokens
        : []
    )
  ];

  const resultJson = JSON.stringify({
    targetCount:
      Number(result?.targetCount || 0),
    attemptedCount:
      Number(result?.attemptedCount || 0),
    deferredCount:
      Number(result?.deferredCount || 0),
    successCount:
      Number(result?.successCount || 0),
    failureCount:
      Number(result?.failureCount || 0),
    unknownCount:
      Number(result?.unknownCount || 0),
    unregisteredCount:
      Number(result?.unregisteredCount || 0)
  });

  if (
    retryTokens.length > 0 &&
    attempts < NOTIFICATION_OUTBOX_MAX_ATTEMPTS
  ) {
    const delay =
      notificationRetryDelaySeconds(
        attempts
      );

    await env.DB.prepare(
      `UPDATE notification_outbox
       SET
         tokens_json=?,
         status='retry',
         attempts=?,
         next_attempt_at=
           datetime(
             'now',
             '+' || ? || ' seconds'
           ),
         locked_at=NULL,
         last_error=?,
         last_result_json=?,
         updated_at=CURRENT_TIMESTAMP
       WHERE id=?`
    ).bind(
      JSON.stringify(retryTokens),
      attempts,
      delay,
      `retryable:${retryTokens.length}`,
      resultJson,
      id
    ).run();

    return "retry";
  }

  const successCount =
    Number(result?.successCount || 0);

  const status =
    successCount > 0
      ? "sent"
      : "dead";

  const lastError =
    status === "dead"
      ? (
          retryTokens.length > 0
            ? "max-attempts"
            : "no-delivery"
        )
      : null;

  await env.DB.prepare(
    `UPDATE notification_outbox
     SET
       status=?,
       attempts=?,
       locked_at=NULL,
       last_error=?,
       last_result_json=?,
       updated_at=CURRENT_TIMESTAMP,
       sent_at=
         CASE
           WHEN ?='sent'
           THEN CURRENT_TIMESTAMP
           ELSE sent_at
         END
     WHERE id=?`
  ).bind(
    status,
    attempts,
    lastError,
    resultJson,
    status,
    id
  ).run();

  return status;
}
__name(
  finalizeNotificationOutboxAttempt,
  "finalizeNotificationOutboxAttempt"
);


async function processNotificationOutbox(env) {
  if (!env?.DB) {
    return {
      processed: 0,
      skipped: true
    };
  }

  // Recover rows left locked by an interrupted Worker.
  await env.DB.prepare(
    `UPDATE notification_outbox
     SET
       status='retry',
       locked_at=NULL,
       next_attempt_at=CURRENT_TIMESTAMP,
       updated_at=CURRENT_TIMESTAMP
     WHERE
       status='processing'
       AND locked_at <
         datetime('now', '-5 minutes')`
  ).run();

  const due = await env.DB.prepare(
    `SELECT
       id,
       tokens_json,
       payload_json,
       attempts
     FROM notification_outbox
     WHERE
       status IN ('pending', 'retry')
       AND next_attempt_at <= CURRENT_TIMESTAMP
     ORDER BY created_at ASC
     LIMIT ?`
  ).bind(
    NOTIFICATION_OUTBOX_BATCH_SIZE
  ).all();

  const rows =
    Array.isArray(due?.results)
      ? due.results
      : [];

  if (!rows.length) {
    return {
      processed: 0
    };
  }

  // Fresh Firebase access token for every retry run.
  const accessToken =
    await serviceToken(env);

  let processed = 0;

  for (const row of rows) {
    // Claim the row so overlapping retry runs
    // cannot process the same notification together.
    const claim = await env.DB.prepare(
      `UPDATE notification_outbox
       SET
         status='processing',
         locked_at=CURRENT_TIMESTAMP,
         updated_at=CURRENT_TIMESTAMP
       WHERE
         id=?
         AND status IN ('pending', 'retry')
         AND next_attempt_at <= CURRENT_TIMESTAMP`
    ).bind(
      row.id
    ).run();

    if (
      Number(
        claim?.meta?.changes || 0
      ) !== 1
    ) {
      continue;
    }

    let tokens;
    let payload;

    try {
      tokens =
        JSON.parse(
          row.tokens_json || "[]"
        );

      payload =
        JSON.parse(
          row.payload_json || "{}"
        );
    } catch (error) {
      await env.DB.prepare(
        `UPDATE notification_outbox
         SET
           status='dead',
           locked_at=NULL,
           last_error='invalid-outbox-json',
           updated_at=CURRENT_TIMESTAMP
         WHERE id=?`
      ).bind(
        row.id
      ).run();

      continue;
    }

    try {
      const result =
        await sendPushToTokens(
          env,
          accessToken,
          tokens,
          payload
        );

      await cleanupInvalidPushTokensBestEffort(env, accessToken, result.invalidTokens);

      await finalizeNotificationOutboxAttempt(
        env,
        row.id,
        result,
        row.attempts
      );
    } catch (error) {
      // Network/Worker exception:
      // keep all tokens retryable.
      await finalizeNotificationOutboxAttempt(
        env,
        row.id,
        {
          targetCount:
            Array.isArray(tokens)
              ? tokens.length
              : 0,
          attemptedCount: 0,
          deferredCount: 0,
          successCount: 0,
          failureCount: 0,
          unknownCount: 1,
          unregisteredCount: 0,
          retryTokens:
            Array.isArray(tokens)
              ? tokens
              : [],
          invalidTokens: []
        },
        row.attempts
      );

      console.error(
        "notification_outbox_attempt_failed",
        String(
          error?.message || error
        )
      );
    }

    processed += 1;
  }

  // Keep history temporarily for diagnosis,
  // but prevent D1 from growing forever.
  await env.DB.prepare(
    `DELETE FROM notification_outbox
     WHERE
       status IN ('sent', 'dead')
       AND created_at <
         datetime('now', '-14 days')`
  ).run();

  return {
    processed
  };
}
__name(
  processNotificationOutbox,
  "processNotificationOutbox"
);


async function sendPushBestEffort(
  env,
  token,
  deviceTokens,
  payload,
  logKey = "push_best_effort_failed"
) {
  const normalizedTokens = [
    ...new Set(
      (deviceTokens || []).filter(
        (value) =>
          typeof value === "string" &&
          value.length > 20
      )
    )
  ];

  if (!normalizedTokens.length) {
    return {
      targetCount: 0,
      attemptedCount: 0,
      deferredCount: 0,
      successCount: 0,
      failureCount: 0,
      unknownCount: 0,
      unregisteredCount: 0,
      retryTokens: [],
      invalidTokens: [],
      queuedCount: 0
    };
  }

  let entries;

  try {
    entries =
      await enqueueNotificationOutbox(
        env,
        normalizedTokens,
        payload,
        logKey
      );
  } catch (error) {
    console.error(
      "notification_outbox_persist_failed",
      logKey,
      String(error?.message || error)
    );

    try {
      const result = await sendPushToTokens(
        env,
        token,
        normalizedTokens,
        payload
      );
      await cleanupInvalidPushTokensBestEffort(env, token, result.invalidTokens);
      return result;
    } catch (fallbackError) {
      console.error(
        logKey,
        String(
          fallbackError?.message ||
          fallbackError
        )
      );

      return {
        targetCount:
          normalizedTokens.length,
        attemptedCount: 0,
        deferredCount:
          normalizedTokens.length,
        successCount: 0,
        failureCount: 0,
        unknownCount:
          normalizedTokens.length,
        unregisteredCount: 0,
        retryTokens:
          normalizedTokens,
        invalidTokens: [],
        queuedCount: 0
      };
    }
  }

  if (!entries.length) {
    return {
      targetCount:
        normalizedTokens.length,
      attemptedCount: 0,
      deferredCount: 0,
      successCount: 0,
      failureCount: 0,
      unknownCount: 0,
      unregisteredCount: 0,
      retryTokens: [],
      invalidTokens: [],
      queuedCount: 0,
      deduped: true
    };
  }

  const immediate = entries[0];

  let result;

  try {
    result =
      await sendPushToTokens(
        env,
        token,
        immediate.tokens,
        payload
      );
    await cleanupInvalidPushTokensBestEffort(env, token, result.invalidTokens);
  } catch (error) {
    console.error(
      logKey,
      String(error?.message || error)
    );

    result = {
      targetCount:
        immediate.tokens.length,
      attemptedCount: 0,
      deferredCount: 0,
      successCount: 0,
      failureCount: 0,
      unknownCount:
        immediate.tokens.length,
      unregisteredCount: 0,
      retryTokens:
        immediate.tokens,
      invalidTokens: []
    };
  }

  try {
    await finalizeNotificationOutboxAttempt(
      env,
      immediate.id,
      result,
      immediate.attempts
    );
  } catch (error) {
    console.error(
      "notification_outbox_finalize_failed",
      String(error?.message || error)
    );

    // Do not send again here.
    // The durable row remains for recovery.
  }

  return {
    ...result,
    outboxId: immediate.id,
    queuedCount:
      Math.max(
        0,
        entries.length - 1
      ) +
      (
        Array.isArray(
          result.retryTokens
        ) &&
        result.retryTokens.length > 0
          ? 1
          : 0
      )
  };
}
__name(sendPushBestEffort, "sendPushBestEffort");

async function userPushTokens(env, token, uid) {
  if (!uid) return [];
  const profile = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(uid)}`
  );
  return selectRecentPushTokens(profile?.fcmTokens);
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
    rejected: "\u062A\u0645 \u0631\u0641\u0636 \u0627\u0644\u0637\u0644\u0628",
    cancelled: "\u062A\u0645 \u0625\u0644\u063A\u0627\u0621 \u0637\u0644\u0628\u0643",
    canceled: "\u062A\u0645 \u0625\u0644\u063A\u0627\u0621 \u0637\u0644\u0628\u0643"
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
  await sendPushBestEffort(
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
  const [ownerTokens, supervisors] = await Promise.all([
    adminPushTokens(env, token),
    firestoreQuery(env, token, "users", [fieldEquals("role", "order_supervisor")])
  ]);
  const adminTokens = [
    ...ownerTokens,
    ...supervisors
      .filter((supervisor) => supervisor.adminPermissions?.manageOrders === true)
      .flatMap((supervisor) => selectRecentPushTokens(supervisor.fcmTokens))
  ];
  let merchantTokens = [];
  if (order.businessId) {
    const [business, directlyLinkedMerchants, managedBusinessMerchants] = await Promise.all([
      firestoreGet(
        env,
        token,
        `items/${encodeURIComponent(order.businessId)}`
      ),
      firestoreQuery(env, token, "users", [
        fieldEquals("merchantBusinessId", order.businessId)
      ]),
      firestoreQuery(env, token, "users", [
        fieldArrayContains("managedBusinessIds", order.businessId)
      ])
    ]);
    const merchantUserIds = [
      business?.ownerId,
      ...(Array.isArray(business?.managerIds) ? business.managerIds : [])
    ].filter(Boolean);
    merchantTokens = (await Promise.all(
      [...new Set(merchantUserIds)].map((uid) => userPushTokens(env, token, uid))
    )).flat();
    merchantTokens.push(
      ...directlyLinkedMerchants.flatMap((profile) =>
        selectRecentPushTokens(profile.fcmTokens)
      ),
      ...managedBusinessMerchants.flatMap((profile) =>
        selectRecentPushTokens(profile.fcmTokens)
      )
    );
  }
  const orderLabel = String(
    order.orderNumber || orderId.substring(0, 6).toUpperCase()
  );
  await sendPushBestEffort(
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

async function notifyOrderAdminAlarmStop(
  env,
  token,
  orderId,
  order,
  status
) {
  const [ownerTokens, supervisors] = await Promise.all([
    adminPushTokens(env, token),
    firestoreQuery(env, token, "users", [
      fieldEquals("role", "order_supervisor")
    ])
  ]);

  const adminTokens = [
    ...ownerTokens,
    ...supervisors
      .filter(
        (supervisor) =>
          supervisor.adminPermissions?.manageOrders === true
      )
      .flatMap(
        (supervisor) =>
          selectRecentPushTokens(supervisor.fcmTokens)
      )
  ];

  let merchantTokens = [];

  if (order.businessId) {
    const [
      business,
      directlyLinkedMerchants,
      managedBusinessMerchants
    ] = await Promise.all([
      firestoreGet(
        env,
        token,
        `items/${encodeURIComponent(order.businessId)}`
      ),
      firestoreQuery(env, token, "users", [
        fieldEquals("merchantBusinessId", order.businessId)
      ]),
      firestoreQuery(env, token, "users", [
        fieldArrayContains("managedBusinessIds", order.businessId)
      ])
    ]);

    const merchantUserIds = [
      business?.ownerId,
      ...(Array.isArray(business?.managerIds)
        ? business.managerIds
        : [])
    ].filter(Boolean);

    merchantTokens = (
      await Promise.all(
        [...new Set(merchantUserIds)].map(
          (uid) => userPushTokens(env, token, uid)
        )
      )
    ).flat();

    merchantTokens.push(
      ...directlyLinkedMerchants.flatMap(
        (profile) => selectRecentPushTokens(profile.fcmTokens)
      ),
      ...managedBusinessMerchants.flatMap(
        (profile) => selectRecentPushTokens(profile.fcmTokens)
      )
    );
  }

  const orderLabel = String(
    order.orderNumber ||
      orderId.substring(0, 6).toUpperCase()
  );

  await sendPushBestEffort(
    env,
    token,
    [
      ...adminTokens,
      ...merchantTokens
    ],
    {
      title:
        status === "accepted"
          ? "تم قبول الطلب ✅"
          : "تم إغلاق الطلب",
      body: `الطلب #${orderLabel} لم يعد بانتظار القبول.`,
      data: {
        type: "admin_order_alarm_stop",
        adminAlarm: "stop",
        orderId,
        orderNumber: orderLabel,
        status: String(status || "")
      }
    },
    "order_admin_alarm_stop_failed"
  );
}

__name(
  notifyOrderAdminAlarmStop,
  "notifyOrderAdminAlarmStop"
);

async function createPartnerApplication(request, env) {
  const data = await readJson(request);
  const required = [
    "businessName",
    "ownerName",
    "email",
    "phone",
    "activityType",
    "businessCategory",
    "area",
    "locationUrl",
    "identityDocumentRef"
  ];
  for (const field of required) {
    if (!String(data?.[field] || "").trim()) {
      fail(400, "missing-field", "بيانات طلب الشريك غير مكتملة.");
    }
  }
  const latitude = Number(data.latitude);
  const longitude = Number(data.longitude);
  if (data.latitude === null || data.longitude === null ||
      data.latitude === "" || data.longitude === "" ||
      !["number", "string"].includes(typeof data.latitude) ||
      !["number", "string"].includes(typeof data.longitude) ||
      !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
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
    requestedBusinessStatus: data.requestedBusinessStatus === "coming_soon" ? "coming_soon" : "open",
    barberServices: Array.isArray(data.barberServices)
      ? data.barberServices.slice(0, 30).map((service) => ({
        title: text(service?.title, 120),
        price: Math.max(0, Math.min(Number(service?.price) || 0, 1e6)),
        durationMinutes: Math.max(10, Math.min(Number(service?.durationMinutes) || 30, 240))
      })).filter((service) => service.title.length >= 2)
      : [],
    barberOpeningTime: text(data.barberOpeningTime, 10),
    barberClosingTime: text(data.barberClosingTime, 10),
    barberSlotMinutes: Math.max(10, Math.min(Number(data.barberSlotMinutes) || 30, 240)),
    doctorSpecialty: text(data.doctorSpecialty, 120),
    doctorLicense: text(data.doctorLicense, 120),
    doctorConsultationFee: Math.max(0, Math.min(Number(data.doctorConsultationFee) || 0, 1e6)),
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
    commissionAppliesTo: "products_and_bookings",
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

  // The application is already committed at this point. A push notification is
  // best-effort and must never make the applicant see a failed submission (or
  // submit duplicates) when FCM is temporarily unavailable.
  try {
    const adminTokens = await adminPushTokens(env, token);
    await sendPushBestEffort(env, token, adminTokens, {
      title: "طلب انضمام شريك جديد 🤝",
      body: `${record.businessName} بانتظار المراجعة.`,
      data: {
        type: "partner_application",
        applicationId
      }
    });
  } catch (error) {
    console.error("partner_application_notification_failed", String(error?.message || error));
  }
  return { applicationId, status: "pending" };
}
__name(createPartnerApplication, "createPartnerApplication");
async function adminPushTokens(env, token) {
  const owner = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(PRIMARY_ADMIN_UID)}`
  );
  return selectRecentPushTokens(owner?.fcmTokens);
}
__name(adminPushTokens, "adminPushTokens");


async function taxiBusinessPushTokens(env, token, order) {
  if (!order?.businessId) return [];
  const businessIds = [...new Set([order.businessId, order.originalBusinessId].filter(Boolean))];
  const businesses = await Promise.all(businessIds.map(id => firestoreGet(env, token, `items/${encodeURIComponent(id)}`)));
  const userIds = [PRIMARY_ADMIN_UID];
  for (const business of businesses.filter(Boolean)) {
    if (business.ownerId) userIds.push(business.ownerId);
    if (Array.isArray(business.managerIds)) userIds.push(...business.managerIds);
  }
  const groups = await Promise.all([...new Set(userIds)].map(uid => userPushTokens(env, token, uid)));
  return groups.flat();
}
__name(taxiBusinessPushTokens, "taxiBusinessPushTokens");


async function notifyTaxiLifecycle(
  env,
  token,
  order,
  action,
  actorUid
) {
  if (!order || action === "update_location") {
    return;
  }

  const orderId = String(order.orderId || order.id || "");
  const orderNumber = String(
    order.orderNumber ||
    (orderId ? orderId.slice(-8).toUpperCase() : "تكسي")
  );

  const commonData = {
    type: action === "created" ? "new_taxi_order" : "taxi_order",
    action: String(action),
    orderId,
    orderNumber,
    status: String(order.status || "")
  };

  const customerTokens = order.customerId
    ? await userPushTokens(env, token, order.customerId)
    : [];

  const driverTokens = order.driverUid
    ? await userPushTokens(env, token, order.driverUid)
    : [];

  if (
    action === "dispatch" ||
    action === "cancel"
  ) {
    try {
      const officeTokens =
        await taxiBusinessPushTokens(env, token, order);

      await sendPushBestEffort(
        env,
        token,
        officeTokens,
        {
          title:
            action === "dispatch"
              ? "تم إرسال سيارة للطلب ✅"
              : "تم إلغاء طلب التكسي",
          body: `طلب التكسي ${orderNumber} لم يعد بانتظار الإرسال.`,
          data: {
            ...commonData,
            type: "admin_taxi_alarm_stop",
            adminAlarm: "stop"
          }
        },
        "taxi_admin_alarm_stop_failed"
      );
    } catch (error) {
      console.error(
        "taxi_admin_alarm_stop_failed",
        String(error?.message || error)
      );
    }
  }

  if (action === "created") {
    const officeTokens = await taxiBusinessPushTokens(env, token, order);
    const store = createFirestoreStore({ baseUrl: firestoreBase(env), token });
    const drivers = await store.query('users', { taxiDriverEnabled: true });
    const driverTokenGroups = await Promise.all(drivers
      .filter(row => row.id !== order.customerId && row.data.taxiBusinessId)
      .map(async row => {
        const office = await store.get(`items/${encodeURIComponent(row.data.taxiBusinessId)}`);
        if (!office || office.data.isActive === false || office.data.status === 'closed' || office.data.businessStatus === 'closed') return [];
        return userPushTokens(env, token, row.id);
      }));

    await sendPushBestEffort(
      env,
      token,
      officeTokens,
      {
        title: "طلب تكسي جديد 🚕",
        body: `الطلب ${orderNumber} متاح؛ افتح لوحة سائق التكسي لقبوله.`,
        data: commonData
      },
      "taxi_created_notification_failed"
    );
    await sendPushBestEffort(env, token, [...new Set(driverTokenGroups.flat())], {
      title: "طلب تكسي متاح 🚕", body: `الطلب ${orderNumber} متاح للقبول في لوحة السائق.`,
      data: { ...commonData, type: "taxi_driver_order_available" }
    }, "taxi_available_driver_notification_failed");

    return;
  }

  if (action === "dispatch") {
    await sendPushBestEffort(
      env,
      token,
      customerTokens,
      {
        title: "تم إرسال سيارة تكسي بركة 🚕",
        body: order.dispatchedEtaMinutes
          ? `السيارة في طريقها إليك. الوصول المتوقع خلال ${order.dispatchedEtaMinutes} دقائق.`
          : "السيارة في طريقها إليك.",
        data: commonData
      },
      "taxi_customer_dispatch_notification_failed"
    );

    await sendPushBestEffort(
      env,
      token,
      driverTokens,
      {
        title: "تم تعيين رحلة تكسي جديدة 🚕",
        body: `الرحلة ${orderNumber} جاهزة في لوحة السائق.`,
        data: commonData
      },
      "taxi_driver_dispatch_notification_failed"
    );

    return;
  }

  if (action === "start_trip") {
    await sendPushBestEffort(
      env,
      token,
      customerTokens,
      {
        title: "بدأت رحلة تكسي بركة 🚕",
        body: "بدأ السائق الرحلة ويمكنك متابعة موقعه من داخل بركة.",
        data: commonData
      },
      "taxi_start_notification_failed"
    );

    return;
  }

  if (action === "complete") {
    await sendPushBestEffort(
      env,
      token,
      customerTokens,
      {
        title: "الرحلة بانتظار تأكيدك ✅",
        body: `وصلت رحلة ${orderNumber}. افتح بركة لتأكيد الوصول.`,
        data: commonData
      },
      "taxi_complete_notification_failed"
    );

    return;
  }

  if (action === "confirm") {
    const officeTokens =
      await taxiBusinessPushTokens(env, token, order);

    await sendPushBestEffort(
      env,
      token,
      [
        ...officeTokens,
        ...driverTokens
      ],
      {
        title: "تم تأكيد رحلة تكسي بركة ✅",
        body: `أكد العميل اكتمال الرحلة ${orderNumber}.`,
        data: commonData
      },
      "taxi_confirm_notification_failed"
    );

    return;
  }

  if (action === "cancel") {
    const cancelledByCustomer =
      order.customerId &&
      actorUid === order.customerId;

    if (cancelledByCustomer) {
      const officeTokens =
        await taxiBusinessPushTokens(env, token, order);

      await sendPushBestEffort(
        env,
        token,
        [
          ...officeTokens,
          ...driverTokens
        ],
        {
          title: "تم إلغاء طلب التكسي",
          body: `ألغى العميل الطلب ${orderNumber}.`,
          data: commonData
        },
        "taxi_customer_cancel_notification_failed"
      );
    } else {
      await sendPushBestEffort(
        env,
        token,
        [
          ...customerTokens,
          ...driverTokens
        ],
        {
          title: "تم إلغاء رحلة تكسي بركة",
          body: `تم إلغاء الطلب ${orderNumber}.`,
          data: commonData
        },
        "taxi_office_cancel_notification_failed"
      );
    }
  }
}
__name(notifyTaxiLifecycle, "notifyTaxiLifecycle");

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
      label: (record) => record.itemName || "إعلان مزاد جديد",
      ownerField: "userId",
      expectedStatus: "pending"
    },
    auction_sale: {
      collection: "auction_sales",
      title: "حجز جديد في المزاد 🛍️",
      label: (record) => record.itemName || "سلعة مزاد",
      ownerField: "buyerId",
      expectedStatus: "pending_commission"
    },
    driver_application: {
      collection: "driver_applications",
      title: "طلب انضمام سائق جديد 🚗",
      label: (record) => record.fullName || "متقدم جديد"
    },
    taxi_driver_application: {
      collection: "taxi_driver_applications",
      title: "طلب انضمام سائق تكسي بركة جديد 🚕",
      label: (record) => record.fullName || "متقدم جديد",
      ownerField: "userId",
      expectedStatus: "pending"
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
  if (
    !record ||
    record[definition.ownerField || "userId"] !== user.uid ||
    record.status !== (definition.expectedStatus || "pending")
  ) {
    fail(403, "request-not-owned", "تعذر التحقق من الطلب الجديد.");
  }
  const tokens = await adminPushTokens(env, token);
  await sendPushBestEffort(env, token, tokens, {
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
async function notifyAuctionStatus(request, env, user) {
  const body = await readJson(request);
  const saleId = String(body?.saleId || "").trim();
  const status = String(body?.status || "").trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(saleId)) {
    fail(400, "invalid-sale-id", "معرّف عملية المزاد غير صالح.");
  }
  if (!["commission_paid", "completed", "cancelled"].includes(status)) {
    fail(400, "invalid-sale-status", "حالة عملية المزاد غير مدعومة.");
  }
  const token = await serviceToken(env);
  const actor = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );
  if (!isPrimaryAdmin(user, actor)) {
    fail(403, "permission-denied", "هذه العملية متاحة للأدمن فقط.");
  }
  const sale = await firestoreGet(
    env,
    token,
    `auction_sales/${encodeURIComponent(saleId)}`
  );
  if (!sale || sale.status !== status) {
    fail(409, "sale-status-mismatch", "لم يتم تأكيد حالة البيع الجديدة.");
  }
  const labels = {
    commission_paid: {
      title: "تم تأكيد عمولة المزاد ✅",
      body: "يمكن الآن متابعة تسليم السلعة مع إدارة بركة."
    },
    completed: {
      title: "اكتملت عملية المزاد 🎉",
      body: "تم تسجيل بيع السلعة بنجاح."
    },
    cancelled: {
      title: "أُلغي حجز المزاد",
      body: "أعيدت السلعة للعرض ويمكن حجزها من جديد."
    }
  };
  const targetIds = [...new Set([sale.buyerId, sale.sellerId].filter(Boolean))];
  const tokenGroups = await Promise.all(
    targetIds.map((uid) => userPushTokens(env, token, uid))
  );
  const message = labels[status];
  await sendPushBestEffort(env, token, tokenGroups.flat(), {
    title: message.title,
    body: message.body,
    data: { type: "auction_status", saleId, status }
  });
  return { ok: true, saleId, status };
}
__name(notifyAuctionStatus, "notifyAuctionStatus");
async function sendSupportMessage(request, env, user) {
  const body = await readJson(request);
  const threadId =
    String(body?.threadId || "").trim();

  const message =
    String(body?.text || "").trim();

  const imageUrl = String(body?.imageUrl || "").trim();
  const videoUrl = String(body?.videoUrl || "").trim();
  const mediaType = String(body?.mediaType || "").trim();
  const attachmentUrl = imageUrl || videoUrl;
  const expectedType = imageUrl ? "image" : videoUrl ? "video" : "";
  let validMedia = !attachmentUrl;
  if (attachmentUrl) {
    try {
      const parsed = new URL(attachmentUrl);
      validMedia = attachmentUrl.length <= 2048 && parsed.protocol === "https:" &&
        parsed.hostname === "ik.imagekit.io" && !parsed.username && !parsed.password &&
        !parsed.port && !parsed.search && !parsed.hash && parsed.pathname.length > 1;
    } catch (_) { validMedia = false; }
  }
  if ((imageUrl && videoUrl) || !validMedia || (mediaType && mediaType !== expectedType)) {
    fail(400, "invalid-media", "رابط المرفق أو نوعه غير صالح. أعد رفع الملف من بركة.");
  }
  const media = attachmentUrl
    ? { ...(imageUrl ? { imageUrl } : { videoUrl }), mediaType: expectedType }
    : {};
  const preview = message || (imageUrl ? "📷 صورة" : videoUrl ? "🎥 فيديو" : "");
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(threadId)) {
    fail(
      400,
      "invalid-thread",
      "محادثة خدمة العملاء غير صالحة."
    );
  }

  if ((!message && !attachmentUrl) || message.length > 4e3) {
    fail(
      400,
      "invalid-message",
      "الرسالة فارغة أو طويلة جدًا."
    );
  }

  const token = await serviceToken(env);

  const [thread, actor] =
    await Promise.all([
      firestoreGet(
        env,
        token,
        `support_threads/${encodeURIComponent(threadId)}`
      ),
      firestoreGet(
        env,
        token,
        `users/${encodeURIComponent(user.uid)}`
      )
    ]);

  if (!thread || !actor) {
    fail(
      404,
      "support-thread-not-found",
      "محادثة خدمة العملاء غير موجودة."
    );
  }

  let senderRole;
  let senderName;
  let notificationTitle;

  if (thread.customerId === user.uid) {
    senderRole = "customer";
    senderName = String(
      actor.displayName ||
      thread.customerName ||
      "عميل بركة"
    );

    notificationTitle =
      "رسالة جديدة لخدمة العملاء 💬";

  } else if (
    actor.role === "customer_service" &&
    actor.customerServiceEnabled === true &&
    thread.assignedAgentId === user.uid
  ) {
    // This is authorization/business validation,
    // so it remains before the message commit.
    const contract =
      await firestoreGet(
        env,
        token,
        `employment_contracts/${encodeURIComponent(user.uid)}`
      );

    if (contract?.status !== "accepted") {
      fail(
        403,
        "support-contract-required",
        "يجب قبول عقد العمل قبل إرسال رسائل خدمة العملاء."
      );
    }

    senderRole = "customer_service";
    senderName = String(
      actor.displayName ||
      "خدمة عملاء بركة"
    );

    notificationTitle =
      "رد جديد من خدمة عملاء بركة 💬";

  } else if (
    isPrimaryAdmin(user, actor)
  ) {
    senderRole = "admin";
    senderName = String(
      actor.displayName ||
      "إدارة بركة"
    );

    notificationTitle =
      "رد جديد من إدارة بركة 💬";

  } else {
    fail(
      403,
      "support-permission-denied",
      "غير مسموح بإرسال رسالة في هذه المحادثة."
    );
  }

  const messageId =
    crypto.randomUUID().replace(/-/g, "");

  const shouldSendWelcome =
    senderRole === "customer" &&
    thread.autoWelcomeSent !== true;

  const welcomeMessageId =
    shouldSendWelcome
      ? crypto.randomUUID().replace(/-/g, "")
      : null;

  const welcomeMessage =
    "أهلًا وسهلًا بك في خدمة عملاء بركة 🌟\n" +
    "تم استلام رسالتك بنجاح، وسيقوم أحد أعضاء فريقنا " +
    "بالرد عليك بأقرب وقت. شكرًا لاختيارك بركة.";

  const writes = [
    createWrite(
      env,
      `support_threads/${encodeURIComponent(threadId)}/messages/${messageId}`,
      {
        senderId: user.uid,
        senderRole,
        senderName,
        text: message,
        ...media,
        createdAt: new Date()
      }
    ),

    updateWrite(
      env,
      `support_threads/${encodeURIComponent(threadId)}`,
      {
        lastMessage: preview,
        lastMessageAt: new Date(),
        updatedAt: new Date(),
        status:
          senderRole === "customer"
            ? "open"
            : "active",
        ...(shouldSendWelcome
          ? {
              autoWelcomeSent: true,
              autoWelcomeAt: new Date()
            }
          : {})
      },
      thread.updateTime
    )
  ];

  if (shouldSendWelcome) {
    writes.push(
      createWrite(
        env,
        `support_threads/${encodeURIComponent(threadId)}/messages/${welcomeMessageId}`,
        {
          senderId: "barakah_support_bot",
          senderRole: "system",
          senderName: "مساعد بركة",
          text: welcomeMessage,
          createdAt:
            new Date(Date.now() + 1)
        }
      )
    );
  }

  // Business data is committed BEFORE any notification lookup.
  const commit =
    await firestoreCommit(
      env,
      token,
      writes
    );

  if (!commit) {
    fail(
      409,
      "support-thread-changed",
      "وصلت رسالة أخرى؛ حاول الإرسال مجددًا."
    );
  }

  // ----------------------------------------------------------
  // Everything below is notification-only best effort.
  // It must never make an already-saved message look failed.
  // ----------------------------------------------------------

  try {
    let recipientTokens = [];

    if (senderRole === "customer") {
      if (thread.assignedAgentId) {
        try {
          recipientTokens.push(
            ...await userPushTokens(
              env,
              token,
              thread.assignedAgentId
            )
          );
        } catch (error) {
          console.error(
            "support_agent_token_lookup_failed",
            String(error?.message || error)
          );
        }
      } else {
        try {
          const agents =
            await firestoreQuery(
              env,
              token,
              "users",
              [
                fieldEquals(
                  "role",
                  "customer_service"
                )
              ]
            );

          recipientTokens.push(
            ...agents
              .filter(
                (agent) =>
                  agent.customerServiceEnabled === true
              )
              .flatMap(
                (agent) =>
                  selectRecentPushTokens(
                    agent.fcmTokens
                  )
              )
          );
        } catch (error) {
          console.error(
            "support_agent_directory_failed",
            String(error?.message || error)
          );
        }
      }

      try {
        recipientTokens.push(
          ...await adminPushTokens(
            env,
            token
          )
        );
      } catch (error) {
        console.error(
          "support_admin_token_lookup_failed",
          String(error?.message || error)
        );
      }

    } else {
      try {
        recipientTokens =
          await userPushTokens(
            env,
            token,
            thread.customerId
          );
      } catch (error) {
        console.error(
          "support_customer_token_lookup_failed",
          String(error?.message || error)
        );
      }
    }

    await sendPushBestEffort(
      env,
      token,
      recipientTokens,
      {
        title: notificationTitle,
        body:
          `${senderName}: ${preview.slice(0, 180)}`,
        data: {
          type: "support_message",
          threadId,
          messageId,
          senderRole
        }
      },
      "support_message_notification_failed"
    );

  } catch (error) {
    console.error(
      "support_message_notification_failed",
      String(error?.message || error)
    );
  }

  if (shouldSendWelcome) {
    try {
      const customerTokens =
        await userPushTokens(
          env,
          token,
          thread.customerId
        );

      await sendPushBestEffort(
        env,
        token,
        customerTokens,
        {
          title:
            "أهلًا بك في خدمة عملاء بركة 🌟",
          body:
            "تم استلام رسالتك وسيقوم فريقنا بالرد عليك بأقرب وقت.",
          data: {
            type: "support_message",
            threadId,
            messageId: welcomeMessageId,
            senderRole: "system"
          }
        },
        "support_welcome_notification_failed"
      );

    } catch (error) {
      console.error(
        "support_welcome_notification_failed",
        String(error?.message || error)
      );
    }
  }

  return {
    ok: true,
    threadId,
    messageId
  };
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

function normalizeProductOptionGroups(rawGroups) {
  if (rawGroups === void 0 || rawGroups === null) return [];

  if (!Array.isArray(rawGroups)) {
    fail(400, "invalid-option-groups", "خيارات المنتج غير صالحة.");
  }

  if (rawGroups.length > 12) {
    fail(400, "too-many-option-groups", "الحد الأقصى لمجموعات الخيارات هو 12.");
  }

  const usedGroupIds = new Set();

  return rawGroups.map((rawGroup, groupIndex) => {
    if (!rawGroup || typeof rawGroup !== "object" || Array.isArray(rawGroup)) {
      fail(400, "invalid-option-group", "إحدى مجموعات الخيارات غير صالحة.");
    }

    const name = String(rawGroup.name || "").trim();
    const required = rawGroup.required === true;
    let id = String(rawGroup.id || "").trim() || `group_${groupIndex + 1}`;

    if (!name || name.length > 80) {
      fail(400, "invalid-option-group-name", "اسم مجموعة الخيارات غير صالح.");
    }

    if (id.length > 100 || usedGroupIds.has(id)) {
      fail(400, "invalid-option-group-id", "معرف مجموعة الخيارات غير صالح أو مكرر.");
    }

    usedGroupIds.add(id);

    const rawOptions = rawGroup.options;

    if (!Array.isArray(rawOptions) || rawOptions.length === 0) {
      fail(400, "missing-product-options", `أضف خيارًا داخل مجموعة "${name}".`);
    }

    if (rawOptions.length > 30) {
      fail(400, "too-many-product-options", `خيارات "${name}" أكثر من الحد المسموح.`);
    }

    const usedOptionIds = new Set();

    const options = rawOptions.map((rawOption, optionIndex) => {
      if (!rawOption || typeof rawOption !== "object" || Array.isArray(rawOption)) {
        fail(400, "invalid-product-option", `خيار داخل "${name}" غير صالح.`);
      }

      const optionName = String(rawOption.name || "").trim();
      let optionId =
        String(rawOption.id || "").trim() || `option_${optionIndex + 1}`;

      const priceDelta = Number(rawOption.priceDelta || 0);

      if (!optionName || optionName.length > 120) {
        fail(400, "invalid-product-option-name", `اسم خيار داخل "${name}" غير صالح.`);
      }

      if (optionId.length > 100 || usedOptionIds.has(optionId)) {
        fail(400, "invalid-product-option-id", "معرف الخيار غير صالح أو مكرر.");
      }

      if (!Number.isFinite(priceDelta) || priceDelta < 0 || priceDelta > 1e6) {
        fail(400, "invalid-option-price", `سعر الخيار "${optionName}" غير صالح.`);
      }

      usedOptionIds.add(optionId);

      return {
        id: optionId,
        name: optionName,
        priceDelta: Math.round(priceDelta * 100) / 100
      };
    });

    return {
      id,
      name,
      required,
      selectionType: "single",
      options
    };
  });
}
__name(normalizeProductOptionGroups, "normalizeProductOptionGroups");
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

  if (profile?.role === "admin" || profile?.role === "order_supervisor" || profile?.isAdmin === true) {
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
    taxiDriverApplications,
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
            firestoreQuery(
      env,
      token,
      "taxi_driver_applications",
      [
        fieldEquals("userId", targetUid)
      ]
    ).catch(() => []),
firestoreQuery(
      env,
      token,
      "taxi_driver_applications",
      [
        fieldEquals("userId", targetUid)
      ]
    ).catch(() => []),
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

  for (const application of taxiDriverApplications) {
    writes.push(
      deleteWrite(
        env,
        `taxi_driver_applications/${encodeURIComponent(application.id)}`
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
function canManageBusiness(userId, business) {
  return Boolean(
    business &&
      (business.ownerId === userId ||
        (Array.isArray(business.managerIds) && business.managerIds.includes(userId)))
  );
}
__name(canManageBusiness, "canManageBusiness");


async function listTaxiOfficeDrivers(request, env, user) {
  const data = await readJson(request);
  const businessId = String(data.businessId || "").trim();

  if (!/^[A-Za-z0-9_-]{1,128}$/.test(businessId)) {
    fail(
      400,
      "invalid-business",
      "رقم مكتب التكسي غير صالح."
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

  if (!business || business.kind === "product") {
    fail(
      404,
      "business-not-found",
      "مكتب التكسي غير موجود."
    );
  }

  const mayManage =
    user.uid === PRIMARY_ADMIN_UID ||
    actor?.role === "admin" ||
    actor?.isAdmin === true ||
    canManageBusiness(user.uid, business);

  if (!mayManage) {
    fail(
      403,
      "permission-denied",
      "لا يحق لهذا الحساب عرض سائقي مكتب التكسي."
    );
  }

  const type =
    String(business.type || "").trim().toLowerCase();

  const category =
    String(business.category || "").trim().toLowerCase();

  const activity =
    String(
      business.activityType ||
      business.activity ||
      ""
    ).trim().toLowerCase();

  const title =
    String(business.title || "").trim().toLowerCase();

  const taxiBusiness =
    type === "taxi" ||
    category.includes("تكسي") ||
    category.includes("تاكسي") ||
    category.includes("taxi") ||
    activity.includes("تكسي") ||
    activity.includes("تاكسي") ||
    activity.includes("taxi") ||
    title.includes("تكسي") ||
    title.includes("تاكسي");

  if (!taxiBusiness) {
    fail(
      409,
      "not-taxi-business",
      "المحل المحدد ليس مكتب تكسي."
    );
  }

  const matches = await firestoreQuery(
    env,
    token,
    "users",
    [
      fieldEquals("taxiBusinessId", businessId)
    ]
  );

  const drivers = matches
    .filter(
      (driver) =>
        driver?.id &&
        driver.taxiDriverEnabled === true
    )
    .map((driver) => ({
      uid: String(driver.id),

      name: String(
        driver.displayName ||
        driver.name ||
        driver.fullName ||
        "سائق بركة"
      )
        .trim()
        .slice(0, 120),

      vehicle: String(
        driver.taxiDriverVehicle ||
        driver.vehicleInfo ||
        driver.vehicle ||
        driver.carInfo ||
        ""
      )
        .trim()
        .slice(0, 160),

      plateNumber: String(
        driver.taxiDriverPlateNumber || ""
      )
        .trim()
        .slice(0, 40),

      vehicleColor: String(
        driver.taxiDriverVehicleColor || ""
      )
        .trim()
        .slice(0, 60)
    }));

  return {
    ok: true,
    businessId,
    drivers
  };
}
__name(
  listTaxiOfficeDrivers,
  "listTaxiOfficeDrivers"
);

async function assignTaxiDriver(request, env, user) {
  const data = await readJson(request);
  const driverUid = String(data.driverUid || "").trim();
  const businessId = String(data.businessId || "").trim();
  const action = data.action === "remove" ? "remove" : "assign";

  if (!/^[A-Za-z0-9_-]{1,128}$/.test(driverUid)) {
    fail(400, "invalid-driver", "رقم السائق غير صالح.");
  }

  if (
    action === "assign" &&
    !/^[A-Za-z0-9_-]{1,128}$/.test(businessId)
  ) {
    fail(400, "invalid-business", "رقم مكتب التكسي غير صالح.");
  }

  const token = await serviceToken(env);

  const actor = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(user.uid)}`
  );

  if (!isPrimaryAdmin(user, actor)) {
    fail(
      403,
      "permission-denied",
      "أدمن بركة فقط يستطيع ربط السائق بمكتب تكسي."
    );
  }

  const driver = await firestoreGet(
    env,
    token,
    `users/${encodeURIComponent(driverUid)}`
  );

  if (!driver) {
    fail(
      404,
      "driver-not-found",
      "الحساب غير موجود."
    );
  }

  // ربط السيارة بمكتب تكسي لا يتم إلا بعد وجود وثيقة طلب سائق معتمدة.
  // تبقى الهوية والرخصة ووثائق المركبة والتأمين وبيانات المستحقات وشروط
  // السائق محفوظة في taxi_driver_applications ولا يمكن تجاوزها بتعديل profile.
  const driverApplication = await firestoreGet(
    env,
    token,
    `taxi_driver_applications/${encodeURIComponent(driverUid)}`
  );

  if (
    action === "assign" &&
    (!driverApplication ||
      driverApplication.status !== "approved" ||
      driverApplication.identityVerified !== true ||
      driverApplication.driverLicenseVerified !== true ||
      driverApplication.vehicleDocumentsVerified !== true ||
      driverApplication.payoutVerified !== true ||
      driverApplication.acceptedDriverTerms !== true ||
      driverApplication.acceptedPrivacyPolicy !== true)
  ) {
    fail(
      409,
      "driver-documents-required",
      "لا يمكن ربط السائق بالمكتب قبل اعتماد وثيقة السائق والتحقق من المركبة."
    );
  }

  if (action === "remove") {
    const result = await firestoreCommit(env, token, [
      updateWrite(
        env,
        `users/${encodeURIComponent(driverUid)}`,
        {
          taxiBusinessId: null,
          taxiBusinessName: null,
          taxiDriverEnabled: false,
          taxiRemovedAt: new Date(),
          taxiRemovedBy: user.uid,
          updatedAt: new Date()
        },
        driver.updateTime
      )
    ]);

    if (!result) {
      fail(
        409,
        "driver-changed",
        "تغيّرت بيانات السائق. حاول مجددًا."
      );
    }

    return {
      ok: true,
      driverUid,
      taxiDriverEnabled: false
    };
  }

  const business = await firestoreGet(
    env,
    token,
    `items/${encodeURIComponent(businessId)}`
  );

  if (!business || business.kind === "product") {
    fail(404, "business-not-found", "مكتب التكسي غير موجود.");
  }

  const type = String(business.type || "").trim().toLowerCase();
  const merchantType = String(
    business.merchantType || ""
  ).trim().toLowerCase();
  const category = String(
    business.category || ""
  ).trim().toLowerCase();
  const activity = String(
    business.activityType || ""
  ).trim().toLowerCase();
  const title = String(
    business.title || business.name || ""
  ).trim();

  const taxiLike =
    type === "taxi" ||
    merchantType === "taxi" ||
    category.includes("تكسي") ||
    category.includes("تاكسي") ||
    category.includes("taxi") ||
    activity.includes("تكسي") ||
    activity.includes("تاكسي") ||
    activity.includes("taxi") ||
    title.includes("تكسي") ||
    title.includes("تاكسي");

  if (!taxiLike) {
    fail(
      409,
      "not-taxi-business",
      "المحل المحدد ليس مكتب تكسي."
    );
  }

  if (
    business.isActive === false ||
    ["closed", "coming_soon"].includes(
      String(business.businessStatus || business.status || "")
        .trim()
        .toLowerCase()
    )
  ) {
    fail(
      409,
      "taxi-business-unavailable",
      "مكتب التكسي غير متاح حاليًا."
    );
  }

  const businessName =
    title || "مكتب تكسي بركة";

  const result = await firestoreCommit(env, token, [
    updateWrite(
      env,
      `users/${encodeURIComponent(driverUid)}`,
      {
        taxiBusinessId: businessId,
        taxiBusinessName: businessName,
        taxiDriverEnabled: true,
        taxiAssignedAt: new Date(),
        taxiAssignedBy: user.uid,
        taxiAssignmentAgreementVersion: driverApplication.agreementVersion,
        updatedAt: new Date()
      },
      driver.updateTime
    )
  ]);

  if (!result) {
    fail(
      409,
      "driver-changed",
      "تغيّرت بيانات السائق. حاول مجددًا."
    );
  }

  return {
    ok: true,
    driverUid,
    businessId,
    businessName,
    taxiDriverEnabled: true
  };
}
__name(assignTaxiDriver, "assignTaxiDriver");

async function updateBusinessManager(request, env, user) {
  const data = await readJson(request);
  const businessId = String(data.businessId || "").trim();
  const email = String(data.email || "").trim().toLowerCase();
  const action = data.action === "remove" ? "remove" : "add";
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(businessId)) {
    fail(400, "invalid-business", "رقم المحل غير صالح.");
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    fail(400, "invalid-email", "أدخل بريدًا إلكترونيًا صحيحًا.");
  }

  const token = await serviceToken(env);
  const [actor, business, matches] = await Promise.all([
    firestoreGet(env, token, `users/${encodeURIComponent(user.uid)}`),
    firestoreGet(env, token, `items/${encodeURIComponent(businessId)}`),
    firestoreQuery(env, token, "users", [fieldEquals("email", email)])
  ]);
  if (!business || business.kind === "product") {
    fail(404, "business-not-found", "المحل غير موجود.");
  }
  const mayAssign = isPrimaryAdmin(user, actor) || business.ownerId === user.uid;
  if (!mayAssign) {
    fail(403, "permission-denied", "صاحب المحل أو أدمن بركة فقط يستطيع إضافة مديري المحل.");
  }
  const target = matches[0];
  if (!target?.id) {
    fail(404, "user-not-found", "لا يوجد حساب مسجل بهذا البريد. يجب أن يسجل الشخص في بركة أولًا.");
  }
  if (target.id === business.ownerId) {
    fail(409, "already-owner", "هذا البريد يعود إلى صاحب المحل بالفعل.");
  }
  if (["admin", "order_supervisor", "driver", "customer_service"].includes(String(target.role || ""))) {
    fail(409, "incompatible-role", "هذا الحساب مرتبط بوظيفة أخرى في بركة ولا يمكن إضافته كمدير محل.");
  }

  const managerIds = Array.isArray(business.managerIds) ? [...business.managerIds] : [];
  const managerEmails = Array.isArray(business.managerEmails) ? [...business.managerEmails] : [];
  const managedBusinessIds = Array.isArray(target.managedBusinessIds)
    ? [...target.managedBusinessIds]
    : [];

  if (action === "add") {
    if (!managerIds.includes(target.id)) managerIds.push(target.id);
    if (!managerEmails.includes(email)) managerEmails.push(email);
    if (!managedBusinessIds.includes(businessId)) managedBusinessIds.push(businessId);
  } else {
    const idIndex = managerIds.indexOf(target.id);
    if (idIndex >= 0) managerIds.splice(idIndex, 1);
    const emailIndex = managerEmails.indexOf(email);
    if (emailIndex >= 0) managerEmails.splice(emailIndex, 1);
    const businessIndex = managedBusinessIds.indexOf(businessId);
    if (businessIndex >= 0) managedBusinessIds.splice(businessIndex, 1);
  }

  const targetUpdates = {
    managedBusinessIds,
    merchantBusinessId: managedBusinessIds[0] || null,
    merchantEnabled: managedBusinessIds.length > 0,
    updatedAt: new Date()
  };
  if (action === "add") {
    targetUpdates.role = "merchant";
    if (target.role !== "merchant") {
      targetUpdates.roleBeforeMerchantManagement = target.role || "customer";
    }
    targetUpdates.merchantBusinessId = target.merchantBusinessId || businessId;
    targetUpdates.merchantEnabled = true;
  } else if (managedBusinessIds.length === 0) {
    targetUpdates.role = target.roleBeforeMerchantManagement || "customer";
    targetUpdates.roleBeforeMerchantManagement = null;
  }

  const result = await firestoreCommit(env, token, [
    updateWrite(env, `items/${encodeURIComponent(businessId)}`, {
      managerIds,
      managerEmails,
      updatedAt: new Date()
    }, business.updateTime),
    updateWrite(env, `users/${encodeURIComponent(target.id)}`, targetUpdates, target.updateTime)
  ]);
  if (!result) {
    fail(409, "manager-list-changed", "تغيرت قائمة مديري المحل. حاول مجددًا.");
  }
  return { ok: true, action, email, managerIds, managerEmails };
}
__name(updateBusinessManager, "updateBusinessManager");

async function createMerchantProduct(request, env, user) {
  const data = await readJson(request);
  const businessId = String(data.businessId || "").trim();
  const title = String(data.title || "").trim();
  const description = String(data.description || "").trim();
  const image = String(data.image || "").trim();
  const price = Number(data.price);
  const stock = Number(data.stock);
  const soldOut = data.soldOut === true;
  const optionGroups = normalizeProductOptionGroups(data.optionGroups);
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
  const isAdminProductManager = isPrimaryAdmin(user, actor);

  if (
    !isAdminProductManager &&
    (!actor || actor.role !== "merchant" || actor.merchantEnabled !== true)
  ) {
    fail(
      403,
      "merchant-not-authorized",
      "\u0647\u0630\u0627 \u0627\u0644\u062d\u0633\u0627\u0628 \u063a\u064a\u0631 \u0645\u0641\u0648\u0636 \u0644\u0625\u062f\u0627\u0631\u0629 \u0645\u062a\u062c\u0631."
    );
  }

  if (
    !business ||
    business.kind === "product" ||
    (!isAdminProductManager && !canManageBusiness(user.uid, business))
  ) {
    fail(
      403,
      "business-not-owned",
      "\u0644\u0627 \u064a\u0645\u0643\u0646\u0643 \u0625\u0636\u0627\u0641\u0629 \u0645\u0646\u062a\u062c\u0627\u062a \u0625\u0644\u0649 \u0647\u0630\u0627 \u0627\u0644\u0645\u062a\u062c\u0631."
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
    soldOut,
    optionGroups,
    ownerId: String(business.ownerId || user.uid),
    ownerEmail: business.ownerEmail || user.email || null,
    createdBy: user.uid,
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
  if (!product || product.kind !== "product") {
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
  if (!business || !canManageBusiness(user.uid, business)) {
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
  const soldOut = data.soldOut === true;
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
  const optionGroups =
    data.optionGroups === void 0
      ? normalizeProductOptionGroups(product.optionGroups || [])
      : normalizeProductOptionGroups(data.optionGroups);
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
          soldOut,
          optionGroups,
          businessId: product.businessId,
          businessTitle: String(business.title || ""),
          category: String(business.category || ""),
          type: String(business.type || ""),
          ownerId: String(business.ownerId || product.ownerId || user.uid),
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
    merchantUid: user.uid,
    businessOwnerUid: String(business.ownerId || "")
  });
  return {
    ok: true,
    productId
  };
}
__name(updateMerchantProduct, "updateMerchantProduct");
async function deleteMerchantProduct(env, user, productId) {
  const token = await serviceToken(env);
  const { product, business } = await requireOwnedMerchantProduct(
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
    merchantUid: user.uid,
    businessOwnerUid: String(business.ownerId || "")
  });
  return {
    ok: true,
    productId
  };
}
__name(deleteMerchantProduct, "deleteMerchantProduct");
async function createAgentOrder(request, env, user) {
  const data = await readJson(request);
  const agentId = String(data.agentId || "").trim();
  const details = String(data.details || "").trim().slice(0, 2e3);
  const customerPhone = String(data.customerPhone || "").trim().slice(0, 40);
  const deliveryAddress = String(data.deliveryAddress || "").trim().slice(0, 300);
  const paymentMethod = data.paymentMethod === "cash" ? "cash" : "card";
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(agentId)) {
    fail(400, "invalid-agent", "الوسيطة المحددة غير صالحة.");
  }
  if (details.length < 3 || customerPhone.length < 6 || deliveryAddress.length < 3) {
    fail(400, "missing-field", "أكمل تفاصيل الطلب ورقم الهاتف وعنوان التسليم.");
  }
  if (paymentMethod !== "cash") {
    fail(409, "card-payment-unavailable", "الدفع ببطاقة Visa غير متاح قبل ربط بوابة الدفع الآمنة.");
  }

  const token = await serviceToken(env);
  const agent = await firestoreGet(env, token, `items/${encodeURIComponent(agentId)}`);
  if (!agent || agent.kind !== "agent") {
    fail(404, "agent-not-found", "الوسيطة غير موجودة.");
  }
  const rawAgentFee = Number(
    agent.agentFee ?? agent.serviceFee ?? agent.fee ?? 0
  );
  const agentFee = Number.isFinite(rawAgentFee)
    ? Math.round(Math.max(0, rawAgentFee) * 100) / 100
    : 0;

  const requestId = crypto.randomUUID().replace(/-/g, "");
  const record = {
    agentId,
    agentName: String(agent.title || "الوسيطة"),
    customerId: user.uid,
    customerEmail: user.email || null,
    customerPhone,
    deliveryAddress,
    details,
    paymentMethod: "cash",
    paymentStatus: "cash_on_delivery",
    agentFee,
    earningStatus: "none",
    status: "pending",
    createdAt: new Date(),
    updatedAt: new Date()
  };
  await firestoreCreate(env, token, "agent_orders", requestId, record);

  const recipients = [
    agent.ownerId,
    ...(Array.isArray(agent.managerIds) ? agent.managerIds : []),
    PRIMARY_ADMIN_UID
  ].filter(Boolean);
  try {
    const pushTokens = (await Promise.all(
      [...new Set(recipients)].map((uid) => userPushTokens(env, token, uid))
    )).flat();
    await sendPushBestEffort(env, token, pushTokens, {
      title: "طلب جديد للوسيطة",
      body: `طلب جديد إلى ${record.agentName}`,
      data: { type: "agent_order", requestId, agentId }
    });
  } catch (error) {
    console.error("agent_order_notification_failed", error.message);
  }
  return { ok: true, requestId, status: "pending" };
}
__name(createAgentOrder, "createAgentOrder");

async function updateAgentOrderStatus(env, user, requestId, nextStatus) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(requestId)) {
    fail(
      400,
      "invalid-agent-order",
      "رقم طلب الوسيطة غير صالح."
    );
  }

  if (
    nextStatus !== "accepted" &&
    nextStatus !== "rejected"
  ) {
    fail(
      400,
      "invalid-agent-status",
      "حالة طلب الوسيطة غير صالحة."
    );
  }

  const token = await serviceToken(env);

  const [actor, order] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_orders/${encodeURIComponent(requestId)}`
    )
  ]);

  if (!order) {
    fail(
      404,
      "agent-order-not-found",
      "طلب الوسيطة غير موجود."
    );
  }

  const agent = await firestoreGet(
    env,
    token,
    `items/${encodeURIComponent(order.agentId)}`
  );

  if (!agent || agent.kind !== "agent") {
    fail(
      404,
      "agent-not-found",
      "بيانات الوسيطة غير موجودة."
    );
  }

  const allowed =
    isPrimaryAdmin(user, actor) ||
    canManageBusiness(user.uid, agent);

  if (!allowed) {
    fail(
      403,
      "permission-denied",
      "غير مسموح لك بإدارة طلبات هذه الوسيطة."
    );
  }

  if (order.status !== "pending") {
    fail(
      409,
      "agent-order-already-handled",
      "تم التعامل مع هذا الطلب مسبقًا."
    );
  }

  const now = new Date();

  const patch = {
    status: nextStatus,
    updatedAt: now
  };

  let deliveryCode = null;

  if (nextStatus === "accepted") {
    patch.acceptedBy = user.uid;
    patch.acceptedAt = now;

    deliveryCode = String(
      crypto.getRandomValues(new Uint32Array(1))[0] % 1000000
    ).padStart(6, "0");
  } else {
    patch.rejectedBy = user.uid;
    patch.rejectedAt = now;
  }

  const writes = [
    updateWrite(
      env,
      `agent_orders/${encodeURIComponent(requestId)}`,
      patch,
      order.updateTime
    )
  ];

  if (nextStatus === "accepted") {
    writes.push(
      createWrite(
        env,
        `agent_order_secrets/${encodeURIComponent(requestId)}`,
        {
          orderId: requestId,
          customerId: order.customerId,
          agentId: order.agentId,
          code: deliveryCode,
          attempts: 0,
          used: false,
          createdAt: now,
          updatedAt: now
        }
      )
    );
  }

  const result = await firestoreCommit(
    env,
    token,
    writes
  );

  if (!result) {
    fail(
      409,
      "agent-order-changed",
      "تغيّرت حالة الطلب أثناء العملية. حدّث الصفحة."
    );
  }

  return {
    ok: true,
    requestId,
    status: nextStatus
  };
}

__name(
  updateAgentOrderStatus,
  "updateAgentOrderStatus"
);

async function getAgentOrderDeliveryCode(env, user, requestId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(requestId)) {
    fail(400, "invalid-agent-order", "رقم طلب الوسيطة غير صالح.");
  }

  const token = await serviceToken(env);

  const [order, secret] = await Promise.all([
    firestoreGet(
      env,
      token,
      `agent_orders/${encodeURIComponent(requestId)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_order_secrets/${encodeURIComponent(requestId)}`
    )
  ]);

  if (!order) {
    fail(404, "agent-order-not-found", "طلب الوسيطة غير موجود.");
  }

  if (order.customerId !== user.uid) {
    fail(
      403,
      "permission-denied",
      "رمز التسليم متاح لصاحب الطلب فقط."
    );
  }

  if (order.status !== "accepted") {
    fail(
      409,
      "delivery-code-unavailable",
      "رمز التسليم يظهر بعد قبول الوسيطة للطلب."
    );
  }

  if (!secret || secret.used === true) {
    fail(
      409,
      "delivery-code-unavailable",
      "رمز التسليم غير متاح لهذا الطلب."
    );
  }

  return {
    ok: true,
    requestId,
    code: String(secret.code || "")
  };
}

__name(
  getAgentOrderDeliveryCode,
  "getAgentOrderDeliveryCode"
);


async function completeAgentOrder(request, env, user, requestId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(requestId)) {
    fail(400, "invalid-agent-order", "رقم طلب الوسيطة غير صالح.");
  }

  const data = await readJson(request);
  const code = String(data.code || "").trim();

  if (!/^[0-9]{6}$/.test(code)) {
    fail(
      400,
      "invalid-delivery-code",
      "أدخل رمز التسليم المكوّن من 6 أرقام."
    );
  }

  const token = await serviceToken(env);

  const [actor, order, secret] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_orders/${encodeURIComponent(requestId)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_order_secrets/${encodeURIComponent(requestId)}`
    )
  ]);

  if (!order) {
    fail(404, "agent-order-not-found", "طلب الوسيطة غير موجود.");
  }

  if (!secret) {
    fail(
      409,
      "delivery-code-not-created",
      "لم يتم إنشاء رمز تسليم لهذا الطلب."
    );
  }

  const agent = await firestoreGet(
    env,
    token,
    `items/${encodeURIComponent(order.agentId)}`
  );

  if (!agent || agent.kind !== "agent") {
    fail(404, "agent-not-found", "بيانات الوسيطة غير موجودة.");
  }

  const allowed =
    isPrimaryAdmin(user, actor) ||
    canManageBusiness(user.uid, agent);

  if (!allowed) {
    fail(
      403,
      "permission-denied",
      "غير مسموح لك بإتمام هذا الطلب."
    );
  }

  if (order.status !== "accepted") {
    fail(
      409,
      "invalid-agent-order-status",
      "لا يمكن إتمام الطلب في حالته الحالية."
    );
  }

  if (secret.used === true) {
    fail(
      409,
      "delivery-code-used",
      "تم استخدام رمز التسليم مسبقًا."
    );
  }

  const attempts = Number(secret.attempts || 0);

  if (attempts >= 5) {
    fail(
      429,
      "delivery-code-locked",
      "تم تجاوز عدد محاولات رمز التسليم."
    );
  }

  if (String(secret.code || "") !== code) {
    const failed = await firestoreCommit(
      env,
      token,
      [
        updateWrite(
          env,
          `agent_order_secrets/${encodeURIComponent(requestId)}`,
          {
            attempts: attempts + 1,
            updatedAt: new Date()
          },
          secret.updateTime
        )
      ]
    );

    if (!failed) {
      fail(
        409,
        "delivery-code-changed",
        "تغيّرت بيانات رمز التسليم. حاول مجددًا."
      );
    }

    fail(
      409,
      "wrong-delivery-code",
      "رمز التسليم غير صحيح."
    );
  }

  const now = new Date();

  const rawFee = Number(order.agentFee || 0);
  const agentFee = Number.isFinite(rawFee)
    ? Math.round(Math.max(0, rawFee) * 100) / 100
    : 0;

  const writes = [
    updateWrite(
      env,
      `agent_orders/${encodeURIComponent(requestId)}`,
      {
        status: "completed",
        completedBy: user.uid,
        completedAt: now,
        earningStatus: "due",
        updatedAt: now
      },
      order.updateTime
    ),

    updateWrite(
      env,
      `agent_order_secrets/${encodeURIComponent(requestId)}`,
      {
        used: true,
        usedAt: now,
        updatedAt: now
      },
      secret.updateTime
    ),

    createWrite(
      env,
      `agent_earnings/${encodeURIComponent(requestId)}`,
      {
        earningId: requestId,
        orderId: requestId,
        agentId: order.agentId,
        agentName: order.agentName || "الوسيطة",
        customerId: order.customerId,
        amount: agentFee,
        status: "due",
        frozen: false,
        disputeId: null,
        createdAt: now,
        updatedAt: now
      }
    )
  ];

  const result = await firestoreCommit(
    env,
    token,
    writes
  );

  if (!result) {
    fail(
      409,
      "agent-order-changed",
      "تغيّرت بيانات الطلب أثناء تأكيد التسليم. حاول مجددًا."
    );
  }

  return {
    ok: true,
    requestId,
    status: "completed",
    earningStatus: "due",
    agentFee
  };
}

__name(
  completeAgentOrder,
  "completeAgentOrder"
);




async function createAgentOrderDispute(request, env, user, requestId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(requestId)) {
    fail(400, "invalid-agent-order", "رقم طلب الوسيطة غير صالح.");
  }

  const data = await readJson(request);
  const reason = String(data.reason || "").trim();

  if (reason.length < 5 || reason.length > 1000) {
    fail(
      400,
      "invalid-dispute-reason",
      "اكتب سبب الاعتراض بوضوح."
    );
  }

  const token = await serviceToken(env);

  const [order, earning] = await Promise.all([
    firestoreGet(
      env,
      token,
      `agent_orders/${encodeURIComponent(requestId)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_earnings/${encodeURIComponent(requestId)}`
    )
  ]);

  if (!order) {
    fail(404, "agent-order-not-found", "طلب الوسيطة غير موجود.");
  }

  if (order.customerId !== user.uid) {
    fail(
      403,
      "permission-denied",
      "الاعتراض متاح لصاحب الطلب فقط."
    );
  }

  if (order.status !== "completed") {
    fail(
      409,
      "invalid-agent-order-status",
      "يمكن الاعتراض بعد إتمام الطلب فقط."
    );
  }

  if (!earning) {
    fail(
      409,
      "earning-not-found",
      "لم يتم إنشاء مستحق لهذا الطلب."
    );
  }

  if (
    earning.status !== "due" ||
    earning.frozen === true
  ) {
    fail(
      409,
      "earning-not-disputable",
      "هذا المستحق غير متاح للاعتراض."
    );
  }

  const disputeId = requestId;
  const now = new Date();

  const result = await firestoreCommit(
    env,
    token,
    [
      updateWrite(
        env,
        `agent_orders/${encodeURIComponent(requestId)}`,
        {
          status: "disputed",
          earningStatus: "frozen",
          disputeId,
          disputedAt: now,
          updatedAt: now
        },
        order.updateTime
      ),

      updateWrite(
        env,
        `agent_earnings/${encodeURIComponent(requestId)}`,
        {
          status: "frozen",
          frozen: true,
          disputeId,
          frozenAt: now,
          updatedAt: now
        },
        earning.updateTime
      ),

      createWrite(
        env,
        `agent_disputes/${encodeURIComponent(disputeId)}`,
        {
          disputeId,
          orderId: requestId,
          customerId: order.customerId,
          agentId: order.agentId,
          agentName: order.agentName || "الوسيطة",
          amount: Number(earning.amount || 0),
          reason,
          status: "open",
          createdBy: user.uid,
          createdAt: now,
          updatedAt: now
        }
      )
    ]
  );

  if (!result) {
    fail(
      409,
      "agent-dispute-conflict",
      "تغيّرت بيانات الطلب أثناء تسجيل الاعتراض. حاول مجددًا."
    );
  }

  return {
    ok: true,
    requestId,
    disputeId,
    status: "disputed",
    earningStatus: "frozen"
  };
}

async function resolveAgentOrderDispute(
  request,
  env,
  user,
  requestId
) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(requestId)) {
    fail(400, "invalid-agent-order", "رقم طلب الوسيطة غير صالح.");
  }

  const data = await readJson(request);
  const decision = String(data.decision || "").trim();
  const adminNote = String(data.adminNote || "").trim();

  if (!["release", "cancel"].includes(decision)) {
    fail(
      400,
      "invalid-dispute-decision",
      "قرار الاعتراض غير صالح."
    );
  }

  if (adminNote.length > 1000) {
    fail(
      400,
      "invalid-admin-note",
      "ملاحظة الأدمن طويلة جدًا."
    );
  }

  const token = await serviceToken(env);

  const [actor, order, earning, dispute] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_orders/${encodeURIComponent(requestId)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_earnings/${encodeURIComponent(requestId)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_disputes/${encodeURIComponent(requestId)}`
    )
  ]);

  if (!isPrimaryAdmin(user, actor)) {
    fail(
      403,
      "permission-denied",
      "معالجة اعتراضات الوسيطات متاحة للأدمن الأساسي فقط."
    );
  }

  if (!order || !earning || !dispute) {
    fail(
      404,
      "agent-dispute-not-found",
      "بيانات الاعتراض غير مكتملة أو غير موجودة."
    );
  }

  if (
    order.status !== "disputed" ||
    earning.status !== "frozen" ||
    earning.frozen !== true ||
    dispute.status !== "open"
  ) {
    fail(
      409,
      "dispute-already-resolved",
      "تمت معالجة هذا الاعتراض مسبقًا."
    );
  }

  const now = new Date();

  const release = decision === "release";

  const orderData = release
    ? {
        status: "completed",
        earningStatus: "due",
        disputeId: null,
        disputeResolvedAt: now,
        disputeResolvedBy: user.uid,
        updatedAt: now
      }
    : {
        status: "completed",
        earningStatus: "cancelled",
        disputeId: null,
        disputeResolvedAt: now,
        disputeResolvedBy: user.uid,
        updatedAt: now
      };

  const earningData = release
    ? {
        status: "due",
        frozen: false,
        disputeId: null,
        unfrozenAt: now,
        updatedAt: now
      }
    : {
        status: "cancelled",
        frozen: false,
        disputeId: null,
        cancelledAt: now,
        cancelledBy: user.uid,
        updatedAt: now
      };

  const disputeData = {
    status: release ? "rejected" : "accepted",
    decision,
    adminNote,
    resolvedBy: user.uid,
    resolvedAt: now,
    updatedAt: now
  };

  const result = await firestoreCommit(
    env,
    token,
    [
      updateWrite(
        env,
        `agent_orders/${encodeURIComponent(requestId)}`,
        orderData,
        order.updateTime
      ),
      updateWrite(
        env,
        `agent_earnings/${encodeURIComponent(requestId)}`,
        earningData,
        earning.updateTime
      ),
      updateWrite(
        env,
        `agent_disputes/${encodeURIComponent(requestId)}`,
        disputeData,
        dispute.updateTime
      )
    ]
  );

  if (!result) {
    fail(
      409,
      "agent-dispute-conflict",
      "تغيّرت بيانات الاعتراض أثناء المعالجة. حدّث الصفحة."
    );
  }

  return {
    ok: true,
    requestId,
    disputeStatus: disputeData.status,
    earningStatus: earningData.status
  };
}

async function settleAgentOrderEarning(env, user, requestId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(requestId)) {
    fail(400, "invalid-agent-order", "رقم طلب الوسيطة غير صالح.");
  }

  const token = await serviceToken(env);

  const [actor, order, earning] = await Promise.all([
    firestoreGet(
      env,
      token,
      `users/${encodeURIComponent(user.uid)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_orders/${encodeURIComponent(requestId)}`
    ),
    firestoreGet(
      env,
      token,
      `agent_earnings/${encodeURIComponent(requestId)}`
    )
  ]);

  if (!isPrimaryAdmin(user, actor)) {
    fail(
      403,
      "permission-denied",
      "تسوية مستحقات الوسيطات متاحة للأدمن الأساسي فقط."
    );
  }

  if (!order || !earning) {
    fail(
      404,
      "earning-not-found",
      "مستحق الوسيطة غير موجود."
    );
  }

  if (
    earning.status !== "due" ||
    earning.frozen === true
  ) {
    fail(
      409,
      "earning-not-settleable",
      "لا يمكن دفع مستحق معلّق أو تمت تسويته مسبقًا."
    );
  }

  const now = new Date();
  const transactionId = `agent_${requestId}_settled`;

  const result = await firestoreCommit(
    env,
    token,
    [
      updateWrite(
        env,
        `agent_orders/${encodeURIComponent(requestId)}`,
        {
          earningStatus: "settled",
          settledAt: now,
          settledBy: user.uid,
          updatedAt: now
        },
        order.updateTime
      ),

      updateWrite(
        env,
        `agent_earnings/${encodeURIComponent(requestId)}`,
        {
          status: "settled",
          frozen: false,
          settledAt: now,
          settledBy: user.uid,
          transactionId,
          updatedAt: now
        },
        earning.updateTime
      ),

      createWrite(
        env,
        `agent_finance_transactions/${encodeURIComponent(transactionId)}`,
        {
          transactionId,
          type: "agent_settlement",
          orderId: requestId,
          earningId: requestId,
          agentId: earning.agentId,
          agentName: earning.agentName || "الوسيطة",
          amount: Number(earning.amount || 0),
          status: "settled",
          createdBy: user.uid,
          createdAt: now
        }
      )
    ]
  );

  if (!result) {
    fail(
      409,
      "earning-settlement-conflict",
      "تغيّرت بيانات المستحق أثناء التسوية. حدّث الصفحة."
    );
  }

  return {
    ok: true,
    requestId,
    status: "settled",
    transactionId
  };
}

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
  const requested = rawItems.map((item) => {
    const selectedOptions = Array.isArray(item?.selectedOptions)
      ? item.selectedOptions
      : [];
    const specialNote = String(item?.specialNote || "").trim();

    if (selectedOptions.length > 12) {
      fail(
        400,
        "too-many-selected-options",
        "عدد خيارات أحد المنتجات أكبر من الحد المسموح."
      );
    }

    if (specialNote.length > 500) {
      fail(
        400,
        "special-note-too-long",
        "ملاحظة المنتج يجب ألا تتجاوز 500 حرف."
      );
    }

    return {
      productId: String(item?.productId || "").trim(),
      quantity: Number(item?.quantity),
      selectedOptions: selectedOptions.map((option) => ({
        groupId: String(option?.groupId || "").trim(),
        optionId: String(option?.optionId || "").trim()
      })),
      specialNote
    };
  });
  if (requested.some((item) => !/^[A-Za-z0-9_-]{1,128}$/.test(item.productId) || !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 99)) {
    fail(400, "invalid-items", "\u0623\u062D\u062F \u0623\u0635\u0646\u0627\u0641 \u0627\u0644\u0633\u0644\u0629 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  }
  const token = await serviceToken(env);
  const products = await Promise.all(requested.map((item) => firestoreGet(env, token, `items/${encodeURIComponent(item.productId)}`)));
  if (products.some((product) => !product || product.kind !== "product")) {
    fail(409, "product-unavailable", "\u0623\u062D\u062F \u0627\u0644\u0623\u0635\u0646\u0627\u0641 \u0644\u0645 \u064A\u0639\u062F \u0645\u062A\u0627\u062D\u064B\u0627.");
  }
  for (let index = 0; index < products.length; index += 1) {
    const product = products[index];
    if (product.soldOut === true) {
      fail(
        409,
        "product-sold-out",
        `${String(product.title || "\u0627\u0644\u0645\u0646\u062A\u062C")} \u0646\u0641\u062F \u0645\u0646 \u0627\u0644\u0645\u062E\u0632\u0648\u0646.`
      );
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
  if (business.businessStatus === "coming_soon") {
    fail(409, "business-coming-soon", "هذا المتجر قريبًا في بركة ولا يستقبل طلبات بعد.");
  }
  if (business.businessStatus === "closed" && !scheduledFor) {
    fail(409, "business-closed", "\u0627\u0644\u0645\u062D\u0644 \u0645\u063A\u0644\u0642 \u0627\u0644\u0622\u0646\u061B \u064A\u0645\u0643\u0646\u0643 \u062C\u062F\u0648\u0644\u0629 \u0627\u0644\u0637\u0644\u0628.");
  }
  const items = products.map((product, index) => {
    const requestedItem = requested[index];
    const basePrice = Number(product.price);

    if (!Number.isFinite(basePrice) || basePrice < 0) {
      fail(
        409,
        "invalid-product-price",
        "سعر أحد الأصناف غير صالح."
      );
    }

    const optionGroups = normalizeProductOptionGroups(
      product.optionGroups || []
    );

    const requestedSelections = requestedItem.selectedOptions || [];
    const selectionByGroup = new Map();

    for (const selection of requestedSelections) {
      if (
        !selection.groupId ||
        !selection.optionId ||
        selectionByGroup.has(selection.groupId)
      ) {
        fail(
          400,
          "invalid-selected-options",
          `اختيارات ${String(product.title || "المنتج")} غير صالحة.`
        );
      }

      selectionByGroup.set(selection.groupId, selection.optionId);
    }

    const authoritativeSelections = [];
    let optionsTotal = 0;

    for (const group of optionGroups) {
      const selectedOptionId = selectionByGroup.get(group.id);

      if (!selectedOptionId) {
        if (group.required === true) {
          fail(
            400,
            "required-option-missing",
            `اختر "${group.name}" للمنتج ${String(product.title || "")}.`
          );
        }
        continue;
      }

      const option = group.options.find(
        (candidate) => candidate.id === selectedOptionId
      );

      if (!option) {
        fail(
          400,
          "invalid-selected-option",
          `أحد خيارات ${String(product.title || "المنتج")} لم يعد متاحًا.`
        );
      }

      const priceDelta = Number(option.priceDelta || 0);

      if (
        !Number.isFinite(priceDelta) ||
        priceDelta < 0 ||
        priceDelta > 1e6
      ) {
        fail(
          409,
          "invalid-option-price",
          `سعر أحد خيارات ${String(product.title || "المنتج")} غير صالح.`
        );
      }

      optionsTotal = money(optionsTotal + priceDelta);

      authoritativeSelections.push({
        groupId: group.id,
        groupName: group.name,
        optionId: option.id,
        optionName: option.name,
        priceDelta: money(priceDelta)
      });

      selectionByGroup.delete(group.id);
    }

    // أي groupId بقي هنا يعني أن التطبيق أرسل خيارًا
    // غير موجود أصلًا في تعريف المنتج.
    if (selectionByGroup.size > 0) {
      fail(
        400,
        "unknown-option-group",
        `أحد خيارات ${String(product.title || "المنتج")} غير معروف.`
      );
    }

    const price = money(basePrice + optionsTotal);

    return {
      productId: requestedItem.productId,
      title: String(product.title || "منتج"),
      basePrice: money(basePrice),
      optionsTotal,
      price,
      quantity: requestedItem.quantity,
      selectedOptions: authoritativeSelections,
      specialNote: requestedItem.specialNote || "",
      businessId,
      businessTitle: String(business.title || "")
    };
  });
  const subtotal = money(items.reduce((sum, item) => sum + item.price * item.quantity, 0));
  const deliveryMethod = data.deliveryMethod === "pickup" ? "pickup" : "delivery";
  const paymentMethod = data.paymentMethod === "cash" ? "cash" : "cash";
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
  let deliveryFee = 0;
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

    const businessLatitude = finiteOrNull(business.latitude);
    const businessLongitude = finiteOrNull(business.longitude);
    const deliveryZones = Array.isArray(business.deliveryZones)
      ? business.deliveryZones
          .filter((zone) => Number.isFinite(Number(zone?.maxKm)) && Number.isFinite(Number(zone?.fee)))
          .map((zone) => ({ maxKm: Number(zone.maxKm), fee: Number(zone.fee) }))
          .filter((zone) => zone.maxKm >= 0 && zone.fee >= 0)
          .sort((a, b) => a.maxKm - b.maxKm)
      : [];

    if (businessLatitude !== null && businessLongitude !== null && deliveryZones.length > 0) {
      const distanceKm = geoDistanceKm(
        businessLatitude,
        businessLongitude,
        deliveryLatitude,
        deliveryLongitude
      );
      const matchedZone = deliveryZones.find((zone) => distanceKm <= zone.maxKm);
      if (!matchedZone) {
        fail(
          409,
          "delivery-outside-range",
          "\u0639\u0646\u0648\u0627\u0646\u0643 \u062E\u0627\u0631\u062C \u0646\u0637\u0627\u0642 \u062A\u0648\u0635\u064A\u0644 \u0647\u0630\u0627 \u0627\u0644\u0645\u062A\u062C\u0631. \u0627\u062E\u062A\u0631 \u0627\u0633\u062A\u0644\u0627\u0645\u064B\u0627 \u0634\u062E\u0635\u064A\u064B\u0627 \u0623\u0648 \u0639\u0646\u0648\u0627\u0646\u064B\u0627 \u0623\u0642\u0631\u0628."
        );
      }
      deliveryFee = money(matchedZone.fee);
    } else {
      deliveryFee = money(Number(business.deliveryFee || 0));
    }
  }
  const total = money(subtotal + Math.max(0, deliveryFee));
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
  const orderRecord = {
    orderNumber,
    orderSequence: sequence,
    customerId: user.uid,
    customerName: String(
      customer.fullName ||
      customer.name ||
      customer.displayName ||
      user.name ||
      ""
    ).trim() || null,
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
    restaurantAddress: String(business.address || ""),
    restaurantLatitude: finiteOrNull(business.latitude),
    restaurantLongitude: finiteOrNull(business.longitude),
    preparationMinutes,
    estimatedReadyAt: new Date(Date.now() + preparationMinutes * 6e4),
    scheduledFor,
    rewardGranted: false,
    inventoryManaged: false,
    stockRestored: true,
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
async function restoreOrderInventory(env, token, order) {
  if (order?.stockRestored === true) return [];
  const quantities = new Map();
  for (const rawItem of Array.isArray(order?.items) ? order.items : []) {
    const item = rawItem && typeof rawItem === "object" ? rawItem : {};
    const productId = String(item.productId || "").trim();
    const quantity = Number(item.quantity);
    if (!productId || !Number.isInteger(quantity) || quantity < 1) continue;
    quantities.set(productId, (quantities.get(productId) || 0) + quantity);
  }
  const productIds = [...quantities.keys()];
  const products = await Promise.all(
    productIds.map((productId) => firestoreGet(
      env,
      token,
      `items/${encodeURIComponent(productId)}`
    ))
  );
  return products.flatMap((product, index) => {
    if (!product || product.kind !== "product") return [];
    const stock = Number(product.stock);
    if (!Number.isInteger(stock)) return [];
    const productId = productIds[index];
    const nextStock = Math.max(0, Math.floor(stock) + quantities.get(productId));
    return [updateWrite(
      env,
      `items/${encodeURIComponent(productId)}`,
      {
        stock: nextStock,
        soldOut: nextStock <= 0,
        updatedAt: /* @__PURE__ */ new Date()
      },
      product.updateTime
    )];
  });
}
__name(restoreOrderInventory, "restoreOrderInventory");
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
      const needsPointRefund = pointsUsed2 > 0 &&
        order.barakahPointsRefunded !== true &&
        Boolean(order.customerId);
      const needsInventoryRestore = order.stockRestored !== true;
      if (!needsPointRefund && !needsInventoryRestore) {
        return {
          orderId,
          status: "cancelled",
          pointsRefunded: order.barakahPointsRefundedAmount || 0
        };
      }
      const writes = [];
      const orderPatch = { updatedAt: /* @__PURE__ */ new Date() };
      if (needsPointRefund) {
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
        writes.push(updateWrite(
          env,
          `users/${encodeURIComponent(order.customerId)}`,
          {
            loyaltyPoints: currentPoints + pointsUsed2,
            updatedAt: /* @__PURE__ */ new Date()
          },
          customer.updateTime
        ));
        writes.push(loyaltyTransactionWrite(
          env,
          `order_REFUND_${orderId}`,
          {
            customerId: order.customerId,
            type: "refund",
            pointsDelta: pointsUsed2,
            balanceBefore: currentPoints,
            balanceAfter: currentPoints + pointsUsed2,
            orderId,
            orderNumber: order.orderNumber || null,
            source: "cancelled_order",
            description: `\u0625\u0631\u062c\u0627\u0639 ${pointsUsed2} \u0646\u0642\u0637\u0629 \u0628\u0639\u062f \u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u0637\u0644\u0628`,
            metadata: { reason: "cancelled_order" }
          }
        ));
        Object.assign(orderPatch, {
          barakahPointsRefunded: true,
          barakahPointsRefundedAmount: pointsUsed2,
          barakahPointsRefundedAt: /* @__PURE__ */ new Date()
        });
      }
      if (needsInventoryRestore) {
        writes.push(...await restoreOrderInventory(env, token, order));
        Object.assign(orderPatch, {
          stockRestored: true,
          stockRestoredAt: /* @__PURE__ */ new Date()
        });
      }
      writes.push(updateWrite(
        env,
        `orders/${encodeURIComponent(orderId)}`,
        orderPatch,
        order.updateTime
      ));
      const repairResult = await firestoreCommit(env, token, writes);
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
    const orderPatch = {
      status: "cancelled",
      cancelledBy: "customer",
      cancelledAt: /* @__PURE__ */ new Date(),
      barakahPointsRefunded: pointsUsed > 0 ? true : order.barakahPointsRefunded === true,
      barakahPointsRefundedAmount: pointsUsed > 0 ? pointsUsed : Number(order.barakahPointsRefundedAmount || 0),
      ...pointsUsed > 0 ? { barakahPointsRefundedAt: /* @__PURE__ */ new Date() } : {},
      updatedAt: /* @__PURE__ */ new Date()
    };
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
      writes.push(loyaltyTransactionWrite(
        env,
        `order_REFUND_${orderId}`,
        {
          customerId: order.customerId,
          type: "refund",
          pointsDelta: pointsUsed,
          balanceBefore: currentPoints,
          balanceAfter: currentPoints + pointsUsed,
          orderId,
          orderNumber: order.orderNumber || null,
          source: "cancelled_order",
          description: `\u0625\u0631\u062c\u0627\u0639 ${pointsUsed} \u0646\u0642\u0637\u0629 \u0628\u0639\u062f \u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u0637\u0644\u0628`,
          metadata: { reason: "cancelled_order" }
        }
      ));
    }
    if (order.stockRestored !== true) {
      writes.push(...await restoreOrderInventory(env, token, order));
      Object.assign(orderPatch, {
        stockRestored: true,
        stockRestoredAt: /* @__PURE__ */ new Date()
      });
    }
    writes.push(updateWrite(
      env,
      `orders/${encodeURIComponent(orderId)}`,
      orderPatch,
      order.updateTime
    ));
    const result = await firestoreCommit(
      env,
      token,
      writes
    );
    if (result) {
      try {
        await notifyCustomerOrderStatus(
          env,
          token,
          { ...order, ...orderPatch },
          orderId,
          "cancelled"
        );
      } catch (error) {
        console.error(
          "customer_cancel_notification_failed",
          error.message
        );
      }

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
function canTransitionOrderStatus(currentStatus, nextStatus, {
  isAdmin = false,
  isPickupMerchant = false,
  isPickupOrder = false
} = {}) {
  if (isAdmin && isPickupOrder && currentStatus === "ready" && nextStatus === "delivered") {
    return true;
  }
  const transitions = {
    new: ["accepted", "rejected"],
    scheduled: ["accepted", "rejected"],
    accepted: ["preparing", "rejected"],
    preparing: ["ready", "rejected"],
    ready: isPickupMerchant && isPickupOrder ? ["delivered"] : [],
    driver_assigned: ["picked_up"],
    picked_up: ["delivered"]
  };
  return transitions[currentStatus]?.includes(nextStatus) === true;
}
__name(canTransitionOrderStatus, "canTransitionOrderStatus");
async function updateOrderStatus(request, env, user, orderId) {
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(orderId)) fail(400, "invalid-order", "\u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D.");
  const data = await readJson(request);
  const allowed = /* @__PURE__ */ new Set(["accepted", "preparing", "ready", "rejected", "picked_up", "delivered", "awaiting_driver"]);
  if (!allowed.has(data.status)) fail(400, "invalid-status", "\u062D\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0635\u0627\u0644\u062D\u0629.");
  const token = await serviceToken(env);
  const [actor, order] = await Promise.all([
    firestoreGet(env, token, `users/${encodeURIComponent(user.uid)}`),
    firestoreGet(env, token, `orders/${encodeURIComponent(orderId)}`)
  ]);
  if (!order) fail(404, "order-not-found", "\u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F.");
  const isAdmin = isPrimaryAdmin(user, actor) ||
    (actor?.role === "order_supervisor" && actor?.adminPermissions?.manageOrders === true);
  const orderBusiness = order.businessId
    ? await firestoreGet(env, token, `items/${encodeURIComponent(order.businessId)}`)
    : null;
  const isMerchant = Boolean(
    actor &&
      orderBusiness &&
      (canManageBusiness(user.uid, orderBusiness) ||
        actor.merchantBusinessId === order.businessId ||
        (Array.isArray(actor.managedBusinessIds) &&
          actor.managedBusinessIds.includes(order.businessId)))
  );
  const isDriver = actor?.role === "driver" && order.driverId === user.uid;
  const isPickupMerchant = Boolean(isMerchant && order.deliveryMethod === "pickup");
  const merchantStates = /* @__PURE__ */ new Set(["accepted", "preparing", "ready", "rejected"]);
  const driverStates = /* @__PURE__ */ new Set(["picked_up", "delivered"]);
  if (!isAdmin && !(isMerchant && merchantStates.has(data.status)) && !(isPickupMerchant && data.status === "delivered") && !(isDriver && driverStates.has(data.status))) {
    fail(403, "permission-denied", "\u0644\u0627 \u062A\u0645\u0644\u0643 \u0635\u0644\u0627\u062D\u064A\u0629 \u062A\u063A\u064A\u064A\u0631 \u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628.");
  }
  if (data.status === "awaiting_driver") {
    if (
      !isAdmin ||
      order.status !== "ready" ||
      order.awaitingAdminApproval !== true ||
      order.deliveryMethod === "pickup"
    ) {
      fail(
        403,
        "admin-approval-required",
        "\u0644\u0627 \u064a\u0645\u0643\u0646 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0637\u0644\u0628 \u0644\u0644\u0633\u0627\u0626\u0642 \u0642\u0628\u0644 \u0645\u0648\u0627\u0641\u0642\u0629 \u0627\u0644\u0623\u062f\u0645\u0646."
      );
    }

    return await publishOrderToDrivers(
      env,
      token,
      order,
      orderId,
      user.uid
    );
  }

  if (!canTransitionOrderStatus(order.status, data.status, {
    isAdmin,
    isPickupMerchant,
    isPickupOrder: order.deliveryMethod === "pickup"
  })) {
    if (isAdmin && data.status === "delivered") {
      fail(
        409,
        "invalid-transition",
        "\u0637\u0644\u0628 \u0627\u0644\u062A\u0648\u0635\u064A\u0644 \u064A\u062C\u0628 \u0623\u0646 \u064A\u0645\u0631 \u0628\u0627\u0644\u0633\u0627\u0626\u0642 \u0642\u0628\u0644 \u062A\u0623\u0643\u064A\u062F \u0627\u0644\u062A\u0633\u0644\u064A\u0645."
      );
    }
    fail(409, "invalid-transition", "\u0644\u0627 \u064A\u0645\u0643\u0646 \u0646\u0642\u0644 \u0627\u0644\u0637\u0644\u0628 \u0625\u0644\u0649 \u0647\u0630\u0647 \u0627\u0644\u062D\u0627\u0644\u0629 \u0627\u0644\u0622\u0646.");
  }
  if (order.status === "scheduled" && order.scheduledFor && Date.parse(order.scheduledFor) > Date.now() && !isAdmin) {
    fail(409, "scheduled-order", "\u0644\u0645 \u064A\u062D\u0646 \u0645\u0648\u0639\u062F \u0627\u0644\u0637\u0644\u0628 \u0627\u0644\u0645\u062C\u062F\u0648\u0644 \u0628\u0639\u062F.");
  }
  if (data.status === "ready") {
    if (order.deliveryMethod === "pickup") {
      const result = await publishOrderToDrivers(
        env,
        token,
        order,
        orderId,
        user.uid
      );

      try {
        await notifyCustomerOrderStatus(
          env,
          token,
          { ...order, status: "ready" },
          orderId,
          "ready"
        );
      } catch (error) {
        console.error(
          "customer_status_notification_failed",
          error.message
        );
      }

      return result;
    }

    const statusChangedAt = /* @__PURE__ */ new Date();

    const orderPatch = {
      status: "ready",
      awaitingDriver: false,
      awaitingAdminApproval: true,
      readyAt: statusChangedAt,
      readyBy: user.uid,
      updatedAt: statusChangedAt
    };

    const result = await firestoreCommit(env, token, [
      updateWrite(
        env,
        "orders/" + encodeURIComponent(orderId),
        orderPatch,
        order.updateTime
      )
    ]);

    if (!result) {
      fail(
        409,
        "order-changed",
        "\u062a\u063a\u064a\u0651\u0631\u062a \u062d\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628\u061b \u062d\u062f\u0651\u062b \u0627\u0644\u0635\u0641\u062d\u0629."
      );
    }

    try {
      await notifyCustomerOrderStatus(
        env,
        token,
        { ...order, ...orderPatch },
        orderId,
        "ready"
      );
    } catch (error) {
      console.error(
        "customer_status_notification_failed",
        error.message
      );
    }

    // إشعار الأدمن الرئيسي + مشرفي الطلبات بأن الطلب جاهز للموافقة.
    try {
      const [ownerTokens, supervisors, business, directlyLinkedMerchants, managedBusinessMerchants] =
        await Promise.all([
          adminPushTokens(env, token),
          firestoreQuery(env, token, "users", [
            fieldEquals("role", "order_supervisor")
          ]),
          order.businessId
            ? firestoreGet(
                env,
                token,
                `items/${encodeURIComponent(order.businessId)}`
              )
            : null,
          order.businessId
            ? firestoreQuery(env, token, "users", [
                fieldEquals("merchantBusinessId", order.businessId)
              ])
            : [],
          order.businessId
            ? firestoreQuery(env, token, "users", [
                fieldArrayContains("managedBusinessIds", order.businessId)
              ])
            : []
        ]);

      const adminTokens = [
        ...ownerTokens,
        ...supervisors
          .filter(
            (supervisor) =>
              supervisor.adminPermissions?.manageOrders === true
          )
          .flatMap((supervisor) =>
            selectRecentPushTokens(supervisor.fcmTokens)
          )
      ];

      const merchantUserIds = [
        business?.ownerId,
        ...(Array.isArray(business?.managerIds) ? business.managerIds : [])
      ].filter(Boolean);

      const merchantTokens = (
        await Promise.all(
          [...new Set(merchantUserIds)].map((uid) =>
            userPushTokens(env, token, uid)
          )
        )
      ).flat();

      merchantTokens.push(
        ...directlyLinkedMerchants.flatMap((profile) =>
          selectRecentPushTokens(profile.fcmTokens)
        ),
        ...managedBusinessMerchants.flatMap((profile) =>
          selectRecentPushTokens(profile.fcmTokens)
        )
      );

      const orderLabel = String(
        order.orderNumber || orderId.substring(0, 6).toUpperCase()
      );

      await sendPushBestEffort(
        env,
        token,
        [
          ...adminTokens,
          ...merchantTokens
        ],
        {
          title: "\u0637\u0644\u0628 \u062c\u0627\u0647\u0632 \u0644\u0644\u0645\u0648\u0627\u0641\u0642\u0629",
          body:
            "\u0627\u0644\u0637\u0644\u0628 #" +
            orderLabel +
            " \u062c\u0627\u0647\u0632 \u0645\u0646 " +
            (order.businessTitle || "\u0627\u0644\u0645\u062d\u0644") +
            " \u0648\u064a\u0646\u062a\u0638\u0631 \u0645\u0648\u0627\u0641\u0642\u062a\u0643 \u0644\u0625\u0631\u0633\u0627\u0644\u0647 \u0644\u0644\u0633\u0627\u0626\u0642.",
          data: {
            type: "order_status",
            orderId,
            orderNumber: orderLabel,
            status: "ready",
            awaitingAdminApproval: "true"
          }
        }
      );
    } catch (error) {
      console.error(
        "admin_ready_notification_failed",
        error.message
      );
    }

    return {
      orderId,
      status: "ready",
      awaitingAdminApproval: true
    };
  }
  if (data.status === "delivered") {
    return completeDelivery(
      env,
      token,
      order,
      orderId,
      user.uid,
      isAdmin,
      isPickupMerchant
    );
  }
  const statusChangedAt = /* @__PURE__ */ new Date();
  const statusAuditFields = {
    accepted: {
      acceptedAt: statusChangedAt,
      acceptedBy: user.uid
    },
    preparing: {
      preparingAt: statusChangedAt,
      preparingBy: user.uid
    },
    rejected: {
      rejectedAt: statusChangedAt,
      rejectedBy: user.uid
    },
    picked_up: {
      pickedUpAt: statusChangedAt,
      pickedUpBy: user.uid
    }
  };
  const orderPatch = {
    status: data.status,
    updatedAt: statusChangedAt,
    ...(statusAuditFields[data.status] || {})
  };
  const writes = [];
  if (data.status === "rejected" && order.stockRestored !== true) {
    writes.push(...await restoreOrderInventory(env, token, order));
    Object.assign(orderPatch, {
      stockRestored: true,
      stockRestoredAt: /* @__PURE__ */ new Date()
    });
  }
  writes.push(updateWrite(
    env,
    `orders/${encodeURIComponent(orderId)}`,
    orderPatch,
    order.updateTime
  ));
  const result = await firestoreCommit(env, token, writes);
  if (!result) {
    fail(
      409,
      "order-changed",
      "\u062A\u063A\u064A\u0651\u0631\u062A \u062D\u0627\u0644\u0629 \u0627\u0644\u0637\u0644\u0628\u061B \u062D\u062F\u0651\u062B \u0627\u0644\u0635\u0641\u062D\u0629."
    );
  }
  if (
    data.status === "accepted" ||
    data.status === "rejected"
  ) {
    try {
      await notifyOrderAdminAlarmStop(
        env,
        token,
        orderId,
        { ...order, status: data.status },
        data.status
      );
    } catch (error) {
      console.error(
        "order_admin_alarm_stop_notification_failed",
        error.message
      );
    }
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
async function publishOrderToDrivers(env, token, order, orderId, actorId) {
  if (order.deliveryMethod === "pickup") {
    const result2 = await firestoreCommit(env, token, [
      updateWrite(
        env,
        `orders/${encodeURIComponent(orderId)}`,
        {
          status: "ready",
          awaitingDriver: false,
          readyAt: /* @__PURE__ */ new Date(),
          readyBy: actorId,
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
        awaitingAdminApproval: false,
        adminApprovedAt: /* @__PURE__ */ new Date(),
        adminApprovedBy: actorId,
        readyAt: order.readyAt || /* @__PURE__ */ new Date(),
        readyBy: order.readyBy || actorId,
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
  const driverTokens = availableDrivers.flatMap(
    (driver) => selectRecentPushTokens(driver.fcmTokens, 1)
  );
  if (driverTokens.length > 0) {
    const orderLabel = String(
      order.orderNumber || orderId.substring(0, 6).toUpperCase()
    );
    try {
      await sendPushBestEffort(
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
      restaurantAddress: order.restaurantAddress || null,
      restaurantLatitude: order.restaurantLatitude ?? null,
      restaurantLongitude: order.restaurantLongitude ?? null,
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
  const driverTokens = selectRecentPushTokens(driver?.fcmTokens);
  if (!waitingOrders.length || !driverTokens.length) return waitingOrders.length;
  const firstOrder = waitingOrders[0];
  const orderLabel = String(
    firstOrder.orderNumber || firstOrder.id?.substring(0, 6).toUpperCase() || "جديد"
  );
  await sendPushBestEffort(env, token, driverTokens, {
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
    try {
      waitingOrderCount =
        await notifyDriverAboutWaitingOrders(
          env,
          token,
          driver
        );
    } catch (error) {
      console.error(
        "waiting_driver_notification_failed",
        String(error?.message || error)
      );
    }
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
        driverAssignedAt: /* @__PURE__ */ new Date(),
        driverAssignedBy: user.uid,
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
  try {
    await notifyCustomerOrderStatus(
      env,
      token,
      { ...order, status: "driver_assigned", driverId: user.uid },
      orderId,
      "driver_assigned"
    );
  } catch (error) {
    console.error(
      "customer_status_notification_failed",
      error.message
    );
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
async function completeDelivery(env, token, initialOrder, orderId, actorId, isAdmin = false, isPickupMerchant = false) {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const order = attempt === 0 ? initialOrder : await firestoreGet(env, token, `orders/${encodeURIComponent(orderId)}`);
    if (!order) fail(404, "order-not-found", "\u0627\u0644\u0637\u0644\u0628 \u063A\u064A\u0631 \u0645\u0648\u062C\u0648\u062F.");
    if (order.rewardGranted === true && order.status === "delivered") {
      return { orderId, status: "delivered", repeated: true };
    }
    if (!isAdmin && !isPickupMerchant && (order.driverId !== actorId || order.status !== "picked_up")) {
      fail(409, "invalid-transition", "\u0644\u0627 \u064A\u0645\u0643\u0646 \u0625\u062A\u0645\u0627\u0645 \u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628 \u0627\u0644\u0622\u0646.");
    }
    if (isPickupMerchant && (order.deliveryMethod !== "pickup" || order.status !== "ready")) {
      fail(409, "invalid-transition", "لا يمكن إنهاء طلب الاستلام قبل تجهيزه.");
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
        deliveredBy: actorId,
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
    "canceled"
  ])).has(order.status)) {
    fail(409, "order-inactive", "\u064A\u062C\u0628 \u0625\u0643\u0645\u0627\u0644 \u0627\u0644\u0645\u0647\u0645\u0629 \u0642\u0628\u0644 \u0627\u0646\u062A\u0647\u0627\u0621 \u0627\u0644\u0637\u0644\u0628.");
  }
}
__name(assertRewardOrder, "assertRewardOrder");
function orderRewardDeadline(order) {
  const rewardStartedAt = Date.parse(
    order.completedAt ||
    order.deliveredAt ||
    order.finishedAt ||
    order.updatedAt ||
    order.createdAt ||
    order.createTime ||
    ""
  );
  if (!Number.isFinite(rewardStartedAt)) {
    fail(409, "order-time-missing", "تعذر تثبيت وقت بدء مهلة اللعب.");
  }
  return rewardStartedAt + 30 * 60 * 1e3;
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
function geoDistanceKm(latitude1, longitude1, latitude2, longitude2) {
  const radians = (value) => value * Math.PI / 180;
  const latitudeDelta = radians(latitude2 - latitude1);
  const longitudeDelta = radians(longitude2 - longitude1);
  const haversine = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(latitude1)) *
      Math.cos(radians(latitude2)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}
__name(geoDistanceKm, "geoDistanceKm");
export {
  canUploadMedia,
  canTransitionOrderStatus,
  createImageKitSignature,
  index_default as default,
communicationAudienceMatches,
communicationCampaignProgress,
normalizeCommunicationCampaignInput,
createCommunicationCampaign,
processCommunicationCampaign,
  selectCampaignPushTokens,
  selectRecentPushTokens,
  isUnregisteredFcmError,
  isRetryableFcmStatus,
  sendPushBestEffort,
};
