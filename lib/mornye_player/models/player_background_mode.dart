/// How the full player paints the screen behind its controls.
///
/// [cinematic] is the cover-derived drifting gradient the player shipped with.
/// [albumArt] uses the cover itself at full resolution, and
/// [blurredAlbumArt] uses that same cover under a heavy, static blur. Both
/// artwork modes add a dark scrim so the white labels stay readable.
enum PlayerBackgroundMode {
  cinematic('cinematic'),
  albumArt('album_art'),
  blurredAlbumArt('blurred_album_art');

  const PlayerBackgroundMode(this.storageValue);

  /// Stable value written to Hive; the enum name is not used so a rename
  /// cannot silently reset everyone's preference.
  final String storageValue;

  /// Parses a stored value. Unknown values return null so the caller can fall
  /// back to the legacy boolean.
  static PlayerBackgroundMode? fromStorage(Object? value) {
    if (value is! String) return null;
    for (final mode in PlayerBackgroundMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return null;
  }

  /// The mode an old `playerMeshBackgroundEnabled` preference maps to.
  ///
  /// Turning the mesh off used to leave the player on its blurred cover, so
  /// that is exactly where those users land now.
  static PlayerBackgroundMode fromLegacyMesh(bool? meshEnabled) =>
      meshEnabled == false
      ? PlayerBackgroundMode.blurredAlbumArt
      : PlayerBackgroundMode.cinematic;
}
