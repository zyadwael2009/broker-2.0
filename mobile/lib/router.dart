import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/presentation/broker_detail_screen.dart';
import 'features/admin/presentation/queue_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_phone_screen.dart';
import 'features/broker/presentation/verification_screen.dart';
import 'features/listings/presentation/browse_listings_screen.dart';
import 'features/listings/presentation/create_listing_screen.dart';
import 'features/listings/presentation/listing_detail_screen.dart';
import 'features/listings/presentation/my_listings_screen.dart';
import 'features/market/presentation/price_transparency_screen.dart';
import 'features/messaging/data/models.dart';
import 'features/messaging/presentation/thread_screen.dart';
import 'features/messaging/presentation/threads_list_screen.dart';
import 'features/ratings/presentation/broker_profile_screen.dart';

/// Route names kept as constants so we never mistype them.
class Routes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyPhone = '/verify-phone';
  static const home = '/'; // buyer landing (browse listings)

  static const brokerListings = '/broker/listings';
  static const brokerListingsNew = '/broker/listings/new';
  static const brokerVerify = '/broker/verify';
  static const brokerAnalytics = '/broker/analytics';

  static const adminQueue = '/admin/queue';
  static const adminBrokers = '/admin/brokers'; // + '/:id'

  static const listings = '/listings'; // + '/:id'

  static const marketPrices = '/market/prices';
  static const messages = '/messages'; // + '/:threadId' for detail

  static const brokerProfile = '/brokers'; // + '/:id'
}

/// Given the current user role, where should the "home" landing be?
String landingFor(String? role) {
  switch (role) {
    case 'admin':
      return Routes.adminQueue;
    case 'broker':
      return Routes.brokerListings;
    default:
      return Routes.home;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.login,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final user = auth.user;
      final loggedIn = user != null;
      final loc = state.matchedLocation;

      final onAuthRoute = loc == Routes.login ||
          loc == Routes.register ||
          loc == Routes.forgotPassword;

      if (!loggedIn) {
        return onAuthRoute ? null : Routes.login;
      }

      // Post-register redirect: if the just-created account isn't
      // phone-verified yet and they haven't chosen to skip, funnel them
      // through /verify-phone once before the role landing. The verify
      // screen itself has a "Skip for now" out.
      if (loc == Routes.verifyPhone) return null;
      if (onAuthRoute) {
        if (!user.phoneVerified && loc == Routes.register) {
          return Routes.verifyPhone;
        }
        return landingFor(user.role);
      }

      // Role-based gates.
      if (loc.startsWith('/admin') && user.role != 'admin') {
        return landingFor(user.role);
      }
      if (loc.startsWith('/broker') && user.role != 'broker') {
        return landingFor(user.role);
      }
      // Buyer home is only for buyers.
      if (loc == Routes.home && user.role != 'buyer') {
        return landingFor(user.role);
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.verifyPhone, builder: (_, __) => const VerifyPhoneScreen()),

      // Buyer
      GoRoute(path: Routes.home, builder: (_, __) => const BrowseListingsScreen()),

      // Broker
      GoRoute(
        path: Routes.brokerListings,
        builder: (_, __) => const MyListingsScreen(),
      ),
      GoRoute(
        path: Routes.brokerListingsNew,
        builder: (_, __) => const CreateListingScreen(),
      ),
      GoRoute(
        path: Routes.brokerVerify,
        builder: (_, __) => const VerificationScreen(),
      ),
      GoRoute(
        path: Routes.brokerAnalytics,
        builder: (_, __) => const AnalyticsScreen(),
      ),

      // Admin
      GoRoute(
        path: Routes.adminQueue,
        builder: (_, __) => const AdminQueueScreen(),
      ),
      GoRoute(
        path: '${Routes.adminBrokers}/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AdminBrokerDetailScreen(brokerUserId: id);
        },
      ),

      // Listing detail — shared by buyer, broker owner, and admin.
      GoRoute(
        path: '${Routes.listings}/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ListingDetailScreen(listingId: id);
        },
      ),

      // Price transparency — accessible to any authed role.
      GoRoute(
        path: Routes.marketPrices,
        builder: (_, __) => const PriceTransparencyScreen(),
      ),

      // Messages (all authed roles — buyers and brokers both use it).
      GoRoute(
        path: Routes.messages,
        builder: (_, __) => const ThreadsListScreen(),
      ),
      GoRoute(
        path: '${Routes.messages}/:threadId',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['threadId']!);
          // If we arrived from the inbox we pass the thread DTO via
          // `extra` so the header renders instantly; deep links have
          // no extra and the screen loads it from the first fetch.
          final hint = state.extra is ThreadDto ? state.extra as ThreadDto : null;
          return ThreadScreen(threadId: id, hint: hint);
        },
      ),

      // Broker public profile — aggregate rating + recent reviews.
      GoRoute(
        path: '${Routes.brokerProfile}/:id',
        builder: (_, state) {
          final id = int.parse(state.pathParameters['id']!);
          return BrokerProfileScreen(brokerId: id);
        },
      ),
    ],
  );
});
