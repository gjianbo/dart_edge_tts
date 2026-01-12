# Edge TTS for Dart/Flutter

A Flutter package for Microsoft Edge's online Text-to-Speech service. This package provides a simple interface to synthesize speech from text using high-quality neural voices available in Microsoft Edge.

## Features

*   **High Quality Voices**: Access to Microsoft's natural-sounding "Neural" voices.
*   **Simple API**: Easy-to-use methods for speaking text directly or saving to a file.
*   **SSML Support**: Custom SSML support for advanced speech control (pitch, rate, volume).
*   **Multi-language**: Supports all languages and voices available in Edge TTS.
*   **Audio Playback**: Integrated with `audioplayers` for immediate playback.

## Installation

Add this package to your `pubspec.yaml`.

Since this is currently a private/git package, you can add it via path (for local development) or git:

**Local Path:**
```yaml
dependencies:
  edge_tts_dart:
    path: ../packages/edge_tts_dart
```

**Git Dependency:**
```yaml
dependencies:
  edge_tts_dart:
    git:
      url: https://github.com/your_username/edge_tts_dart.git
      ref: main
```

## Usage

### 1. Initialization

Initialize the service. You can optionally specify default voice, rate, and pitch.

```dart
import 'package:edge_tts_dart/edge_tts_dart.dart';

final ttsService = EdgeTtsService(
  voice: 'zh-CN-XiaoxiaoNeural', // Default voice
  rate: 1.0,                     // 1.0 is normal speed
  pitch: 1.0,                    // 1.0 is normal pitch
);
```

### 2. Speak Text

Directly play the audio for the given text.

```dart
await ttsService.speak('你好，这是一个测试。');
```

### 3. Synthesize to File

Generate an MP3 file and get the file path.

```dart
String? filePath = await ttsService.synthesizeToFile('正在保存这段语音。');
if (filePath != null) {
  print('Audio saved to: $filePath');
}
```

### 4. Get Available Voices

Fetch the list of all available voices from the server.

```dart
try {
  List<EdgeVoice> voices = await ttsService.getVoices();
  for (var voice in voices) {
    print('${voice.friendlyName} - ${voice.shortName}');
  }
} catch (e) {
  print('Failed to load voices: $e');
}
```

### 5. Advanced: Speak Number Sequence

Useful for reading out numbers with specific intervals.

```dart
// Speak numbers 1, 2, 3 with 0.5s interval
await ttsService.speakNumberSequence([1, 2, 3], interval: 0.5);
```

### 6. Clean Up

Don't forget to dispose of the service when it's no longer needed to release audio resources.

```dart
ttsService.dispose();
```

## License

MIT
