import 'package:flutter/widgets.dart';

/// Material Symbols counterpart of a legacy Material icon.
///
/// FluentMusic keeps its own icon theme, so the copied Mornye widgets fall
/// back to the plain Material glyphs they were written with.
typedef MaterialSymbol = ({IconData icon, bool filled});

/// Always null: FluentMusic draws the legacy [Icons] glyphs themselves rather
/// than bundling the multi-hundred-megabyte Material Symbols font set.
MaterialSymbol? materialSymbolFor(IconData? icon) => null;