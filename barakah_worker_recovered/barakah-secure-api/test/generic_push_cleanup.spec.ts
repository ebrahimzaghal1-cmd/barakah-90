import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { sendPushBestEffort } from "../src/index.js";

const env = {
  FIREBASE_PROJECT_ID: "push-cleanup-test",
  FIREBASE_CLIENT_EMAIL: "test@example.invalid",
  FIREBASE_PRIVATE_KEY: "AA==",
};
const documentRoot = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
const payload = { title: "Order updated", body: "Test notification", data: { orderId: "order-1" } };
const stale = "stale-registration-token-1";
const secondStale = "stale-registration-token-2";
const valid = "valid-registration-token-1";
const temporary = "temporary-failure-token-1";
type Mode = "immediate" | "fallback" | "outbox";
type Outcome = "unregistered" | "invalid" | "not-found" | "temporary" | "network" | "success";

function userDocument(id: string, tokens: string[]) {
  return {
    name: `${documentRoot}/users/${id}`,
    updateTime: "2026-09-29T10:00:00.000001Z",
    fields: {
      fcmTokens: { arrayValue: { values: tokens.map((stringValue) => ({ stringValue })) } },
      displayName: { stringValue: "Preserved profile" },
    },
  };
}

function tokensOf(document: any): string[] {
  return document.fields.fcmTokens.arrayValue.values.map((value: any) => value.stringValue);
}

function mockServices({
  documents = [],
  outcomes = { [stale]: "unregistered" },
  queryFailure,
  commitFailure,
  queryRows,
}: {
  documents?: any[];
  outcomes?: Record<string, Outcome>;
  queryFailure?: (token: string) => number | "network" | undefined;
  commitFailure?: (name: string) => number | "network" | undefined;
  queryRows?: any[];
} = {}) {
  const users = new Map(documents.map((document) => [document.name, structuredClone(document)]));
  const queries: any[] = [];
  const writes: any[] = [];
  const sent: string[] = [];
  const events: string[] = [];
  const unexpected: string[] = [];

  vi.stubGlobal("fetch", vi.fn(async (input: string | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    if (url.hostname === "oauth2.googleapis.com") {
      return Response.json({ access_token: "test-access-token" });
    }
    const body = JSON.parse(String(init?.body));
    if (url.hostname === "fcm.googleapis.com") {
      const token = body.message.token;
      sent.push(token);
      events.push("send");
      const outcome = outcomes[token] || "success";
      if (outcome === "network") throw new Error("FCM network failure");
      if (outcome === "success") return Response.json({ name: "messages/test" });
      const status = outcome === "temporary" ? 503 : outcome === "invalid" ? 400 : 404;
      return Response.json({
        error: {
          status: status === 404 ? "NOT_FOUND" : status === 400 ? "INVALID_ARGUMENT" : "UNAVAILABLE",
          details: outcome === "not-found" ? [] : [{
            "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
            errorCode: outcome === "unregistered" ? "UNREGISTERED" : "INVALID_ARGUMENT",
          }],
        },
      }, { status });
    }
    if (url.pathname.endsWith("/documents:runQuery")) {
      const query = body.structuredQuery;
      queries.push(query);
      events.push("query");
      const token = query.where?.fieldFilter?.value?.stringValue;
      const failure = queryFailure?.(token);
      if (failure === "network") throw new Error("Owner lookup network failure");
      if (failure) return new Response("Query unavailable", { status: failure });
      return Response.json(queryRows || [...users.values()]
        .filter((document) => tokensOf(document).includes(token))
        .map((document) => ({ document })));
    }
    if (url.pathname.endsWith("/documents:commit")) {
      events.push("commit");
      writes.push(...body.writes);
      for (const write of body.writes) {
        const name = write.transform.document;
        const failure = commitFailure?.(name);
        if (failure === "network") throw new Error("Cleanup write network failure");
        if (failure) return new Response("Write unavailable", { status: failure });
        const document = users.get(name);
        if (!document) {
          return new Response("Document changed", { status: 412 });
        }
        if (
          write.currentDocument?.updateTime &&
          document.updateTime !== write.currentDocument.updateTime
        ) {
          return new Response("Document changed", { status: 412 });
        }
        const removed = write.transform.fieldTransforms[0].removeAllFromArray.values
          .map((value: any) => value.stringValue);
        document.fields.fcmTokens.arrayValue.values = document.fields.fcmTokens.arrayValue.values
          .filter((value: any) => !removed.includes(value.stringValue));
        document.updateTime = "2026-09-29T10:00:01.000001Z";
      }
      return Response.json({ writeResults: [{}] });
    }
    unexpected.push(String(url));
    throw new Error("Unexpected external request");
  }));
  return { users, queries, writes, sent, events, unexpected };
}

