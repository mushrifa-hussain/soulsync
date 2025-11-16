import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/splash_screen.dart';
import 'screens/theme_selection_page.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ai_chat_page.dart';
import 'providers/diary_entries_provider.dart';
import 'providers/ai_chat_provider.dart';
import 'services/notification_service.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔥 [FLUTTER ERROR] ${details.exception}');
    debugPrint('🔥 [FLUTTER ERROR] Stack: ${details.stack}');
    FlutterError.presentError(details);
  };

  // Handle async errors
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔥 [ASYNC ERROR] $error');
    debugPrint('🔥 [ASYNC ERROR] Stack: $stack');
    return false; // Let errors propagate normally
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('🔥 [MAIN] Firebase initialized successfully');

  // Initialize Hive for local storage
  await LocalStorageService.initialize();
  debugPrint('🔥 [MAIN] Local storage initialized successfully');

  tz_data.initializeTimeZones();
  
  // After initializeTimeZones(), tz.local should automatically use the system's local timezone
  // Verify and log the timezone being used
  try {
    final local = tz.local;
    final now = DateTime.now();
    debugPrint('🔥 [MAIN] Timezone initialized');
    debugPrint('🔥 [MAIN] Local timezone: ${local.name}');
    debugPrint('🔥 [MAIN] System timezone offset: ${now.timeZoneOffset}');
    debugPrint('🔥 [MAIN] Current time (local): ${tz.TZDateTime.now(local)}');
  } catch (e) {
    debugPrint('🔥 [MAIN ERROR] Timezone initialization error: $e');
    // Continue - tz.local should still work
  }

  final notificationService = NotificationService();
  await notificationService.initialize();
  
  runApp(const SoulSyncApp());
}

class SoulSyncApp extends StatelessWidget {
  const SoulSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = DiaryEntriesProvider();
            // Load entries asynchronously after build completes (non-blocking)
            // Use Future.microtask to ensure it runs after the current build cycle
            Future.microtask(() {
              // Add a small delay to ensure build is completely finished
              Future.delayed(const Duration(milliseconds: 100), () {
                provider.loadEntries().catchError((e) {
                  debugPrint('🔥 [MAIN] Error loading entries on startup: $e');
                });
              });
            });
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => AIChatProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'SoulSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B4C93),
            brightness: Brightness.light,
      ),
          textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData.light().textTheme,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
        ),
      ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/auth': (context) => const AuthScreen(),
          '/home': (context) => const HomeScreen(),
          '/theme-selection': (context) => const ThemeSelectionPage(),
          '/ai-chat': (context) => const AIChatPage(),
        },
        builder: (context, child) {
          return child!;
        },
      ),
    );
  }
}
