import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:api_caffeine/core/ui/theme/app_fonts.dart';
import 'package:api_caffeine/core/ui/theme/app_spacing.dart';
import 'package:api_caffeine/modules/requests/services/response_mind_map.dart';

const _nodeWidth = 224.0;
const _nodeHeight = 38.0;
const _columnWidth = 276.0;
const _rowHeight = 54.0;
const _margin = 20.0;

class ResponseMindMapView extends StatefulWidget {
  const ResponseMindMapView({
    required this.map,
    required this.expanded,
    required this.activeNode,
    required this.revealRevision,
    required this.viewport,
    required this.onToggle,
    super.key,
  });

  final ResponseMindMap map;
  final Set<int> expanded;
  final int? activeNode;
  final int revealRevision;
  final TransformationController viewport;
  final ValueChanged<int> onToggle;

  @override
  State<ResponseMindMapView> createState() => _ResponseMindMapViewState();
}

class _ResponseMindMapViewState extends State<ResponseMindMapView> {
  @override
  Widget build(BuildContext context) {
    final positions = <int, Offset>{};
    var nextRow = 0;
    var maxColumn = 0;
    double place(int id, int column) {
      maxColumn = math.max(maxColumn, column);
      final children = widget.map.nodes[id].children;
      final double row;
      if (widget.expanded.contains(id) && children.isNotEmpty) {
        row = place(children.first, column + 1);
        for (final child in children.skip(1)) {
          place(child, column + 1);
        }
      } else {
        row = (nextRow++).toDouble();
      }
      positions[id] = Offset(
        _margin + column * _columnWidth,
        _margin + row * _rowHeight,
      );
      return row;
    }

    place(0, 0);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        _revealMatch(positions, constraints.biggest);
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ColoredBox(
            color: scheme.surfaceContainer,
            child: InteractiveViewer(
              transformationController: widget.viewport,
              constrained: false,
              alignment: Alignment.topLeft,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.25,
              maxScale: 2.5,
              child: SizedBox(
                width: _margin * 2 + maxColumn * _columnWidth + _nodeWidth,
                height: _margin * 2 + (nextRow - 1) * _rowHeight + _nodeHeight,
                child: CustomPaint(
                  painter: _Connections(
                    widget.map,
                    positions,
                    scheme.outlineVariant,
                  ),
                  child: Stack(
                    children: [
                      for (final entry in positions.entries.toList().reversed)
                        Positioned(
                          left: entry.value.dx,
                          top: entry.value.dy,
                          width: _nodeWidth,
                          height: _nodeHeight,
                          child: _Node(
                            node: widget.map.nodes[entry.key],
                            active: widget.activeNode == entry.key,
                            expanded: widget.expanded.contains(entry.key),
                            onToggle: () => widget.onToggle(entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // A restored viewport should stay put until the next Find action.
  int _revealed = 0;

  void _revealMatch(Map<int, Offset> positions, Size viewport) {
    if (_revealed == widget.revealRevision) return;
    final target = positions[widget.activeNode];
    if (target == null) return;
    final revision = widget.revealRevision;
    _revealed = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.revealRevision != revision) return;
      final scale = widget.viewport.value.getMaxScaleOnAxis();
      widget.viewport.value = Matrix4.identity()
        ..translateByDouble(
          viewport.width / 2 - (target.dx + _nodeWidth / 2) * scale,
          viewport.height / 2 - (target.dy + _nodeHeight / 2) * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
    });
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.node,
    required this.active,
    required this.expanded,
    required this.onToggle,
  });

  final ResponseMindMapNode node;
  final bool active;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branch = node.children.isNotEmpty;
    final caption = Text(
      node.caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: AppFonts.mono,
        fontSize: 12,
        color: active ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
    );
    return Tooltip(
      message: node.caption,
      child: Material(
        color: active ? scheme.primaryContainer : scheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(AppRadius.tag),
        ),
        child: branch
            ? Semantics(
                expanded: expanded,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.tag),
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          expanded ? Icons.expand_more : Icons.chevron_right,
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: caption),
                      ],
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Align(alignment: Alignment.centerLeft, child: caption),
              ),
      ),
    );
  }
}

class _Connections extends CustomPainter {
  _Connections(this.map, this.positions, this.color);

  final ResponseMindMap map;
  final Map<int, Offset> positions;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    for (final entry in positions.entries) {
      final parent = positions[map.nodes[entry.key].parentId];
      if (parent == null) continue;
      final start = parent + const Offset(_nodeWidth, _nodeHeight / 2);
      final end = entry.value + const Offset(0, _nodeHeight / 2);
      final middle = (start.dx + end.dx) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(middle, start.dy, middle, end.dy, end.dx, end.dy),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_Connections oldDelegate) => true;
}
