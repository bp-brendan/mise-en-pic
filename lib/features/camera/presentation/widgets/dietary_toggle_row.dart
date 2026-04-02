import 'package:flutter/material.dart';

import '../../../../core/theme/cookbook_theme.dart';
import '../../domain/models/dietary_modifier.dart';

/// A horizontal row of segmented toggles for selecting a dietary modifier.
///
/// Uses the theme's SegmentedButton styling (Neubrutalist border + accent fill).
class DietaryToggleRow extends StatelessWidget {
  const DietaryToggleRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DietaryModifier selected;
  final ValueChanged<DietaryModifier> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DietaryModifier>(
      segments: DietaryModifier.values.map((modifier) {
        return ButtonSegment<DietaryModifier>(
          value: modifier,
          label: Text(
            modifier.label,
            style: CookbookTheme.labelStyle(fontSize: 11),
          ),
        );
      }).toList(),
      selected: {selected},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
      showSelectedIcon: false,
    );
  }
}
