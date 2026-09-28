import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'models/farm_site.dart';
import 'screens/home_screen.dart';
import 'services/site_repository.dart';
import 'state/farm_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final repo = SiteRepository();
  final controller = FarmController(repo);
  await controller.init();

  runApp(SmartFarmApp(controller: controller));
}

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key, required this.controller});

  final FarmController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<FarmController>(
        builder: (context, ctrl, _) {
          final bg = Color(
            ctrl.activeSite?.bgColor ?? FarmSite.kDefaultSiteBgColor,
          );
          return MaterialApp(
            title: '스마트팜',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ko'),
            supportedLocales: const [Locale('ko'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorSchemeSeed: const Color(0xFF38BDF8),
              scaffoldBackgroundColor: bg,
              cardTheme: CardThemeData(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
