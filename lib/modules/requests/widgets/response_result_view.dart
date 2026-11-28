import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:api_caffeine/core/ui/theme/app_fonts.dart';
import 'package:api_caffeine/core/ui/theme/app_spacing.dart';
import 'package:api_caffeine/core/ui/widgets/code_view.dart';
import 'package:api_caffeine/core/ui/widgets/status_chip.dart';
import 'package:api_caffeine/modules/requests/models/http_response_result.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';
import 'package:api_caffeine/modules/requests/services/response_body_formatter.dart';
import 'package:api_caffeine/modules/requests/services/response_json_location.dart';
import 'package:api_caffeine/modules/requests/services/response_mind_map.dart';
import 'package:api_caffeine/modules/requests/widgets/response_mind_map_view.dart';
import 'package:api_caffeine/modules/requests/widgets/response_schema_inspector.dart';

enum _BodyMode {
  raw('Raw'),
  pretty('Pretty'),
  mindMap('Mind Map');

  const _BodyMode(this.label);
  final String label;
}

class ResponseResultView extends StatefulWidget {
  const ResponseResultView({
    required this.response,
    this.schemaTest,
    this.currentSchema = '',
    this.onEditSchema,
    super.key,
  });

  final HttpResponseResult response;
  final SchemaTestResult? schemaTest;
  final String currentSchema;
  final VoidCallback? onEditSchema;

  @override
  State<ResponseResultView> createState() => _ResponseResultViewState();
}

class _ResponseResultViewState extends State<ResponseResultView> {
  late final _session = _ResponseSession(widget.response);
  late final _schema = ValueNotifier((
    result: widget.schemaTest,
    source: widget.currentSchema,
  ));
  var _expanded = false;

  @override
  void didUpdateWidget(ResponseResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schemaTest != widget.schemaTest ||
        oldWidget.currentSchema != widget.currentSchema) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _schema.value = (
            result: widget.schemaTest,
            source: widget.currentSchema,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _schema.dispose();
    super.dispose();
  }

