import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_guard/screens/auth/login_screen.dart';
import 'package:pocket_guard/screens/auth/signup_screen.dart';
import 'package:pocket_guard/screens/auth/phone_auth_screen.dart';
import 'package:pocket_guard/screens/onboarding_screen.dart';
import 'package:pocket_guard/screens/home_screen.dart';
import 'package:pocket_guard/services/user_service.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final user = FirebaseAuth.instance.currentUser;
      final path = state.uri.path;
      final isAuthRoute = path == '/' || path == '/signup' || path == '/phone-auth';
      final isOnboardingRoute = path == '/onboarding';

      debugPrint('Router redirect: path=$path user=${user?.uid}');

      if (user == null) {
        if (!isAuthRoute) return '/';
        return null;
      }

      final userDoc = await UserService().getUser(user.uid);
      final isOnboarded = userDoc != null && (userDoc.personalSalary > 0 || userDoc.businessIncome > 0) && userDoc.salaryDate > 0;
      if (kDebugMode) {
        debugPrint('Router redirect: fetched userDoc=${userDoc != null} salary=${userDoc?.monthlySalary} salaryDate=${userDoc?.salaryDate} isOnboarded=$isOnboarded');
      }

      if (!isOnboarded && !isOnboardingRoute) return '/onboarding';
      if (isOnboarded && (isAuthRoute || isOnboardingRoute)) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(child: const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => NoTransitionPage(child: const SignUpScreen()),
      ),
      GoRoute(
        path: '/phone-auth',
        name: 'phone-auth',
        pageBuilder: (context, state) => NoTransitionPage(child: const PhoneAuthScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => NoTransitionPage(child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => NoTransitionPage(child: const HomeScreen()),
      ),
    ],
  );
}

class AppRoutes {
  static const String login = '/';
  static const String signup = '/signup';
  static const String phoneAuth = '/phone-auth';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
}
