import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/confirm/confirm_scan_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/already_have_screen.dart';
import 'features/home/home_screen.dart';
import 'features/inventory/box_form_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/inventory/product_detail_screen.dart';
import 'features/inventory/product_form_screen.dart';
import 'features/profiles/profile_detail_screen.dart';
import 'features/profiles/profile_form_screen.dart';
import 'features/profiles/profiles_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell.dart';
import 'features/treatments/treatment_form_screen.dart';

final rootKey = GlobalKey<NavigatorState>();

int? _int(String? v) => v == null ? null : int.tryParse(v);

GoRouter buildRouter() => GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/inventory', builder: (_, _) => const InventoryScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/profiles', builder: (_, _) => const ProfilesScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())]),
          ],
        ),
        GoRoute(
          path: '/inventory/product',
          parentNavigatorKey: rootKey,
          builder: (_, s) => ProductFormScreen(
            productId: _int(s.uri.queryParameters['id']),
            gtin: s.uri.queryParameters['gtin'],
            lot: s.uri.queryParameters['lot'],
            expires: s.uri.queryParameters['exp'],
          ),
        ),
        GoRoute(
          path: '/inventory/product/:id',
          parentNavigatorKey: rootKey,
          builder: (_, s) => ProductDetailScreen(productId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/inventory/box',
          parentNavigatorKey: rootKey,
          builder: (_, s) => BoxFormScreen(
            productId: int.parse(s.uri.queryParameters['productId']!),
            boxId: _int(s.uri.queryParameters['boxId']),
            lot: s.uri.queryParameters['lot'],
            expires: s.uri.queryParameters['exp'],
          ),
        ),
        GoRoute(path: '/profiles/new', parentNavigatorKey: rootKey, builder: (_, _) => const ProfileFormScreen()),
        GoRoute(
          path: '/profiles/:id',
          parentNavigatorKey: rootKey,
          builder: (_, s) => ProfileDetailScreen(profileId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/profiles/:id/edit',
          parentNavigatorKey: rootKey,
          builder: (_, s) => ProfileFormScreen(profileId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/treatments/new',
          parentNavigatorKey: rootKey,
          builder: (_, s) => TreatmentFormScreen(
            profileId: _int(s.uri.queryParameters['profileId']),
            productId: _int(s.uri.queryParameters['productId']),
          ),
        ),
        GoRoute(
          path: '/treatments/:id',
          parentNavigatorKey: rootKey,
          builder: (_, s) => HistoryScreen(treatmentId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/confirm-scan',
          parentNavigatorKey: rootKey,
          builder: (_, s) => ConfirmScanScreen(doseId: _int(s.uri.queryParameters['doseId'])),
        ),
        GoRoute(path: '/already-have', parentNavigatorKey: rootKey, builder: (_, _) => const AlreadyHaveScreen()),
      ],
    );
