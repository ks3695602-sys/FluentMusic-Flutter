/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

/// Visual presentation of the Now Playing screen.
///
/// Kept as a pure Dart enum (no Flutter imports) so the persisted value and
/// its migration fallback can be unit tested without a widget tree.
enum PlayerStyle {
  /// Full-bleed artwork with the blurred bed and liquid glass chrome.
  immersive(
    storageValue: 'immersive',
    label: 'Immersive',
    description: 'Full-bleed artwork with liquid glass controls',
  ),

  /// Near-black stage with a soft accent glow, no artwork backdrop.
  midnight(
    storageValue: 'midnight',
    label: 'Midnight',
    description: 'True-black stage with a soft accent glow',
  ),

  /// Artwork presented as the label of a vinyl record.
  vinyl(
    storageValue: 'vinyl',
    label: 'Vinyl',
    description: 'Artwork centred on a record-stage turntable',
  );

  const PlayerStyle({
    required this.storageValue,
    required this.label,
    required this.description,
  });

  /// Stable value written to Hive. Never reuse a retired value.
  final String storageValue;

  /// Short name shown in settings and the chooser sheet.
  final String label;

  /// One-line explanation shown under [label].
  final String description;

  /// Resolves a stored value, falling back to [immersive] for missing or
  /// unknown values (including installs that predate player styles).
  static PlayerStyle fromStorage(Object? value) {
    final raw = value?.toString();
    for (final style in PlayerStyle.values) {
      if (style.storageValue == raw) return style;
    }
    return PlayerStyle.immersive;
  }
}
