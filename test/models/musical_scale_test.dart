import 'package:flutter_test/flutter_test.dart';
import 'package:flute_practice/models/musical_scale.dart';

void main() {
  group('MusicalScale', () {
    test('C Major 音阶包含正确音名', () {
      const scale = MusicalScale(root: 'C', type: ScaleType.major);
      final indices = scale.noteIndices();
      // C Major: C D E F G A B = {0,2,4,5,7,9,11}
      expect(indices, equals({0, 2, 4, 5, 7, 9, 11}));
    });

    test('A Minor 音阶包含正确音名', () {
      const scale = MusicalScale(root: 'A', type: ScaleType.minor);
      final indices = scale.noteIndices();
      // A Minor: A B C D E F G = {9,11,0,2,4,5,7}
      expect(indices, equals({9, 11, 0, 2, 4, 5, 7}));
    });

    test('label 格式正确', () {
      const major = MusicalScale(root: 'G', type: ScaleType.major);
      const minor = MusicalScale(root: 'D', type: ScaleType.minor);
      expect(major.label, equals('G Major'));
      expect(minor.label, equals('D Minor'));
    });

    test('toJson / fromJson 对称', () {
      const original = MusicalScale(root: 'F#', type: ScaleType.minor);
      final restored = MusicalScale.fromJson(original.toJson());
      expect(restored.root, equals(original.root));
      expect(restored.type, equals(original.type));
    });

    test('fromJson 缺失字段使用默认值', () {
      final scale = MusicalScale.fromJson({});
      expect(scale.root, equals('C'));
      expect(scale.type, equals(ScaleType.major));
    });

    test('fromJson 未知 type 回退到 major', () {
      final scale = MusicalScale.fromJson({'root': 'G', 'type': 'unknown'});
      expect(scale.type, equals(ScaleType.major));
    });

    test('allScales 返回 24 个音阶（12 根音 × 2 类型）', () {
      final scales = MusicalScale.allScales();
      expect(scales.length, equals(24));
    });

    test('未知根音回退到 C Major 全音阶', () {
      const scale = MusicalScale(root: 'X', type: ScaleType.major);
      final indices = scale.noteIndices();
      expect(indices, equals({0, 2, 4, 5, 7, 9, 11}));
    });
  });
}
