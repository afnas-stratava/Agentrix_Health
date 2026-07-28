import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x242D2B2B), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x292D2B2B), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x382D2B2B), blurRadius: 32, offset: Offset(0, 12)),
  ];
}
