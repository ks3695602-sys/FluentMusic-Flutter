import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:musify/mornye_player/utils/lyrics_parser.dart';

/// What the lyrics views rebuild on when a translation arrives.
class LyricsTranslationState {
  const LyricsTranslationState({this.results = const {}});

  /// Translations read or made this session, by cache key.
  final Map<String, Object?> results;
}

/// FluentMusic shows the lyrics a provider returned, including any translation
/// the provider itself supplied. There is no AI translation job here, so the
/// state stays empty and [shown] hands the lyrics straight back.
final lyricsTranslationProvider =
    NotifierProvider<LyricsTranslationController, LyricsTranslationState>(
      LyricsTranslationController.new,
    );

class LyricsTranslationController extends Notifier<LyricsTranslationState> {
  @override
  LyricsTranslationState build() => const LyricsTranslationState();

  ParsedLyrics shown(ParsedLyrics lyrics) => lyrics;
}