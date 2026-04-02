import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/theme/cookbook_theme.dart';
import 'core/widgets/paper_texture.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(CookbookTheme.edgeToEdgeLight);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const ProviderScope(child: MiseEnPicApp()));
}

class MiseEnPicApp extends StatelessWidget {
  const MiseEnPicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mise en Pic',
      debugShowCheckedModeBanner: false,
      theme: CookbookTheme.light(),
      darkTheme: CookbookTheme.dark(),
      routerConfig: appRouter,
      builder: (context, child) {
        return PaperTextureBackground(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
