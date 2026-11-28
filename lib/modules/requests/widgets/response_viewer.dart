import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/ui/theme/app_spacing.dart';
import 'package:api_caffeine/modules/requests/models/send_state.dart';
import 'package:api_caffeine/modules/requests/providers/request_providers.dart';
import 'package:api_caffeine/modules/requests/widgets/response_result_view.dart';

/// Response pane: idle, loading, error and the Body / Headers result views.
class ResponseViewer extends ConsumerWidget {
  const ResponseViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(sendStateProvider)) {
      SendIdle() => const _Message(
        icon: Icons.send_outlined,
        text: 'Send a request to see the response.',
      ),
      SendLoading() => const _Loading(),
      SendFailed(:final failure) => _Message(
        icon: Icons.error_outline,
        text: failure.message,
        isError: true,
      ),
      SendSuccess(:final response, :final schemaTest) => ResponseResultView(
        key: ObjectKey(response),
        response: response,
        schemaTest: schemaTest,
        currentSchema: ref.watch(requestDraftProvider).responseSchemaSource,
        onEditSchema: () =>
            ref.read(schemaEditorRequestProvider.notifier).open(),
      ),
    };
  }
}

class _Message extends ConsumerWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.primary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.cardLarge),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isError) ...[
            Text(
              'Request failed',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: AppSpacing.sm),
          if (isError)
            TextButton(
              onPressed: ref.read(sendStateProvider.notifier).send,
              child: const Text('Retry'),
            )
          else
            Text(
              'Press Ctrl+Enter to send',
              maxLines: 1,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _Loading extends ConsumerWidget {
  const _Loading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          const Text('Sending…'),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: ref.read(sendStateProvider.notifier).cancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
