import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  await NotificationService.init();
  await FirebaseMessaging.instance.requestPermission();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp.router(
        title: 'Delulu',
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFFECB2FF),
          scaffoldBackgroundColor: const Color(0xFF111318),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFECB2FF),
            secondary: Color(0xFF00EEFC),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E002E),
            elevation: 0,
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}

// Simple routing using GoRouter
final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/profile-completion',
      name: 'profileCompletion',
      builder: (context, state) => const ProfileCompletionScreen(),
    ),
    GoRoute(
      path: '/face-verification',
      name: 'faceVerification',
      builder: (context, state) => const FaceVerificationScreen(),
    ),
    GoRoute(
      path: '/discovery',
      name: 'discovery',
      builder: (context, state) => const DiscoveryScreen(),
    ),
    GoRoute(
      path: '/profile-details/:userId',
      name: 'profileDetails',
      builder: (context, state) => ProfileDetailsScreen(
        userId: state.pathParameters['userId']!,
      ),
    ),
    GoRoute(
      path: '/requests',
      name: 'requests',
      builder: (context, state) => const RequestsScreen(),
    ),
    GoRoute(
      path: '/chat-list',
      name: 'chatList',
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/chat/:roomId/:peerId',
      name: 'chat',
      builder: (context, state) => ChatScreen(
        roomId: state.pathParameters['roomId']!,
        peerId: state.pathParameters['peerId']!,
      ),
    ),
    GoRoute(
      path: '/call/:channelName/:peerId',
      name: 'call',
      builder: (context, state) => CallScreen(
        channelName: state.pathParameters['channelName']!,
        peerId: state.pathParameters['peerId']!,
      ),
    ),
    GoRoute(
      path: '/profile-settings',
      name: 'profileSettings',
      builder: (context, state) => const ProfileSettingsScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      name: 'editProfile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/premium',
      name: 'premium',
      builder: (context, state) => const PremiumScreen(),
    ),
  ],
);