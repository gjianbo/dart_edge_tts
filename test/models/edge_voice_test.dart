import 'package:flutter_test/flutter_test.dart';
import 'package:edge_tts_dart/src/models/edge_voice.dart';

void main() {
  group('EdgeVoice', () {
    test('fromJson creates correct instance from valid JSON', () {
      final json = {
        'Name': 'Microsoft Server Speech Text to Speech Voice (zh-CN, XiaoxiaoNeural)',
        'ShortName': 'zh-CN-XiaoxiaoNeural',
        'Gender': 'Female',
        'Locale': 'zh-CN',
        'FriendlyName': 'Microsoft Xiaoxiao Online (Natural) - Chinese (Mainland)',
        'Status': 'GA',
      };

      final voice = EdgeVoice.fromJson(json);

      expect(voice.name, 'Microsoft Server Speech Text to Speech Voice (zh-CN, XiaoxiaoNeural)');
      expect(voice.shortName, 'zh-CN-XiaoxiaoNeural');
      expect(voice.gender, 'Female');
      expect(voice.locale, 'zh-CN');
      expect(voice.friendlyName, 'Microsoft Xiaoxiao Online (Natural) - Chinese (Mainland)');
      expect(voice.status, 'GA');
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};
      final voice = EdgeVoice.fromJson(json);

      expect(voice.name, '');
      expect(voice.shortName, '');
      expect(voice.gender, '');
      expect(voice.locale, '');
      expect(voice.friendlyName, '');
      expect(voice.status, '');
    });
  });
}
