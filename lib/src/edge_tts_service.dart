import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'models/edge_voice.dart';

/// Edge TTS 服务
/// 
/// 基于 rany2/edge-tts 项目实现的 Dart 版本
class EdgeTtsService {
  // Constants from rany2/edge-tts
  static const String _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  
  static const String _voiceListBaseUrl = 'speech.platform.bing.com/consumer/speech/synthesize/readaloud';
  static const String _wssBaseUrl = 'speech.platform.bing.com/consumer/speech/synthesize/readaloud';

  static const String _voiceListUrl = 'https://$_voiceListBaseUrl/voices/list?trustedclienttoken=$_trustedClientToken';
  static const String _wssUrl = 'wss://$_wssBaseUrl/edge/v1?TrustedClientToken=$_trustedClientToken';

  static const Map<String, String> _baseHeaders = {
    'Sec-CH-UA': '" Not;A Brand";v="99", "Microsoft Edge";v="143", "Chromium";v="143"',
    'Sec-CH-UA-Mobile': '?0',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0',
    'Accept': '*/*',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  // Constants for Sec-MS-GEC generation
  static const int _winEpoch = 11644473600;

  final String defaultVoice;
  final double defaultRate;
  final double defaultPitch;

  EdgeTtsService({
    String voice = 'zh-CN-XiaoxiaoNeural',
    double rate = 1.0,
    double pitch = 1.0,
  }) : defaultVoice = voice,
       defaultRate = rate,
       defaultPitch = pitch;

  final AudioPlayer _player = AudioPlayer();

  /// 释放资源
  void dispose() {
    _player.dispose();
  }

  /// 朗读文本
  Future<void> speak(String text) async {
    try {
      await _player.stop();
      final filePath = await synthesizeToFile(text);
      if (filePath != null) {
        await _player.play(DeviceFileSource(filePath));
      }
    } catch (e) {
      // print('Speak error: $e');
    }
  }

  /// 朗读数字序列
  Future<void> speakNumberSequence(List<int> numbers, {double interval = 0.5}) async {
    for (var number in numbers) {
      await speak(number.toString());
      try {
        await _player.onPlayerComplete.first.timeout(const Duration(seconds: 3));
      } catch (e) {
        // Timeout or error, continue
      }
      
      if (interval > 0 && number != numbers.last) {
        await Future.delayed(Duration(milliseconds: (interval * 1000).toInt()));
      }
    }
  }

  /// 构建带停顿的 SSML
  String buildAuralSSML(List<String> parts, {int pauseMs = 500}) {
    final buffer = StringBuffer();
    // 使用 defaultVoice
    buffer.write('<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="en-US">');
    buffer.write('<voice name="$defaultVoice">');
    buffer.write('<prosody rate="${_convertRate(defaultRate)}" pitch="${_convertPitch(defaultPitch)}">');
    
    for (var i = 0; i < parts.length; i++) {
      buffer.write(parts[i]);
      if (i < parts.length - 1) {
        buffer.write('<break time="${pauseMs}ms"/>');
      }
    }
    
    buffer.write('</prosody>');
    buffer.write('</voice>');
    buffer.write('</speak>');
    return buffer.toString();
  }

  /// 合成音频并保存到文件
  Future<String?> synthesizeToFile(String text, {String? customSSML}) async {
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/edge_tts_$timestamp.mp3');
      final sink = file.openWrite();

      final stream = getAudioStream(text, customSSML: customSSML);
      
      await for (final chunk in stream) {
        sink.add(chunk);
      }
      
      await sink.flush();
      await sink.close();
      
      return file.path;
    } catch (e) {
      // print('Error saving TTS to file: $e');
      return null;
    }
  }

