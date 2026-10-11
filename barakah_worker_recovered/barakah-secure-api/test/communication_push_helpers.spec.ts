import { describe, expect, it } from "vitest";

import {
  isUnregisteredFcmError,
  selectCampaignPushTokens,
} from "../src/index.js";

describe("communication campaign push safety", () => {
  it("keeps only the four newest unique usable tokens", () => {
    const tokens = [
      "A".repeat(25),
      "B".repeat(25),
      "C".repeat(25),
      "D".repeat(25),
      "E".repeat(25),
      "E".repeat(25),
    ];

    expect(selectCampaignPushTokens(tokens)).toEqual([
      "B".repeat(25),
      "C".repeat(25),
      "D".repeat(25),
      "E".repeat(25),
    ]);
  });

  it("recognizes explicit FCM UNREGISTERED", () => {
    const body = JSON.stringify({
      error: {
        status: "NOT_FOUND",
        details: [
          {
            "@type":
              "type.googleapis.com/google.firebase.fcm.v1.FcmError",
            errorCode: "UNREGISTERED",
          },
        ],
      },
    });

    expect(isUnregisteredFcmError(body)).toBe(true);
  });

  it("does not classify a generic FCM failure as unregistered", () => {
    const body = JSON.stringify({
      error: {
        status: "INTERNAL",
        message: "temporary failure",
      },
    });

    expect(isUnregisteredFcmError(body)).toBe(false);
  });
});
