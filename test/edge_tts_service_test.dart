import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edge_tts_dart/edge_tts_dart.dart';

void main() {
  group('EdgeTtsService', () {
    late EdgeTtsService service;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Mock AudioPlayers global channel
      const MethodChannel globalChannel = MethodChannel('xyz.luan/audioplayers.global');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        globalChannel,
        (MethodCall methodCall) async {
          return null;
        },
      );
      
      // Mock AudioPlayers instance channel
      const MethodChannel channel = MethodChannel('xyz.luan/audioplayers');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          return null;
        },
      );
      
      service = EdgeTtsService(
        voice: 'zh-CN-XiaoxiaoNeural',
        rate: 1.0,
        pitch: 1.0,
      );
    });
    
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        null,
      );
    });

    test('initializes with default values', () {
      final defaultService = EdgeTtsService();
      expect(defaultService.defaultVoice, 'zh-CN-XiaoxiaoNeural');
      expect(defaultService.defaultRate, 1.0);
      expect(defaultService.defaultPitch, 1.0);
    });

    test('initializes with custom values', () {
      final customService = EdgeTtsService(
        voice: 'en-US-AriaNeural',
        rate: 1.5,
        pitch: 0.5,
      );
      expect(customService.defaultVoice, 'en-US-AriaNeural');
      expect(customService.defaultRate, 1.5);
      expect(customService.defaultPitch, 0.5);
    });

    test('buildAuralSSML generates correct SSML structure', () {
      final parts = ['1', '2', '3'];
      final ssml = service.buildAuralSSML(parts, pauseMs: 500);

      expect(ssml, contains('<speak version="1.0"'));
      expect(ssml, contains('xml:lang="en-US"'));
      expect(ssml, contains('<voice name="zh-CN-XiaoxiaoNeural">'));
      
      // Default rate 1.0 -> +0%
      // Default pitch 1.0 -> +0%
      expect(ssml, contains('<prosody rate="+0%" pitch="+0%">'));
      
      expect(ssml, contains('1<break time="500ms"/>'));
      expect(ssml, contains('2<break time="500ms"/>'));
      expect(ssml, contains('3')); // Last one should not have break
      expect(ssml, isNot(contains('3<break time="500ms"/>')));
      
      expect(ssml, contains('</prosody>'));
      expect(ssml, contains('</voice>'));
      expect(ssml, contains('</speak>'));
    });

    test('buildAuralSSML handles custom pause duration', () {
      final parts = ['A', 'B'];
      final ssml = service.buildAuralSSML(parts, pauseMs: 1000);
      
      expect(ssml, contains('<break time="1000ms"/>'));
    });
  });
}
