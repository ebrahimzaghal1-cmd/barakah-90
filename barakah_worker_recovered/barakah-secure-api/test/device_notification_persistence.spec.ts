import { describe, expect, it } from 'vitest';
import { selectRecentPushTokens } from '../src/index.js';

describe('registered device eligibility', () => {
  const devices = Array.from({length: 12}, (_, i) => `registered-device-${i}-${'x'.repeat(30)}`);
  it('keeps a previously registered device eligible after many other devices register', () => {
    expect(selectRecentPushTokens(devices)).toContain(devices[0]);
    expect(selectRecentPushTokens(devices)).toHaveLength(12);
  });
  it('never applies the old single-device delivery cap', () => {
    expect(selectRecentPushTokens(devices, 1)).toHaveLength(12);
  });
  it('filters invalid values and duplicate registrations', () => {
    expect(selectRecentPushTokens([...devices, devices[0], null, '', 'short'])).toHaveLength(12);
  });
  it('handles profiles without tokens', () => {
    expect(selectRecentPushTokens(undefined)).toEqual([]);
  });
});
