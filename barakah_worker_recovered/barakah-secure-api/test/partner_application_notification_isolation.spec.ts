import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index.js";

const env = {
  FIREBASE_PROJECT_ID: "partner-isolation-test",
  FIREBASE_CLIENT_EMAIL: "test@example.invalid",
  FIREBASE_PRIVATE_KEY: "AA==",
};
const adminToken = "admin-token-for-regression-test";
const ownerName = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/users/admin-owner`;
const ownerUpdateTime = "2026-09-29T12:00:00.000000Z";

const application = {
  businessName: "Test business",
  ownerName: "Test owner",
  email: "owner@example.invalid",
  phone: "0590000000",
  activityType: "shop",
  businessCategory: "groceries",
  area: "Test area",
  locationUrl: "https://example.invalid/location",
  identityDocumentRef: "test-document",
  latitude: 32,
  longitude: 35,
  acceptedPartnerAgreement: true,
  acceptedPrivacyPolicy: true,
};

function submitApplication() {
  return worker.fetch(
    new Request("https://example.invalid/v1/partner-applications", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(application),
    }),
    env,
  );
}

function mockServices({
  adminReadFailure,
  writeFailure = false,
  cleanupFailure,
}: {
  adminReadFailure?: "network" | "response";
  writeFailure?: boolean;
  cleanupFailure?: "query" | "commit";
} = {}) {
  const events: string[] = [];
  const saved = new Map<string, any>();
  const pushMessages: any[] = [];
  const cleanupQueries: any[] = [];
  const cleanupWrites: any[] = [];

  vi.stubGlobal("fetch", vi.fn(async (input: string | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    if (url.hostname === "oauth2.googleapis.com") {
      return Response.json({ access_token: "test-access-token" });
    }

    if (url.pathname.endsWith("/merchant_applications")) {
      events.push("save");
      if (writeFailure) return new Response("unavailable", { status: 503 });
      const id = url.searchParams.get("documentId")!;
      const document = {
        name: `${url.pathname}/${id}`,
        ...JSON.parse(String(init?.body)),
      };
      saved.set(id, document);
      return Response.json(document);
    }

    if (url.pathname.includes("/documents/users/")) {
      events.push("admin-read");
      if (adminReadFailure === "network") throw new Error("admin lookup unavailable");
      if (adminReadFailure === "response") {
        return new Response("unavailable", { status: 503 });
      }
      return Response.json({
        name: url.pathname,
        fields: {
          fcmTokens: {
            arrayValue: { values: [{ stringValue: adminToken }] },
          },
        },
      });
    }

    if (url.hostname === "fcm.googleapis.com") {
      events.push("push");
      pushMessages.push(JSON.parse(String(init?.body)).message);
      if (cleanupFailure) {
        return Response.json({
          error: {
            status: "NOT_FOUND",
            details: [{
              "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
              errorCode: "UNREGISTERED",
            }],
          },
        }, { status: 404 });
      }
      throw new Error("FCM unavailable");
    }

    if (url.pathname.endsWith("/documents:runQuery")) {
      events.push("cleanup-query");
      cleanupQueries.push(JSON.parse(String(init?.body)));
      if (cleanupFailure === "query") throw new Error("owner lookup unavailable");
      return Response.json([{ document: {
        name: ownerName,
        updateTime: ownerUpdateTime,
        fields: {
          fcmTokens: {
            arrayValue: { values: [{ stringValue: adminToken }] },
          },
        },
      } }]);
    }

    if (url.pathname.endsWith("/documents:commit")) {
      events.push("cleanup-commit");
      cleanupWrites.push(JSON.parse(String(init?.body)));
      return new Response("unavailable", { status: 503 });
    }

    events.push(`unexpected:${url.pathname}`);
    throw new Error("Unexpected service request");
  }));

  return { events, saved, pushMessages, cleanupQueries, cleanupWrites };
}

describe("partner application notification isolation", () => {
  let errorLog: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    // Service authentication is outside this regression's scope; no real keys
    // or external services are used.
    vi.spyOn(crypto.subtle, "importKey").mockResolvedValue({} as CryptoKey);
    vi.spyOn(crypto.subtle, "sign").mockResolvedValue(new Uint8Array([1]).buffer);
    errorLog = vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it.each(["network", "response"] as const)(
    "returns the saved application when the admin token lookup has a %s failure",
    async (adminReadFailure) => {
      const services = mockServices({ adminReadFailure });
      const response = await submitApplication();
      const result: any = await response.json();

      expect(response.status).toBe(201);
      expect(result).toEqual({ applicationId: expect.any(String), status: "pending" });
      expect(services.saved.size).toBe(1);
      expect(services.saved.get(result.applicationId).fields).toMatchObject({
        businessName: { stringValue: application.businessName },
        status: { stringValue: "pending" },
      });
      expect(services.events).toEqual(["save", "admin-read"]);
      expect(errorLog).toHaveBeenCalledWith(
        "partner_application_notification_failed",
        expect.any(String),
      );
    },
  );

  it("returns the saved application when FCM delivery fails", async () => {
    const services = mockServices();
    const response = await submitApplication();
    const result: any = await response.json();

    expect(response.status).toBe(201);
    expect(result).toEqual({ applicationId: expect.any(String), status: "pending" });
    expect(services.saved.size).toBe(1);
    expect(services.saved.has(result.applicationId)).toBe(true);
    expect(services.events).toEqual(["save", "admin-read", "push"]);
    expect(services.pushMessages).toHaveLength(1);
    expect(services.pushMessages[0].data).toEqual({
      type: "partner_application",
      applicationId: result.applicationId,
    });
  });

  it("preserves a business write failure and skips all notifications", async () => {
    const services = mockServices({ writeFailure: true });
    const response = await submitApplication();

    expect(response.status).toBe(502);
    expect(await response.json()).toMatchObject({ error: "firestore-write-failed" });
    expect(services.saved.size).toBe(0);
    expect(services.events).toEqual(["save"]);
    expect(services.pushMessages).toEqual([]);
  });

  it.each(["query", "commit"] as const)(
    "returns the saved application when UNREGISTERED cleanup has a %s failure",
    async (cleanupFailure) => {
      const services = mockServices({ cleanupFailure });
      const response = await submitApplication();
      const result: any = await response.json();

      expect(response.status).toBe(201);
      expect(result).toEqual({ applicationId: expect.any(String), status: "pending" });
      expect(services.saved.size).toBe(1);
      expect(services.saved.get(result.applicationId).fields).toMatchObject({
        businessName: { stringValue: application.businessName },
        status: { stringValue: "pending" },
      });
      expect(services.events).toEqual([
        "save", "admin-read", "push", "cleanup-query",
        ...(cleanupFailure === "commit" ? ["cleanup-commit"] : []),
      ]);
      expect(services.cleanupQueries).toEqual([{
        structuredQuery: {
          from: [{ collectionId: "users" }],
          where: {
            fieldFilter: {
              field: { fieldPath: "fcmTokens" },
              op: "ARRAY_CONTAINS",
              value: { stringValue: adminToken },
            },
          },
          limit: 100,
        },
      }]);
      if (cleanupFailure === "commit") {
        expect(services.cleanupWrites).toEqual([{
          writes: [{
            transform: {
              document: ownerName,
              fieldTransforms: [{
                fieldPath: "fcmTokens",
                removeAllFromArray: { values: [{ stringValue: adminToken }] },
              }],
            },
            currentDocument: { exists: true },
          }],
        }]);
      } else {
        expect(services.cleanupWrites).toEqual([]);
      }
      expect(errorLog).toHaveBeenCalledWith(
        cleanupFailure === "query"
          ? "push_invalid_token_cleanup_query_failed"
          : "push_invalid_token_cleanup_write_failed",
        expect.any(String),
      );
    },
  );
});
