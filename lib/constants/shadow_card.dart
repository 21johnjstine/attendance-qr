import 'package:flutter/material.dart';

class ShadowCard {
  ShadowCard._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color.fromRGBO(60, 64, 67, 0.3),
      blurRadius: 2,
      spreadRadius: 0,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color.fromRGBO(60, 64, 67, 0.15),
      blurRadius: 3,
      spreadRadius: 1,
      offset: Offset(0, 1),
    ),
  ];
}
