import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/ui/theme/app_spacing.dart';
import 'package:api_caffeine/modules/requests/models/key_value.dart';
import 'package:api_caffeine/modules/requests/providers/request_providers.dart';
import 'package:api_caffeine/modules/requests/widgets/auth_tab.dart';
import 'package:api_caffeine/modules/requests/widgets/body_tab.dart';
import 'package:api_caffeine/modules/requests/widgets/key_value_table.dart';
import 'package:api_caffeine/modules/requests/widgets/request_bar.dart';
import 'package:api_caffeine/modules/requests/widgets/response_schema_tab.dart';

int _enabledCount(List<KeyValue> rows) =>
    rows.where((row) => row.enabled && row.key.trim().isNotEmpty).length;

/// A tab label with the number of active rows next to it (hidden at 0).
class _CountTab extends StatelessWidget {
  const _CountTab(this.label, this.count);

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, maxLines: 1),
          if (count > 0) ...[
            const SizedBox(width: AppSpacing.xs + 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm - 2,
              ),
              decoration: ShapeDecoration(
                color: scheme.surfaceContainerHighest,
                shape: const StadiumBorder(),
              ),
              child: Text(
                '$count',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'JetBrainsMono',
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Request builder: URL bar plus the Params / Headers / Auth / Body tabs.
class RequestEditor extends ConsumerStatefulWidget {
  const RequestEditor({super.key});

  @override
  ConsumerState<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends ConsumerState<RequestEditor>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this);
  final _schemaFocus = FocusNode(debugLabel: 'Response schema');

  @override
  void dispose() {
    _tabs.dispose();
    _schemaFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(requestDraftProvider);
    final notifier = ref.read(requestDraftProvider.notifier);
    ref.listen(schemaEditorRequestProvider, (_, next) {
      _tabs.index = 4;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schemaFocus.requestFocus();
      });
    });

    return Column(
      children: [
        const RequestBar(),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            _CountTab('Params', _enabledCount(draft.params)),
            _CountTab('Headers', _enabledCount(draft.headers)),
            const Tab(text: 'Auth'),
            const Tab(text: 'Body'),
            const Tab(text: 'Test'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              KeyValueTable(items: draft.params, onChanged: notifier.setParams),
              KeyValueTable(
                items: draft.headers,
                onChanged: notifier.setHeaders,
              ),
              AuthTab(auth: draft.auth, onChanged: notifier.setAuth),
              BodyTab(body: draft.body, onChanged: notifier.setBody),
              ResponseSchemaTab(
                enabled: draft.responseSchemaEnabled,
                source: draft.responseSchemaSource,
                focusNode: _schemaFocus,
                onEnabled: notifier.setResponseSchemaEnabled,
                onSource: notifier.setResponseSchemaSource,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
