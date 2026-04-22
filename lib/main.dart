import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/brand_header.dart';
import 'theme/app_colors.dart';
import 'widgets/bottom_nav_bar.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/requests_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DeluluApp());
}

class DeluluApp extends StatelessWidget {
  const DeluluApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delulu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.white),
          bodyMedium: TextStyle(color: AppColors.white),
        ),
      ),
      home: const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: AppFlowController(),
      ),
    );
  }
}

class AppFlowController extends StatefulWidget {
  const AppFlowController({super.key});

  @override
  State<AppFlowController> createState() => _AppFlowControllerState();
}

class _AppFlowControllerState extends State<AppFlowController> {
  AppFlow _flow = AppFlow.splash;
  NavTab _currentTab = NavTab.discovery;

  @override
  Widget build(BuildContext context) {
    switch (_flow) {
      case AppFlow.splash:
        return SplashScreen(
          onComplete: () => setState(() => _flow = AppFlow.onboarding),
        );
      case AppFlow.onboarding:
        return OnboardingScreen(
          onComplete: () => setState(() => _flow = AppFlow.main),
        );
      case AppFlow.main:
        return _buildMainApp();
    }
  }

  Widget _buildMainApp() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrandHeader(),
            Expanded(
              child: IndexedStack(
                index: _currentTab.index,
                children: const [
                  DiscoveryScreen(),
                  RequestsScreen(),
                  ChatScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedTab: _currentTab,
        onTabChanged: (tab) => setState(() => _currentTab = tab),
      ),
    );
  }
}

enum AppFlow { splash, onboarding, main }