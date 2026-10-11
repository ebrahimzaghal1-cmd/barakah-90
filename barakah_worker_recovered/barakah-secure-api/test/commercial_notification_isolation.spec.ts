import {
  describe,
  expect,
  it
} from "vitest";

import source from "../src/index.js?raw";

function functionBlock(
  name: string,
  nextMarker: string
) {
  const start =
    source.indexOf(
      `async function ${name}(`
    );

  const end =
    source.indexOf(
      nextMarker,
      start
    );

  expect(start).toBeGreaterThanOrEqual(0);
  expect(end).toBeGreaterThan(start);

  return source.slice(
    start,
    end
  );
}

describe(
  "commercial notification isolation",
  () => {
    it(
      "records pickup ready actor safely",
      () => {
        const block =
          functionBlock(
            "publishOrderToDrivers",
            '__name(publishOrderToDrivers'
          );

        expect(block)
          .toContain(
            "readyBy: actorId"
          );

        expect(block)
          .not.toContain(
            "readyBy: user.uid"
          );
      }
    );

    it(
      "does not fail driver availability after notification failure",
      () => {
        const block =
          functionBlock(
            "setDriverAvailability",
            '__name(setDriverAvailability'
          );

        expect(block)
          .toContain(
            "waiting_driver_notification_failed"
          );

        expect(block)
          .toContain(
            "try {"
          );
      }
    );

    it(
      "commits support message before notification token lookups",
      () => {
        const block =
          functionBlock(
            "sendSupportMessage",
            '__name(sendSupportMessage'
          );

        const commit =
          block.indexOf(
            "await firestoreCommit"
          );

        const notificationSection =
          block.indexOf(
            "Everything below is notification-only"
          );

        const userTokens =
          block.indexOf(
            "await userPushTokens",
            notificationSection
          );

        expect(commit)
          .toBeGreaterThanOrEqual(0);

        expect(notificationSection)
          .toBeGreaterThan(commit);

        expect(userTokens)
          .toBeGreaterThan(
            notificationSection
          );

        expect(
          block.slice(
            0,
            commit
          )
        ).not.toContain(
          "userPushTokens("
        );

        expect(
          block.slice(
            0,
            commit
          )
        ).not.toContain(
          "adminPushTokens("
        );
      }
    );

    it(
      "isolates welcome notification after commit",
      () => {
        const block =
          functionBlock(
            "sendSupportMessage",
            '__name(sendSupportMessage'
          );

        expect(block)
          .toContain(
            "support_welcome_notification_failed"
          );

        expect(block)
          .toContain(
            "messageId: welcomeMessageId"
          );
      }
    );
  }
);
