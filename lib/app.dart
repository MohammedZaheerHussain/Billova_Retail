import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/app_shell.dart';

class SkywalkApp extends StatelessWidget {
  const SkywalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const AppShell(),
          },
        );
      },
    );
  }
}
