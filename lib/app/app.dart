/// Pocket Claw root application widget
library;

import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class PocketClawApp extends StatelessWidget {
  const PocketClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pocket Claw',
      debugShowCheckedModeBanner: false,
      theme: PocketClawTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
