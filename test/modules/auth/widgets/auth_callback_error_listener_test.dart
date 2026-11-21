import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/modules/auth/auth.dart';

void main() {
  testWidgets('shows a snackbar when a GitHub redirect fails', (tester) async {
    final errors = StreamController<Failure>();
    addTearDown(errors.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authCallbackErrorProvider.overrideWith((_) => errors.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AuthCallbackErrorListener(child: SizedBox.expand()),
          ),
        ),
      ),
    );
    expect(find.byType(SnackBar), findsNothing);

    errors.add(const AuthFailure('GitHub access was denied.'));
    await tester.pump();
    await tester.pump();

    expect(find.text('GitHub access was denied.'), findsOneWidget);
  });
}
