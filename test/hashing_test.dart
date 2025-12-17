import 'package:flutter_test/flutter_test.dart';
import 'package:unit/hashing.dart';

void main() {
  test('sha256Hex returns known hash for "abc"', () {
    final result = sha256Hex('abc');
    expect(result, 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