  /// 获取可用语音列表
  Future<List<EdgeVoice>> getVoices() async {
    try {
      final headers = Map<String, String>.from(_baseHeaders);
      headers['Authority'] = 'speech.platform.bing.com';
      
      final response = await http.get(Uri.parse(_voiceListUrl), headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => EdgeVoice.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load voices: ${response.statusCode}');
      }
    } catch (e) {
      //print('Error fetching voices: $e');
      rethrow;
    }
  }

  /// 生成音频并返回字节流
  /// 
  /// [text]: 要朗读的文本
  /// [voice]: 语音名称 (ShortName)，例如 "zh-CN-XiaoxiaoNeural"
  /// [rate]: 语速，例如 "+0%" 或 "0%"
  /// [volume]: 音量，例如 "+0%"
  /// [pitch]: 音调，例如 "+0Hz"
  Stream<Uint8List> getAudioStream(
    String text, {
    String? voice,
    String? rate,
    String volume = '+0%',
    String? pitch,
    String? customSSML,
  }) async* {
    final targetVoice = voice ?? defaultVoice;
    
    // Convert double defaults to string format if not provided
    final targetRate = rate ?? _convertRate(defaultRate);
    final targetPitch = pitch ?? _convertPitch(defaultPitch);

    final controller = StreamController<Uint8List>();
    
    try {
      // 1. 获取服务器时间并生成 Sec-MS-GEC
      final fetchedTime = await _getServerTime();
      final serverTime = fetchedTime ?? DateTime.now().toUtc();
      
      final secMsGec = _generateSecMsGec(_trustedClientToken, serverTime);
      final connectionId = _generateConnectionId();
      final muidStr = _generateMuid();
      
      // 2. 构建 WebSocket URL
      final url = '$_wssUrl&ConnectionId=$connectionId&Sec-MS-GEC=$secMsGec&Sec-MS-GEC-Version=1-143.0.3650.75';
      // print('WebSocket URL: $url');
      
      // 3. 连接 WebSocket
      // Python WSS headers do NOT include Sec-CH-UA or Sec-Fetch-*
      // Order matters? Aligning with Python implementation.
      final wsHeaders = <String, String>{
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
        'Sec-WebSocket-Version': '13',
        // 'User-Agent': _baseHeaders['User-Agent']!, // Handled by customClient to avoid appending
        'Accept-Encoding': 'gzip, deflate, br, zstd',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cookie': 'muid=$muidStr;',
      };
      // print('WS Headers: $wsHeaders');

      // Create custom HttpClient to ensure User-Agent is replaced, not appended.
      // Dart's default HttpClient appends headers if they exist, and sets a default User-Agent.
      final client = HttpClient();
      client.userAgent = _baseHeaders['User-Agent'];

      final ws = await WebSocket.connect(
        url,
        headers: wsHeaders,
        compression: CompressionOptions.compressionOff,
        customClient: client,
      );
      final channel = IOWebSocketChannel(ws);

      // 等待连接建立
      await channel.ready;

      // 4. 发送配置消息
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final configMsg = _buildMessage(
        {
          'X-Timestamp': timestamp,
          'Content-Type': 'application/json; charset=utf-8',
          'Path': 'speech.config',
        },
        json.encode({
          'context': {
            'synthesis': {
              'audio': {
                'metadataoptions': {
                  'sentenceBoundaryEnabled': 'false',
                  'wordBoundaryEnabled': 'false',
                },
                'outputFormat': 'audio-24khz-48kbitrate-mono-mp3',
              }
            }
          }
        }),
      );
      channel.sink.add(configMsg);

      // 5. 发送 SSML 消息
      final requestId = _generateMuid();
      final ssml = customSSML ?? _buildSsml(text, targetVoice, targetRate, volume, targetPitch);
      final ssmlMsg = _buildMessage(
        {
          'X-RequestId': requestId,
          'Content-Type': 'application/ssml+xml',
          'X-Timestamp': timestamp,
          'Path': 'ssml',
        },
        ssml,
      );
      channel.sink.add(ssmlMsg);

      // 6. 监听消息
      await for (final message in channel.stream) {
        if (message is String) {
          // 处理文本消息
          if (message.contains('Path:turn.end')) {
            // 结束
            break;
          }
        } else if (message is List<int>) {
          // 处理二进制消息
          final data = Uint8List.fromList(message);
          if (data.length < 2) continue;

          // 解析头部长度 (Big Endian)
          final headerLength = (data[0] << 8) | data[1];
          if (data.length < headerLength + 2) continue;

          final headerString = utf8.decode(data.sublist(2, 2 + headerLength));
          
          if (headerString.contains('Path:audio')) {
            // 提取音频数据
            final audioData = data.sublist(2 + headerLength);
            yield audioData;
          }
        }
      }

      await channel.sink.close(status.normalClosure);
    } catch (e) {
      // print('TTS Error: $e');
      rethrow;
    } finally {
      controller.close();
    }
  }

