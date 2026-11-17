import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_protocol_models.dart';
import '../providers/mcp_content_actions_provider.dart';
import '../services/mcp_content_presentation.dart';
import 'mcp_resource_content_view.dart';

class McpContentBlockView extends ConsumerWidget {
  const McpContentBlockView({
    required this.serverId,
    required this.origin,
    required this.block,
    this.onOpenResources,
    super.key,
  });
  final String serverId;
  final McpContentOrigin origin;
  final ContentBlock block;
  final VoidCallback? onOpenResources;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (block case final ResourceLinkBlock link) {
      return _ResourceLink(
        serverId: serverId,
        origin: origin,
        link: link,
        onOpenResources: onOpenResources,
      );
    }
    if (block case TextBlock(:final text)) {
      return _TextContent(
        serverId: serverId,
        origin: origin,
        block: block,
        text: text,
      );
    }
    return McpResourceContentView(
      serverId: serverId,
      origin: origin,
      block: block,
      label: switch (block) {
        ImageBlock() => 'Image',
        AudioBlock() => 'Audio',
        _ => null,
      },
      contents: resourceForMcpContent(block)!,
    );
  }
}

class _TextContent extends StatefulWidget {
  const _TextContent({
    required this.serverId,
    required this.origin,
    required this.block,
    required this.text,
  });
  final String serverId;
  final McpContentOrigin origin;
  final ContentBlock block;
  final String text;
  @override
  State<_TextContent> createState() => _TextContentState();
}

class _TextContentState extends State<_TextContent> {
  bool _full = false;
  @override
  Widget build(BuildContext context) {
    if (_full) {
      return McpResourceContentView(
        serverId: widget.serverId,
        contents: resourceForMcpContent(widget.block)!,
        origin: widget.origin,
        block: widget.block,
        label: 'Text content',
      );
    }
    var end = widget.text.length.clamp(0, 4096);
    if (end > 0 &&
        end < widget.text.length &&
        widget.text.codeUnitAt(end - 1) >= 0xd800 &&
        widget.text.codeUnitAt(end - 1) <= 0xdbff) {
      end--;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(widget.text.substring(0, end)),
        if (end < widget.text.length)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _full = true),
              child: const Text('Inspect full text'),
            ),
          ),
      ],
    );
  }
}

class _ResourceLink extends ConsumerStatefulWidget {
  const _ResourceLink({
    required this.serverId,
    required this.origin,
    required this.link,
    this.onOpenResources,
  });
  final String serverId;
  final McpContentOrigin origin;
  final ResourceLinkBlock link;
  final VoidCallback? onOpenResources;
  @override
  ConsumerState<_ResourceLink> createState() => _ResourceLinkState();
}

class _ResourceLinkState extends ConsumerState<_ResourceLink> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final available = ref.watch(mcpCanOpenResourceProvider(widget.serverId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.link.title ?? widget.link.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SelectableText(widget.link.uri),
        if (widget.link.mimeType case final mime?)
          Text(mime, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (widget.link.description case final description?) Text(description),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Resources', maxLines: 1),
            onPressed: !available || widget.onOpenResources == null
                ? null
                : () {
                    final result = ref
                        .read(mcpContentActionsProvider(widget.serverId))
                        .openResource(widget.link, widget.origin);
                    if (result.isSuccess) {
                      widget.onOpenResources!();
                    } else {
                      setState(() => _error = result.failureOrNull!.message);
                    }
                  },
          ),
        ),
        if (!available)
          const Text('This server does not advertise resource reads.'),
        if (_error != null) Text(_error!),
      ],
    );
  }
}
