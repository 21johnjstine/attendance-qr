import 'package:flutter/material.dart';
import 'package:simpleattendancechecker/constants/app_sizing.dart';
import 'package:simpleattendancechecker/constants/color_palatte.dart';
import 'package:simpleattendancechecker/constants/shadow_card.dart';

class SearchbarCard extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String hintText;
  final double iconSize;
  final Color iconColor;
  final bool showPadShad;
  const SearchbarCard({
    super.key,
    required this.onChanged,
    this.controller,
    this.hintText = 'Search by Name or Student ID',
    this.iconSize = 20,
    this.iconColor = Colorpalatte.infocolor,
    this.showPadShad = true,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search, size: iconSize, color: iconColor),
        filled: true,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        fillColor: Colorpalatte.containercolor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );

    if (!showPadShad) return field;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: ShadowCard.card,
        ),
        child: field,
      ),
    );
  }
}
