import 'package:flutter/material.dart';

import 'creator_live_screen.dart' deferred as creator;

/// Opens creator live broadcast. Deferred so Agora is not loaded at app/tab startup.
Future<void> openCreatorLiveScreen(BuildContext context) async {
  await creator.loadLibrary();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => creator.CreatorLiveScreen(),
    ),
  );
}
