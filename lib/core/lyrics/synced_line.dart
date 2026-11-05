class SyncedWord {
  final String text;
  final Duration time;
  final Duration duration;

  const SyncedWord({
    required this.text,
    required this.time,
    this.duration = const Duration(milliseconds: 350),
  });

  Duration get endTime => time + duration;

  bool isCurrent(Duration position) {
    return position >= time && position <= endTime;
  }

  bool isPast(Duration position) {
    return position > endTime;
  }
}

class SyncedLine {
  final Duration time;
  final String text;
  final List<SyncedWord> words;
  final Duration duration;

  const SyncedLine({
    required this.time,
    required this.text,
    this.words = const [],
    this.duration = const Duration(seconds: 4),
  });

  Duration get endTime => time + duration;

  bool isCurrent(Duration position) {
    return position >= time && (duration == Duration.zero || position <= endTime);
  }
}
