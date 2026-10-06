import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/error_message.dart';

class _RawToStringException implements Exception {
  final String value;
  _RawToStringException(this.value);

  @override
  String toString() => value;
}

class _CleanException implements Exception {
  @override
  String toString() => '同步失败';
}

void main() {
  test('describeError drops the Dart exception type prefix', () {
    expect(describeError(const FormatException('数据格式无效')), '数据格式无效');
    expect(describeError(Exception('网络错误')), '网络错误');
    expect(
      describeError(_RawToStringException('DioException [bad response]: 500')),
      '500',
    );
  });

  test('describeError keeps already clean messages', () {
    expect(describeError(_CleanException()), '同步失败');
  });
}
