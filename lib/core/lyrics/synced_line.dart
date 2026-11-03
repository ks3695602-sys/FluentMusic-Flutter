class SyncedWord {
  final String text;
  final Duration time;

  const SyncedWord({required this.text, required this.time});
}

class SyncedLine {
  final Duration time;
  final String text;
  final List<SyncedWord> words;

  const SyncedLine({
    required this.time,
    required this.text,
    this.words = const [],
  });
}
