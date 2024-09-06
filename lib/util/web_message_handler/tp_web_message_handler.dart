import 'dart:async';

import 'package:town_pass/service/account_service.dart';
import 'package:town_pass/service/device_service.dart';
import 'package:town_pass/service/geo_locator_service.dart';
import 'package:town_pass/util/tp_route.dart';
import 'package:town_pass/util/web_message_handler/tp_web_message_reply.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class TPWebMessageHandler {
  String get name;

  Future<void> handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage replyWebMessage)? onReply,
  });

  WebMessage replyWebMessage({required Object data}) {
    return TPWebStringMessageReply(
      name: name,
      data: data,
    ).message;
  }
}

class UserinfoWebMessageHandler extends TPWebMessageHandler {
  @override
  String get name => 'userinfo';

  @override
  Future<void> handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required onReply,
  }) async {
    onReply?.call(replyWebMessage(
      data: Get.find<AccountService>().account ?? [],
    ));
  }
}

class LaunchMapWebMessageHandler extends TPWebMessageHandler {
  @override
  String get name => 'launch_map';

  @override
  handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage reply)? onReply,
  }) async {
    if (message == null) {
      onReply?.call(
        replyWebMessage(data: false),
      );
    }
    final Uri uri = Uri.parse(message!);
    final bool canLaunch = await canLaunchUrl(uri);

    onReply?.call(
      replyWebMessage(data: canLaunch),
    );

    if (canLaunch) {
      await launchUrl(uri);
    }
  }
}

class PhoneCallMessageHandler extends TPWebMessageHandler {
  @override
  String get name => 'phone_call';

  @override
  handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage reply)? onReply,
  }) async {
    if (message == null) {
      onReply?.call(
        replyWebMessage(data: false),
      );
    }
    final Uri uri = Uri.parse('tel://${message!}');
    final bool canLaunch = await canLaunchUrl(uri);

    onReply?.call(
      replyWebMessage(data: canLaunch),
    );

    if (canLaunch) {
      await launchUrl(uri);
    }
  }
}

class LocationMessageHandler extends TPWebMessageHandler {
  @override
  String get name => 'location';

  @override
  handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage reply)? onReply,
  }) async {
    Position? position;

    // might have permission issue
    try {
      position = await Get.find<GeoLocatorService>().position();
    } catch (error) {
      printError(info: error.toString());
    }

    onReply?.call(replyWebMessage(
      data: position?.toJson() ?? [],
    ));
  }
}

class DeviceInfoMessageHandler extends TPWebMessageHandler {
  @override
  String get name => 'deviceinfo';

  @override
  handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage reply)? onReply,
  }) async {
    onReply?.call(replyWebMessage(
      data: Get.find<DeviceService>().baseDeviceInfo?.data ?? [],
    ));
  }
}

class OpenLinkMessageHandler extends TPWebMessageHandler {
  @override
  String get name => 'open_link';

  @override
  handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage reply)? onReply,
  }) async {
    if (message == null) {
      onReply?.call(replyWebMessage(data: false));
      return;
    }
    await Get.toNamed(
      TPRoute.webView,
      arguments: message,
    );
  }
}

class VoiceRecordMessageHandler extends TPWebMessageHandler {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  String _lastWords = '';
  String _returnText = '';

  VoiceRecordMessageHandler() {
    _initSpeech(); // Call it in the constructor
    _startListening();
    _stopListening();
  }

  @override
  String get name => 'voice_record';

  /// This has to happen only once per app
  void _initSpeech() async {
    await _speechToText.initialize();
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    // print(result.recognizedWords);
    _lastWords = result.recognizedWords;
    _returnText = _returnText + _lastWords;
  }

  @override
  handle({
    required String? message,
    required WebUri? sourceOrigin,
    required bool isMainFrame,
    required Function(WebMessage reply)? onReply,
  }) async {
    // print(message);
    if (message == 'start') {
      _startListening();
    }
    else if (message == 'stop') {
      _stopListening();
      onReply?.call(replyWebMessage(data: _returnText));
    }
    else {
      // print('message unknown');
      return;
    }
  }
}