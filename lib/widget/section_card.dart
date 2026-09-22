import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';

class SectionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SectionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colorpalatte.secondary,
        backgroundColor: Colorpalatte.containercolor,
        labelStyle: TextStyle(
          color: selected ? Colorpalatte.maincolor : Colorpalatte.secondary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide.none,
        ),
      ),
    );
  }
}