  Future<void> _expand() async {
    if (_expanded) return;
    final response = widget.response;
    final session = _session;
    setState(() => _expanded = true);
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          body: SafeArea(
            child: _ResultPanel(
              response: response,
              session: session,
              schema: _schema,
              onEditSchema: () {
                Navigator.of(context).pop();
                widget.onEditSchema?.call();
              },
              expanded: true,
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) => _expanded
      ? const SizedBox.expand()
      : _ResultPanel(
          response: widget.response,
          session: _session,
          schema: _schema,
          onEditSchema: widget.onEditSchema,
          onExpand: _expand,
        );
}

// Each presentation owns its controllers. This session survives the route
// transition and is scoped to the response instance that opened it.
class _ResponseSession {
  _ResponseSession(HttpResponseResult response)
    : mode = response.prettyBody == null ? _BodyMode.raw : _BodyMode.pretty;

  _BodyMode mode;
  int tab = 0;
  bool finding = false;
  String query = '';
  int? matchIndex;
  ({_BodyMode mode, CodeFindValue value})? textSearchSnapshot;
  final textOffsets = <_BodyMode, Offset>{};
  double headerOffset = 0;
  final expandedNodes = <int>{0};
  Matrix4? mapViewport;
  Future<ResponseMindMap>? mapFuture;
}

class _ResultPanel extends StatefulWidget {
  const _ResultPanel({
    required this.response,
    required this.session,
    required this.schema,
    this.onEditSchema,
    this.expanded = false,
    this.onExpand,
  });

  final HttpResponseResult response;
  final _ResponseSession session;
  final ValueNotifier<({SchemaTestResult? result, String source})> schema;
  final VoidCallback? onEditSchema;
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  State<_ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<_ResultPanel>
    with SingleTickerProviderStateMixin {
  final _editor = CodeLineEditingController();
  final _textScroll = CodeScrollController();
  final _viewerFocus = FocusNode(debugLabel: 'Response viewer');
  final _bodyFocus = FocusNode(debugLabel: 'Response body');
  final _findFocus = FocusNode(debugLabel: 'Find in response');
  late final _textFind = CodeFindController(_editor);
  late final _query = TextEditingController(text: _session.query);
  late final _headers = ScrollController(
    initialScrollOffset: _session.headerOffset,
  );
  late final _viewport = TransformationController(
    _session.mapViewport?.clone(),
  );
  late final _tabs = TabController(
    length: 2,
    initialIndex: _session.tab,
    vsync: this,
  );

  ResponseMindMap? _map;
  List<int> _mapMatches = const [];
  int _mapReveal = 0;
  int _textLoad = 0;
  int? _pendingTextMatch;
  bool _textReady = false;
  bool _syncingFind = false;
  bool _mapRequested = false;

  _ResponseSession get _session => widget.session;
  HttpResponseResult get _response => widget.response;
  bool get _showBody => _session.tab == 0;
  bool get _mapping => _session.mode == _BodyMode.mindMap;
  String get _source => _session.mode == _BodyMode.pretty
      ? _response.prettyBody!
      : _response.body;

  late final _syntax = switch (responseSource(_response)) {
    ResponseSource.json => CodeSyntax.json,
    ResponseSource.xml || ResponseSource.html => CodeSyntax.xml,
    null => null,
  };

  late final _mapCandidate =
      _syntax == CodeSyntax.json || couldBeJson(_response.body);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_changeTab);
    _textFind.addListener(_textSearchChanged);
    _viewport.addListener(_rememberMapViewport);
    if (_mapping) {
      unawaited(_loadMap(restore: true));
    } else {
      unawaited(_loadSource(restore: true));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _textFind.dispose();
    _editor.dispose();
    _textScroll.dispose();
    _textScroll.verticalScroller.dispose();
    _textScroll.horizontalScroller.dispose();
    _viewerFocus.dispose();
    _bodyFocus.dispose();
    _findFocus.dispose();
    _query.dispose();
    _headers.dispose();
    _viewport.dispose();
    super.dispose();
  }

  void _changeTab() {
    if (_tabs.index == _session.tab) return;
    _rememberScroll();
    setState(() => _session.tab = _tabs.index);
  }

  void _rememberScroll() {
    if (_headers.hasClients) _session.headerOffset = _headers.offset;
    if (!_mapping &&
        _textReady &&
        _textScroll.horizontalScroller.hasClients &&
        _textScroll.verticalScroller.hasClients) {
      _session.textOffsets[_session.mode] = Offset(
        _textScroll.horizontalScroller.offset,
        _textScroll.verticalScroller.offset,
      );
    }
    final find = _textFind.value;
    _session.textSearchSnapshot =
        !_mapping &&
            _session.finding &&
            find?.option.pattern == _session.query &&
            find?.result?.dirty == false
        ? (mode: _session.mode, value: find!)
        : null;
  }

  void _rememberMapViewport() => _session.mapViewport = _viewport.value.clone();

  void _restoreScroll(Offset offset) {
    void jump(ScrollController controller, double value) {
      if (!controller.hasClients || !controller.position.hasContentDimensions) {
        return;
      }
      final position = controller.position;
      controller.jumpTo(
        value.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }

    jump(_textScroll.verticalScroller, offset.dy);
    jump(_textScroll.horizontalScroller, offset.dx);
  }

  Future<void> _loadSource({bool restore = false}) async {
    final load = ++_textLoad;
    final source = _source;
    final snapshot = restore ? _session.textSearchSnapshot : null;
    _session.textSearchSnapshot = null;
    final find =
        snapshot?.mode == _session.mode &&
            snapshot?.value.option.pattern == _session.query
        ? snapshot?.value
        : null;
    final lines =
        find?.result?.codeLines ??
        (source.length > 64 * 1024
            ? await source.codeLinesAsync
            : source.codeLines);
    if (!mounted || load != _textLoad) return;

    _syncingFind = true;
    _textFind.close();
    _editor.codeLines = lines;
    _editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
    if (find != null) {
      _textFind.findInputController.text = find.option.pattern;
      _textFind.value = find;
      final match = _textFind.currentMatchSelection;
      if (match != null) _editor.selection = match;
    }
    _syncingFind = false;
    setState(() => _textReady = true);

    final offset = _session.textOffsets[_session.mode];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || load != _textLoad) return;
      _restoreScroll(offset ?? Offset.zero);
      _syncTextSearch(index: restore ? _session.matchIndex : null);
    });
  }

