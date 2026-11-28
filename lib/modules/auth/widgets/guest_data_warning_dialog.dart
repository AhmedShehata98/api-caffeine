import 'package:flutter/material.dart';
import 'package:api_caffeine/core/ui/widgets/confirm_dialog.dart';

/// Warns that signing in to an existing GitHub account discards the guest's work.
/// Returns true only if the user chose to sign in anyway.
Future<bool> showGuestDataWarningDialog(BuildContext context) =>
    showConfirmDialog(
      context,
      title: 'Sign in to an existing account?',
      message:
          'This GitHub account already has an API Caffeine account. '
          'Your guest workspace will not be carried over.',
      confirmLabel: 'Sign in anyway',
      destructive: true,
    );
