import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_shell.dart';
import 'firebase_options.dart';

import 'providers/auth_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options (fixes web white screen).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firestore for unlimited offline cache size.
  // (system-design.md §3: "configured to unlimited size on app initialization,
  // so a full catalog of products, customers, and recent transaction history
  // stays available locally regardless of how long the phone stays offline.")
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Wire Crashlytics to catch all Flutter framework errors (non-web only).
  // (roadmap.md: "Wired in from the first Phase 1 build, not deferred —
  // cheap to add early, valuable immediately.")
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(
    const ProviderScope(
      child: PapaDeskApp(),
    ),
  );
}

/// Root application widget.
class PapaDeskApp extends ConsumerWidget {
  const PapaDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PapaDesk',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB76E79),
          primary: const Color(0xFFB76E79), // Rose Gold
          secondary: const Color(0xFF4A4A5A), // Platinum Charcoal
          surface: const Color(0xFFFFFFFF),
          error: const Color(0xFFD32F2F),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF9FA),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF2EFF2), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFFFAF9FA),
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Color(0xFF1F1D20)),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F1D20),
            letterSpacing: -0.5,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18, color: Color(0xFF1F1D20), letterSpacing: -0.2),
          bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF6E6870), letterSpacing: -0.1),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F1D20), letterSpacing: -0.5),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF2EFF2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF2EFF2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB76E79), width: 1.5),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE0A899),
          brightness: Brightness.dark,
          primary: const Color(0xFFE0A899), // Metallic Rose Gold
          secondary: const Color(0xFFD0CDE1), // Platinum Silver
          surface: const Color(0xFF17181D), // Obsidian Slate
          error: const Color(0xFFE57373),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E0F12), // Deep Obsidian Charcoal
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF17181D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF262833), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF0C0E17),
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Color(0xFFE2E6F0)),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE2E6F0),
            letterSpacing: -0.5,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18, color: Color(0xFFE2E6F0), letterSpacing: -0.2),
          bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFA0A7B5), letterSpacing: -0.1),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE2E6F0), letterSpacing: -0.5),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151824),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF20253B)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF20253B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4D7CFF), width: 1.5),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}


