import 'package:flutter/material.dart';

import 'sheets.dart';

/// Standalone route for API configuration.
///
/// The actual editor lives in [ConnectSheetScreen], so the settings entry and
/// the dedicated route always edit the same local configuration.
class ConnectionPage extends StatelessWidget {
  const ConnectionPage({super.key});

  @override
  Widget build(BuildContext context) => const ConnectSheetScreen();
}
