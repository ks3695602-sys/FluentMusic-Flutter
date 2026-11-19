/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     FluentMusic is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/// Normalises a provider-supplied artist string for display.
///
/// Providers frequently hand back the same name twice ("A, A"), mix `feat.`
/// with commas, or join collaborators with `&` / `x` / `+`. This collapses the
/// duplicates case-insensitively and joins the survivors with an Oxford-style
/// list: `A`, `A & B`, `A, B & C`.
String formatArtistNames(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  var value = trimmed.replaceAll(
    RegExp(r'\s+(?:feat\.?|ft\.?|featuring|with)\s+', caseSensitive: false),
    ', ',
  );
  value = value.replaceAll(RegExp(r'\s+[xX+]\s+'), ', ');

  final seen = <String>{};
  final parts = <String>[];
  for (final part in value.split(RegExp(r'\s*[,&;]\s*'))) {
    final name = part.trim();
    if (name.isEmpty) continue;
    if (seen.add(name.toLowerCase())) parts.add(name);
  }

  if (parts.isEmpty) return trimmed;
  if (parts.length == 1) return parts.first;
  if (parts.length == 2) return '${parts[0]} & ${parts[1]}';
  return '${parts.sublist(0, parts.length - 1).join(', ')} & ${parts.last}';
}