function mockOutbox(tokens: string[], mode: Mode) {
  const finalized: { sql: string; values: any[] }[] = [];
  const db: any = {
    prepare(sql: string) {
      const statement = {
        sql,
        values: [] as any[],
        bind(...values: any[]) { this.values = values; return this; },
        async run() {
          if (sql.includes("last_result_json=?")) finalized.push({ sql, values: this.values });
          return { meta: { changes: 1 } };
        },
        async all() {
          return { results: [{
            id: "outbox-1",
            tokens_json: JSON.stringify(tokens),
            payload_json: JSON.stringify(payload),
            attempts: 1,
          }] };
        },
      };
      return statement;
    },
    async batch(statements: any[]) {
      if (mode === "fallback") throw new Error("Outbox persistence unavailable");
      return statements.map(() => ({ meta: { changes: 1 } }));
    },
  };
  return { db, finalized };
}

async function deliver(mode: Mode, tokens: string[]) {
  const outbox = mockOutbox(tokens, mode);
  const deliveryEnv = { ...env, DB: outbox.db };
  if (mode !== "outbox") {
    const result = await sendPushBestEffort(deliveryEnv, "test-access-token", tokens, payload);
    return { result, ...outbox };
  }
  const tasks: Promise<unknown>[] = [];
  await worker.scheduled({}, deliveryEnv, {
    waitUntil(task: Promise<unknown>) { tasks.push(task); },
  });
  await Promise.all(tasks);
  return { result: undefined, ...outbox };
}

