import {
  describe,
  expect,
  it,
} from "vitest";

import {
  isRetryableFcmStatus,
} from "../src/index.js";

import source
  from "../src/index.js?raw";

describe(
  "notification outbox durability",
  () => {
    it(
      "retries temporary FCM failures",
      () => {
        expect(
          isRetryableFcmStatus(401)
        ).toBe(true);

        expect(
          isRetryableFcmStatus(408)
        ).toBe(true);

        expect(
          isRetryableFcmStatus(429)
        ).toBe(true);

        expect(
          isRetryableFcmStatus(500)
        ).toBe(true);

        expect(
          isRetryableFcmStatus(503)
        ).toBe(true);
      }
    );

    it(
      "does not retry permanent FCM failures",
      () => {
        expect(
          isRetryableFcmStatus(400)
        ).toBe(false);

        expect(
          isRetryableFcmStatus(403)
        ).toBe(false);

        expect(
          isRetryableFcmStatus(404)
        ).toBe(false);
      }
    );

    it(
      "has scheduled retry processing",
      () => {
        expect(source)
          .toContain(
            "async scheduled(controller, env, ctx)"
          );

        expect(source)
          .toContain(
            "processNotificationOutbox(env)"
          );

        expect(source)
          .toContain(
            "NOTIFICATION_OUTBOX_MAX_ATTEMPTS = 7"
          );
      }
    );

    it(
      "bounds every retry invocation",
      () => {
        expect(source)
          .toContain(
            "GENERIC_PUSH_IMMEDIATE_LIMIT = 8"
          );

        expect(source)
          .toContain(
            "NOTIFICATION_OUTBOX_TOKEN_CHUNK = 8"
          );

        expect(source)
          .toContain(
            "NOTIFICATION_OUTBOX_BATCH_SIZE = 4"
          );
      }
    );

    it(
      "deduplicates by event and recipients",
      () => {
        expect(source)
          .toContain(
            "dedupe_key"
          );

        expect(source)
          .toContain(
            "recipients"
          );

        expect(source)
          .toContain(
            "INSERT OR IGNORE INTO notification_outbox"
          );
      }
    );
  }
);
