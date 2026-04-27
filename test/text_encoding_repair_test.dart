import 'package:flutter_test/flutter_test.dart';
import 'package:tf_ai/text_encoding_repair.dart';

void main() {
  test('repairs UTF-8 text decoded as Windows-1251', () {
    expect(repairTextEncoding('РїСЂРёРІРµС‚'), 'привет');
    expect(repairTextEncoding('РџСЂРёРІРµС‚ В· С‚РµСЃС‚'), 'Привет · тест');
  });

  test('does not touch normal text', () {
    expect(repairTextEncoding('привет'), 'привет');
    expect(repairTextEncoding('hello · test'), 'hello · test');
  });
}
