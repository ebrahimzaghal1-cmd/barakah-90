/// Keep the registering device last so the server's recent-device limit
/// includes it, even when Firebase returns an already stored token.
List<String> tokensAfterRegistration(
  Iterable<String> existingTokens, {
  required String token,
  String? previousToken,
}) {
  final current = token.trim();
  if (current.isEmpty) return existingTokens.toList();

  return [
    ...existingTokens.where(
      (value) => value != current && value != previousToken,
    ).toSet(),
    current,
  ];
}
