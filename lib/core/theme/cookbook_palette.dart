import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Color tokens for Mise en Pic — derived from the suite's Vellum palette.
///
/// Light-mode leans into the warm, editorial paper feel (Loom lineage).
/// Dark-mode reuses the shared dark-card / OLED substrate from Mute.
class CookbookPalette {
  CookbookPalette._();

  // ── Shared light angle across the product suite ─────────────────
  static const double sharedLightAngle = -math.pi / 4.6;

  // ── Light Mode ──────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFE8EFE6);
  static const Color lightCard = Color(0xFFF7F5EF);
  static const Color lightInk = Color(0xFF1D1C19);
  static const Color lightAccent = Color(0xFF5A6A4A); // acid green
  static const Color lightStroke = Color(0xFFCBC7BC);

  // ── Dark Mode ───────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF17120E);
  static const Color darkCard = Color(0xFF221F1A);
  static const Color darkInk = Color(0xFFF3E8D5);
  static const Color darkAccent = Color(0xFF5A6A4A);
  static const Color darkStroke = Color(0xFF4D473C);

  // ── Semantic ────────────────────────────────────────────────────
  static const Color error = Color(0xFFC4362C);
  static const Color success = Color(0xFF4CAF6A);

  // ── Letterpress shadow system ───────────────────────────────────
  static const Color debossHighlight = Color(0xAAFFFFFF);
  static const Color debossShadow = Color(0xFF090909);
}
