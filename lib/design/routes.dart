import 'package:flutter/material.dart';

/// A vertical, glass-friendly page transition used for editors and sheets.
Future<T?> openGlassPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => page),
  );
}