  Future<void> _loadMap({bool restore = false}) async {
    if (_mapRequested) {
      if (_map != null) _searchMap(_session.query);
      return;
    }
    _mapRequested = true;
    final map = await (_session.mapFuture ??= buildResponseMindMap(
      _response.body,
      _response.sizeBytes,
    ));
    if (!mounted) return;
    setState(() => _map = map);
    if (_mapping && _session.finding) {
      _searchMap(_session.query, restore: restore);
    }
  }

  void _changeMode(_BodyMode mode) {
    if (mode == _session.mode) return;
    _rememberScroll();
    ++_textLoad;
    _syncingFind = true;
    _textFind.close();
    _syncingFind = false;
    setState(() {
      _session.mode = mode;
      _session.matchIndex = null;
      _textReady = false;
    });
    if (_mapping) {
      unawaited(_loadMap());
    } else {
      unawaited(_loadSource());
    }
  }

  void _openFind() {
    if (!_showBody) return;
    final wasFinding = _session.finding;
    setState(() => _session.finding = true);
    if (_mapping) {
      if (!wasFinding) _searchMap(_session.query);
    } else {
      _syncTextSearch();
    }
    _findFocus.requestFocus();
    _query.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _query.text.length,
    );
  }

  void _closeFind() {
    setState(() {
      _session.finding = false;
      _session.matchIndex = null;
      _mapMatches = const [];
    });
    _textFind.close();
    _viewerFocus.requestFocus();
  }

  void _escape() {
    if (_session.finding && _showBody) {
      _closeFind();
    } else if (widget.expanded) {
      Navigator.of(context).pop();
    }
  }

  void _setQuery(String query) {
    setState(() {
      _session.query = query;
      _session.matchIndex = null;
    });
    if (_mapping) {
      _searchMap(query);
    } else {
      _syncTextSearch();
    }
  }

  void _syncTextSearch({int? index}) {
    if (!_textReady || !_session.finding || _mapping) return;
    if (_textFind.value?.option.pattern == _session.query) return;
    _pendingTextMatch = index ?? 0;
    _syncingFind = true;
    _textFind.findInputController.clear();
    _textFind.value = const CodeFindValue.empty();
    _textFind.findInputController.text = _session.query;
    _syncingFind = false;
  }

  void _textSearchChanged() {
    if (!mounted || _syncingFind || !_textReady || _mapping) return;
    final find = _textFind.value;
    if (find?.option.pattern != _session.query) return;
    final result = find?.result;
    if (result != null && !result.dirty && result.matches.isNotEmpty) {
      final pending = _pendingTextMatch;
      _pendingTextMatch = null;
      final index =
          pending?.clamp(0, result.matches.length - 1) ?? result.index;
      if (index != result.index) {
        _textFind.value = find!.copyWith(result: result.copyWith(index: index));
        return;
      }
      _session.matchIndex = index;
    }
    setState(() {});
  }

  void _searchMap(String query, {bool restore = false}) {
    if (!_session.finding) return;
    final matches = _map?.find(query) ?? const <int>[];
    setState(() {
      _mapMatches = matches;
      _session.matchIndex = matches.isEmpty
          ? null
          : (restore
                ? (_session.matchIndex ?? 0).clamp(0, matches.length - 1)
                : 0);
      if (!restore) _revealMapMatch();
    });
  }

  int? get _activeNode {
    final index = _session.matchIndex;
    return index == null || index >= _mapMatches.length
        ? null
        : _mapMatches[index];
  }

  void _revealMapMatch() {
    final target = _activeNode;
    if (target == null) return;
    var ancestor = _map!.nodes[target].parentId;
    while (ancestor != null) {
      _session.expandedNodes.add(ancestor);
      ancestor = _map!.nodes[ancestor].parentId;
    }
    ++_mapReveal;
  }

  void _stepMatch(int delta) {
    if (!_mapping) {
      if ((_textFind.value?.result?.matches.length ?? 0) == 0) return;
      if (delta < 0) {
        _textFind.previousMatch();
      } else {
        _textFind.nextMatch();
      }
      return;
    }
    if (_mapMatches.isEmpty) return;
    setState(() {
      _session.matchIndex =
          ((_session.matchIndex ?? 0) + delta) % _mapMatches.length;
      _revealMapMatch();
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _source));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Body copied'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _jumpToIssue(SchemaIssue issue) async {
    if (_tabs.index != 0) _tabs.index = 0;
    if (_mapping) {
      _changeMode(
        _response.prettyBody == null ? _BodyMode.raw : _BodyMode.pretty,
      );
      await _loadSource();
    }
    if (!_textReady) await _loadSource();
    if (!mounted || !_textReady) return;
    final offset = responseJsonLocation(_source, issue.anchor);
    if (offset == null) return;
    final before = _source.substring(0, offset);
    final line = '\n'.allMatches(before).length;
    final lastNewline = before.lastIndexOf('\n');
    final column = offset - lastNewline - 1;
    _editor.selection = CodeLineSelection(
      baseIndex: line,
      baseOffset: column,
      extentIndex: line,
      extentOffset: column + 1,
    );
    _bodyFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_textScroll.verticalScroller.hasClients) return;
      final position = _textScroll.verticalScroller.position;
      _textScroll.verticalScroller.jumpTo(
        (line * 19.0).clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final tabs = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: const [
        Tab(text: 'Body'),
        Tab(text: 'Headers'),
      ],
    );
    final panel = Focus(
      focusNode: _viewerFocus,
      autofocus: widget.expanded,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape &&
            (widget.expanded || (_session.finding && _showBody))) {
          _escape();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyF &&
            HardwareKeyboard.instance.isControlPressed &&
            _showBody) {
          _openFind();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ColoredBox(
            color: scheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: StatusChip(
                                statusCode: _response.statusCode,
                                reason: _response.reason,
                              ),
                            ),
                            if (width >= 235) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                _formatDuration(_response.duration),
                                style: muted,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                _formatSize(_response.sizeBytes),
                                style: muted,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (width < 235)
                        Tooltip(
                          message:
                              '${_formatDuration(_response.duration)} · ${_formatSize(_response.sizeBytes)}',
                          child: const Icon(Icons.info_outline, size: 16),
                        ),
                      IconButton(
                        tooltip: widget.expanded
                            ? 'Close expanded response'
                            : 'Expand response',
                        onPressed: widget.expanded
                            ? () => Navigator.of(context).pop()
                            : () {
                                _rememberScroll();
                                widget.onExpand?.call();
                              },
                        icon: Icon(
                          widget.expanded ? Icons.close : Icons.fullscreen,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showBody && width >= 520)
                  Row(
                    children: [
                      Expanded(child: tabs),
                      _bodyActions(compact: false),
                    ],
                  )
                else ...[
                  tabs,
                  if (_showBody) _bodyActions(compact: true),
                ],
                if (_showBody && _session.finding)
                  _buildFindBar(muted, compact: width < 275),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: widget.schema,
                    builder: (context, schema, _) {
                      final compactHeight =
                          constraints.maxHeight <
                          (schema.result?.issues.isNotEmpty == true
                              ? 420
                              : 260);
                      final inspector = Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          AppSpacing.xs,
                          AppSpacing.sm,
                          0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: ResponseSchemaInspector(
                            result: schema.result,
                            currentSource: schema.source,
                            validUtf8: _response.validUtf8,
                            onEdit: widget.onEditSchema ?? () {},
                            onIssue: _jumpToIssue,
                          ),
                        ),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (schema.result != null && compactHeight)
                            Flexible(
                              child: SingleChildScrollView(child: inspector),
                            ),
                          if (schema.result != null && !compactHeight)
                            inspector,
                          Expanded(
                            child: IndexedStack(
                              index: _session.tab,
                              sizing: StackFit.expand,
                              children: [
                                ExcludeFocus(
                                  excluding: !_showBody,
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    child: _mapping
                                        ? _buildMap()
                                        : _buildSource(),
                                  ),
                                ),
                                ExcludeFocus(
                                  excluding: _showBody,
                                  child: _HeadersList(
                                    headers: _response.headers,
                                    controller: _headers,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return widget.expanded
        ? PopScope<void>(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) _rememberScroll();
            },
            child: panel,
          )
        : panel;
  }

  Widget _bodyActions({required bool compact}) {
    final modes = [
      if (_response.prettyBody != null) _BodyMode.pretty,
      _BodyMode.raw,
      if (_mapCandidate) _BodyMode.mindMap,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<_BodyMode>(
                  tooltip: 'Body format',
                  initialValue: _session.mode,
                  onSelected: _changeMode,
                  itemBuilder: (context) => [
                    for (final mode in modes)
                      PopupMenuItem(value: mode, child: Text(mode.label)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _session.mode.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            SegmentedButton<_BodyMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final mode in modes)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {_session.mode},
              onSelectionChanged: (selection) => _changeMode(selection.single),
            ),
          IconButton(
            tooltip: 'Find in response (Ctrl+F)',
            onPressed: _openFind,
            icon: const Icon(Icons.search, size: 18),
          ),
          IconButton(
            tooltip: 'Copy body',
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildFindBar(TextStyle muted, {required bool compact}) {
    final find = _textFind.value;
    final count = _mapping
        ? _mapMatches.length
        : (find?.result?.matches.length ?? 0);
    final status = switch (_session.query) {
      '' => '',
      _ when !_mapping && (!_textReady || find?.searching == true) =>
        'Searching…',
      _ when _mapping && _map == null => 'Searching…',
      _ when count == 0 => 'No results',
      _ => '${(_session.matchIndex ?? 0) + 1} / $count',
    };
    final field = TextField(
      controller: _query,
      focusNode: _findFocus,
      style: const TextStyle(fontSize: 13),
      decoration: const InputDecoration(
        hintText: 'Find in body',
        isDense: true,
      ),
      onChanged: _setQuery,
      onSubmitted: (_) => _stepMatch(1),
    );
    final controls = [
      Flexible(
        child: Semantics(
          liveRegion: true,
          child: Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Previous match',
        visualDensity: VisualDensity.compact,
        onPressed: count == 0 ? null : () => _stepMatch(-1),
        icon: const Icon(Icons.keyboard_arrow_up, size: 18),
      ),
      IconButton(
        tooltip: 'Next match',
        visualDensity: VisualDensity.compact,
        onPressed: count == 0 ? null : () => _stepMatch(1),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      ),
      IconButton(
        tooltip: 'Close find',
        visualDensity: VisualDensity.compact,
        onPressed: _closeFind,
        icon: const Icon(Icons.close, size: 18),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                Row(children: controls),
              ],
            )
          : Row(
              children: [
                Expanded(child: field),
                ...controls,
              ],
            ),
    );
  }

  Widget _buildSource() {
    if (!_textReady) return const Center(child: CircularProgressIndicator());
    return CodeView(
      controller: _editor,
      focusNode: _bodyFocus,
      scrollController: _textScroll,
      findController: _textFind,
      shortcutOverrideActions: {
        CodeShortcutFindIntent: CallbackAction<CodeShortcutFindIntent>(
          onInvoke: (_) => _openFind(),
        ),
        if (widget.expanded || _session.finding)
          CodeShortcutEscIntent: CallbackAction<CodeShortcutEscIntent>(
            onInvoke: (_) => _escape(),
          ),
      },
      readOnly: true,
      highlightJson: _response.prettyBody != null && _syntax == CodeSyntax.json,
      syntax: _session.mode == _BodyMode.pretty ? _syntax : null,
      hint: 'Empty response body',
    );
  }

  Widget _buildMap() {
    final map = _map;
    if (map == null) return const Center(child: CircularProgressIndicator());
    final reason = map.unavailableReason;
    if (reason != null) {
      return Center(child: Text(reason, textAlign: TextAlign.center));
    }
    return ResponseMindMapView(
      map: map,
      expanded: _session.expandedNodes,
      activeNode: _activeNode,
      revealRevision: _mapReveal,
      viewport: _viewport,
      onToggle: (id) => setState(() {
        if (!_session.expandedNodes.remove(id)) _session.expandedNodes.add(id);
      }),
    );
  }
}

class _HeadersList extends StatelessWidget {
  const _HeadersList({required this.headers, required this.controller});

  final Map<String, List<String>> headers;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = headers.entries.toList();
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(fontFamily: AppFonts.mono, fontSize: 13),
              children: [
                TextSpan(
                  text: '${entry.key}: ',
                  style: TextStyle(color: scheme.primary),
                ),
                TextSpan(text: entry.value.join(', ')),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatDuration(Duration duration) => duration.inMilliseconds >= 1000
    ? '${(duration.inMilliseconds / 1000).toStringAsFixed(2)} s'
    : '${duration.inMilliseconds} ms';

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