  String _convertRate(double rate) {
    final ratePct = ((rate - 1.0) * 100).toInt();
    return ratePct >= 0 ? '+$ratePct%' : '$ratePct%';
  }

  String _convertPitch(double pitch) {
    final pitchPct = ((pitch - 1.0) * 100).toInt();
    return pitchPct >= 0 ? '+$pitchPct%' : '$pitchPct%';
  }

  /// 构建消息
  String _buildMessage(Map<String, String> headers, String body) {
    final buffer = StringBuffer();
    headers.forEach((key, value) {
      buffer.write('$key:$value\r\n');
    });
    buffer.write('\r\n');
    buffer.write(body);
    return buffer.toString();
  }

  /// 构建 SSML
  String _buildSsml(String text, String voice, String rate, String volume, String pitch) {
    return '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">'
        '<voice name="$voice">'
        '<prosody pitch="$pitch" rate="$rate" volume="$volume">'
        '$text'
        '</prosody>'
        '</voice>'
        '</speak>';
  }

  /// 生成 MUID (UUID-like, Uppercase)
  String _generateMuid() {
    final random = Random();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  /// 生成 ConnectionId (UUID-like, Lowercase)
  String _generateConnectionId() {
    return const Uuid().v4().replaceAll('-', '');
  }

  /// 获取服务器时间
  Future<DateTime?> _getServerTime() async {
    try {
      final headers = Map<String, String>.from(_baseHeaders);
      headers['Authority'] = 'speech.platform.bing.com';

      // 使用 HEAD 请求减少流量，如果失败则尝试 GET
      // 注意：Python 实现中使用 GET，这里为了稳妥也用 GET，但只取 header
      final response = await http.get(Uri.parse(_voiceListUrl), headers: headers);
      // print('Server Time Response Status: ${response.statusCode}');
      final dateHeader = response.headers['date'];
      // print('Server Date Header: $dateHeader');
      
      if (dateHeader != null) {
        return HttpDate.parse(dateHeader);
      }
    } catch (e) {
      // print('Error fetching server time: $e');
    }
    return null;
  }

  /// 生成 Sec-MS-GEC Token
  String _generateSecMsGec(String trustedClientToken, DateTime serverTime) {
    // 1. Get timestamp in seconds (int)
    int seconds = serverTime.millisecondsSinceEpoch ~/ 1000;
    
    // 2. Add Windows Epoch difference
    seconds += _winEpoch;
    
    // 3. Round down to nearest 5 minutes (300 seconds)
    seconds -= seconds % 300;
    
    // 4. Convert to 100-nanosecond intervals
    // Use int (64-bit) which is sufficient for current timestamps (up to ~year 3000)
    int ticks = seconds * 10000000;
    
    // 5. Concatenate and Hash
    final strToHash = "$ticks$trustedClientToken";
    // print('Dart String to Hash: $strToHash');
    
    final bytes = ascii.encode(strToHash);
    final digest = sha256.convert(bytes);
    
    return digest.toString().toUpperCase();
  }
}
