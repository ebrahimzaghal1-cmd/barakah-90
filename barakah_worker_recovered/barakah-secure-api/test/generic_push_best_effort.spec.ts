import { describe, expect, it } from "vitest";
import source from "../src/index.js?raw";

function functionBlock(name: string) {
  const startMarker =
    `async function ${name}(`;

  const endMarker =
    `__name(${name}, "${name}");`;

  const start =
    source.indexOf(startMarker);

  const end =
    source.indexOf(
      endMarker,
      start
    );

  expect(start)
    .toBeGreaterThanOrEqual(0);

  expect(end)
    .toBeGreaterThan(start);

  return source.slice(
    start,
    end + endMarker.length
  );
}

describe(
  "generic push commercial safety",
  () => {
    it(
      "keeps raw FCM sending inside the durable layer only",
      () => {
        const rawCalls =
          source.match(
            /await sendPushToTokens\(/g
          ) ?? [];

        expect(rawCalls)
          .toHaveLength(3);
      }
    );

    it(
      "persists before immediate FCM delivery",
      () => {
        const wrapper =
          functionBlock(
            "sendPushBestEffort"
          );

        const enqueue =
          wrapper.indexOf(
            "await enqueueNotificationOutbox("
          );

        const send =
          wrapper.indexOf(
            "await sendPushToTokens("
          );

        expect(enqueue)
          .toBeGreaterThanOrEqual(0);

        expect(send)
          .toBeGreaterThan(enqueue);
      }
    );

    it(
      "does not retry FCM during finalize failure",
      () => {
        const wrapper =
          functionBlock(
            "sendPushBestEffort"
          );

        expect(wrapper)
          .toContain(
            "notification_outbox_finalize_failed"
          );
      }
    );

    it(
      "keeps support messages durable",
      () => {
        const block =
          functionBlock(
            "sendSupportMessage"
          );

        expect(block)
          .toContain(
            "await firestoreCommit"
          );

        expect(block)
          .toContain(
            "await sendPushBestEffort("
          );

        expect(block)
          .toContain(
            "messageId,"
          );
      }
    );

    it(
      "does not push for taxi GPS updates",
      () => {
        expect(source)
          .toContain(
            'if (action !== "update_location")'
          );
      }
    );
  }
);
