import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/blocked_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/legal/privacy_policy_screen.dart';
import 'screens/legal/terms_conditions_screen.dart';
import 'components/verification_prompt_wrapper.dart';
import 'components/game_invite_wrapper.dart';

import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.background,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const DeluluApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DeluluApp extends StatelessWidget {
  const DeluluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Delulu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
      ),
      builder: (context, child) {
        return GameInviteGlobalWrapper(
          child: VerificationPromptWrapper(child: child!),
        );
      },
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignupScreen());
          case '/onboarding':
            final initialName = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (_) => OnboardingScreen(initialName: initialName),
            );
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/blocked':
            return MaterialPageRoute(builder: (_) => const BlockedScreen());
          case '/privacy-policy':
            return MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen());
          case '/terms-and-conditions':
            return MaterialPageRoute(builder: (_) => const TermsConditionsScreen());
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Route not found')),
              ),
            );
        }
      },
    );
  }
}