describe("owner-aware generic push cleanup", () => {
  beforeEach(() => {
    vi.spyOn(crypto.subtle, "importKey").mockResolvedValue({} as CryptoKey);
    vi.spyOn(crypto.subtle, "sign").mockResolvedValue(new Uint8Array([1]).buffer);
    vi.spyOn(console, "error").mockImplementation(() => {});
  });
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it.each(["immediate", "fallback", "outbox"] as const)(
    "removes only the stale token from every matching owner in the %s path",
    async (mode) => {
      const owner = userDocument("owner-1", [stale, valid]);
      Object.assign(owner.fields, {
        id: { stringValue: "unrelated" },
        name: { stringValue: `${documentRoot}/users/unrelated` },
        updateTime: { stringValue: "untrusted-profile-timestamp" },
      });
      const services = mockServices({ documents: [
        owner,
        userDocument("owner-2", [stale, valid]),
        userDocument("unrelated", [valid]),
      ] });
      const { result, finalized } = await deliver(mode, [stale, valid, stale]);

      expect(services.sent).toEqual(expect.arrayContaining([stale, valid]));
      expect(services.sent).toHaveLength(2);
      expect(services.queries).toHaveLength(1);
      expect(services.queries[0]).toMatchObject({
        from: [{ collectionId: "users" }],
        where: { fieldFilter: {
          field: { fieldPath: "fcmTokens" }, op: "ARRAY_CONTAINS", value: { stringValue: stale },
        } },
      });
      expect(services.writes).toEqual(["owner-1", "owner-2"].map((id) => ({
        transform: {
          document: `${documentRoot}/users/${id}`,
          fieldTransforms: [{
            fieldPath: "fcmTokens", removeAllFromArray: { values: [{ stringValue: stale }] },
          }],
        },
        currentDocument: { exists: true },
      })));
      for (const document of services.users.values()) {
        expect(tokensOf(document)).toEqual([valid]);
        expect(document.fields.displayName).toEqual({ stringValue: "Preserved profile" });
      }
      expect(services.events.indexOf("query")).toBeGreaterThan(services.events.lastIndexOf("send"));
      expect(services.unexpected).toEqual([]);
      if (mode !== "outbox") {
        expect(result).toMatchObject({
          successCount: 1, failureCount: 1, unregisteredCount: 1,
          invalidTokens: [stale], retryTokens: [],
        });
      }
      if (mode !== "fallback") {
        expect(finalized).toHaveLength(1);
        expect(finalized[0].values[0]).toBe("sent");
      }
    },
  );

  it.each(["immediate", "fallback", "outbox"] as const)(
    "keeps only temporary failures retryable when cleanup fails in the %s path",
    async (mode) => {
      const services = mockServices({
        documents: [userDocument("owner-1", [stale, valid])],
        outcomes: { [stale]: "unregistered", [temporary]: "temporary" },
        commitFailure: () => 503,
      });
      const { result, finalized } = await deliver(mode, [stale, temporary, valid]);

      expect(services.writes).toHaveLength(1);
      expect(tokensOf(services.users.get(`${documentRoot}/users/owner-1`))).toEqual([stale, valid]);
      expect(services.sent).toHaveLength(3);
      if (mode !== "outbox") {
        expect(result).toMatchObject({
          successCount: 1, failureCount: 2, unknownCount: 0, unregisteredCount: 1,
          invalidTokens: [stale], retryTokens: [temporary],
        });
      }
      if (mode !== "fallback") {
        expect(finalized).toHaveLength(1);
        expect(finalized[0].sql).toContain("status='retry'");
        expect(JSON.parse(finalized[0].values[0])).toEqual([temporary]);
        expect(JSON.parse(finalized[0].values[4])).toMatchObject({
          successCount: 1, failureCount: 2, unknownCount: 0, unregisteredCount: 1,
        });
      }
    },
  );

  it.each([503, "network"] as const)(
    "continues with the next token after a %s owner lookup failure",
    async (failure) => {
      const services = mockServices({
        documents: [userDocument("owner-2", [secondStale, valid])],
        outcomes: { [stale]: "unregistered", [secondStale]: "unregistered" },
        queryFailure: (token) => token === stale ? failure : undefined,
      });
      const { result } = await deliver("immediate", [stale, secondStale]);
      expect(result).toMatchObject({ unregisteredCount: 2, unknownCount: 0, retryTokens: [] });
      expect(services.queries).toHaveLength(2);
      expect(services.writes).toHaveLength(1);
      expect(tokensOf(services.users.get(`${documentRoot}/users/owner-2`))).toEqual([valid]);
    },
  );

  it.each([503, 409, 412, "network"] as const)(
    "continues with other owners after a %s cleanup write failure",
    async (failure) => {
      const services = mockServices({
        documents: [userDocument("owner-1", [stale]), userDocument("owner-2", [stale, valid])],
        commitFailure: (name) => name.endsWith("/owner-1") ? failure : undefined,
      });
      const { finalized } = await deliver("outbox", [stale]);
      expect(services.writes).toHaveLength(2);
      expect(tokensOf(services.users.get(`${documentRoot}/users/owner-1`))).toEqual([stale]);
      expect(tokensOf(services.users.get(`${documentRoot}/users/owner-2`))).toEqual([valid]);
      expect(finalized).toHaveLength(1);
      expect(finalized[0].values[0]).toBe("dead");
      expect(JSON.parse(finalized[0].values[3])).toMatchObject({ unregisteredCount: 1, unknownCount: 0 });
      expect(services.sent).toEqual([stale]);
    },
  );

  it("does not query or remove tokens for success, generic 404, invalid payload, or temporary errors", async () => {
    const outcomes: Record<string, Outcome> = {
      [valid]: "success",
      "generic-not-found-token-1": "not-found",
      "invalid-argument-token-1": "invalid",
      [temporary]: "temporary",
      "network-error-device-token": "network",
    };
    const services = mockServices({ outcomes });
    const { result } = await deliver("immediate", Object.keys(outcomes));
    expect(result).toMatchObject({
      successCount: 1, failureCount: 3, unknownCount: 1, unregisteredCount: 0, invalidTokens: [],
    });
    expect(result.retryTokens.sort()).toEqual([temporary, "network-error-device-token"].sort());
    expect(services.queries).toEqual([]);
    expect(services.writes).toEqual([]);
  });

  it("does not write when no user owns the unregistered token", async () => {
    const services = mockServices({ documents: [userDocument("unrelated", [valid])] });
    const { result } = await deliver("immediate", [stale]);
    expect(result).toMatchObject({ unregisteredCount: 1, retryTokens: [] });
    expect(services.queries).toHaveLength(1);
    expect(services.writes).toEqual([]);
  });

  it("skips query rows without exact array membership or valid user metadata", async () => {
    const base = userDocument("owner-1", [stale]);
    const services = mockServices({ queryRows: [
      { readTime: base.updateTime },
      { document: userDocument("unrelated", [valid]) },
      { document: { ...base, fields: { fcmTokens: { stringValue: stale } } } },
      { document: { ...base, fields: {} } },
      { document: { ...base, name: `${documentRoot}/items/owner-1` } },
      { document: { ...base, name: `${documentRoot}/users/owner-1/nested/child` } },
      { document: { ...base, name: `${documentRoot}/users/` } },
      { document: { ...base, name: base.name.replace("push-cleanup-test", "another-project") } },
      { document: { ...base, name: undefined } },
      { document: { ...base, updateTime: undefined } },
    ] });
    await deliver("immediate", [stale]);
    expect(services.queries).toHaveLength(1);
    expect(services.writes).toEqual([]);
  });

  it("removes only the stale token when an owner changed after lookup", async () => {
    const snapshot = userDocument("owner-1", [stale, valid]);
    const current = {
      ...userDocument("owner-1", [stale, valid]),
      updateTime: "2026-09-29T10:00:02Z",
    };

    const services = mockServices({
      documents: [current],
      queryRows: [{ document: snapshot }],
    });

    const { result } = await deliver("immediate", [stale]);

    expect(services.writes[0].currentDocument).toEqual({ exists: true });

    const stored = services.users.get(current.name);
    expect(tokensOf(stored)).toEqual([valid]);
    expect(stored.fields.displayName).toEqual(current.fields.displayName);

    expect(result).toMatchObject({
      unregisteredCount: 1,
      unknownCount: 0,
      retryTokens: [],
    });
  });

  it("does not recreate an owner deleted after lookup", async () => {
    const services = mockServices({ queryRows: [{ document: userDocument("deleted-owner", [stale]) }] });
    const { result } = await deliver("immediate", [stale]);
    expect(services.writes).toHaveLength(1);
    expect(services.users.size).toBe(0);
    expect(result).toMatchObject({ unregisteredCount: 1, unknownCount: 0, retryTokens: [] });
  });
});
