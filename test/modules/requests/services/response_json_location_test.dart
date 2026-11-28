import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/requests/services/response_json_location.dart';
import 'package:api_caffeine/modules/requests/widgets/response_schema_inspector.dart';

void main() {
  test('locates exact typed paths and escaped property names', () {
    const json = '{"0":[{"a/b~c":42}],"other":[1,2]}';
    expect(responseJsonLocation(json, ['0', 0, 'a/b~c']), json.indexOf('42'));
    expect(responseJsonLocation(json, ['other', 1]), json.indexOf('2]}'));
    expect(responseJsonLocation(json, ['missing']), isNull);
    expect(schemaIssuePath(['0', 0, 'a/b~c']), r'$["0"][0]["a/b~c"]');
  });
}
