import 'package:flutter_test/flutter_test.dart';

import 'package:barakah90/services/push_token_registration.dart';

void main() {
  test('re-registering an old device includes it in the last four targets', () {
    final tokens = List.generate(206, (index) => 'device-$index');
    final updated = tokensAfterRegistration(tokens, token: 'device-0');

    expect(updated, hasLength(206));
    expect(updated.toSet(), tokens.toSet());
    expect(updated.skip(updated.length - 4), contains('device-0'));
    expect(updated.last, 'device-0');
  });

  test('refresh replaces only the previous token of this session', () {
    final updated = tokensAfterRegistration(
      ['other-device', 'old-device', 'third-device'],
      token: 'new-device',
      previousToken: 'old-device',
    );
    expect(updated, ['other-device', 'third-device', 'new-device']);
  });

  test('repeated registration is stable without duplicate tokens', () {
    final first = tokensAfterRegistration(['a', 'b', 'a'], token: ' a ');
    expect(first, ['b', 'a']);
    expect(tokensAfterRegistration(first, token: 'a'), first);
  });

  test('empty tokens do not remove existing registrations', () {
    expect(
      tokensAfterRegistration(['a', 'b'], token: ' ', previousToken: 'a'),
      ['a', 'b'],
    );
  });
}
