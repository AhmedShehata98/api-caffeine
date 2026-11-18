import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_resource_export_repository.dart';
import 'package:test_point/modules/mcp_lab/services/mcp_resource_export_service.dart';

class _Repository implements McpResourceExportRepository {
  final calls = <(Uint8List, String, String)>[];
  Future<Result<bool>> Function()? respond;
  @override
  Future<Result<bool>> save(Uint8List bytes, String name, String mime) async {
    calls.add((bytes, name, mime));
    return respond == null ? const Result.success(true) : respond!();
  }
}

void main() {
  late _Repository repository;
  late McpResourceExportService service;
  const content = ResourceContents(
    uri: 'fixture://../../bad.exe',
    mimeType: 'image/png; charset=binary',
    blob: 'AID/AA==',
  );
  setUp(() {
    repository = _Repository();
    service = McpResourceExportService(repository);
  });
  test(
    'explicit export preserves bytes and uses a safe suggested name',
    () async {
      expect(
        (await service.save(content, isCurrent: () => true)).valueOrNull,
        isTrue,
      );
      expect(repository.calls.single.$1, [0, 128, 255, 0]);
      expect(repository.calls.single.$2, 'resource.png');
      expect(repository.calls.single.$3, 'image/png; charset=binary');
    },
  );
  test('native cancellation remains a successful cancellation', () async {
    repository.respond = () async => const Result.success(false);
    expect(
      (await service.save(content, isCurrent: () => true)).valueOrNull,
      isFalse,
    );
  });
  test('invalid base64 and text cannot open the save dialog', () async {
    final invalid = await service.save(
      content.copyWith(blob: '***'),
      isCurrent: () => true,
    );
    expect(invalid.failureOrNull?.message, contains('invalid base64'));
    final text = await service.save(
      const ResourceContents(uri: 'fixture://text', text: 'hello'),
      isCurrent: () => true,
    );
    expect(text.isSuccess, isFalse);
    expect(repository.calls, isEmpty);
  });
  test(
    'revoked ownership before or during decoding cannot open the dialog',
    () async {
      expect(
        (await service.save(content, isCurrent: () => false)).isSuccess,
        isFalse,
      );
      var checks = 0;
      expect(
        (await service.save(content, isCurrent: () => ++checks == 1)).isSuccess,
        isFalse,
      );
      expect(repository.calls, isEmpty);
    },
  );
  test('late native completion cannot become a current success', () async {
    var current = true;
    final opened = Completer<void>();
    final pending = Completer<Result<bool>>();
    repository.respond = () {
      opened.complete();
      return pending.future;
    };
    final saving = service.save(content, isCurrent: () => current);
    await opened.future;
    current = false;
    pending.complete(const Result.success(true));
    expect((await saving).failureOrNull?.message, contains('no longer active'));
  });
  test(
    'storage failure remains visible and unexpected exceptions are sanitized',
    () async {
      repository.respond = () async =>
          const Result.failure(StorageFailure('Cannot write here.'));
      expect(
        (await service.save(
          content,
          isCurrent: () => true,
        )).failureOrNull?.message,
        'Cannot write here.',
      );
      repository.respond = () async => throw StateError('private path');
      final failure = (await service.save(
        content,
        isCurrent: () => true,
      )).failureOrNull!;
      expect(failure.message, isNot(contains('private path')));
    },
  );
}
