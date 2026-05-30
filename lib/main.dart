import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const AcadiCronApp(),
    ),
  );
}

class AcadiCronApp extends StatelessWidget {
  const AcadiCronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcadiCron',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          return auth.isLoggedIn
              ? const DashboardScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
