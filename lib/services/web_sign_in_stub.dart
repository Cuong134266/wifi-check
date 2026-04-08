import 'package:flutter/material.dart';

/// Stub for non-web platforms — renderButton throws since it's web-only.
Widget renderButton() {
  throw StateError('renderButton should only be called on web');
}
