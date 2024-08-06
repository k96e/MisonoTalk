import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


// type 1:asstant 2:user 3:system 4:timestamp
class Message {
  String message;
  final int type;
  static const int assistant = 1;
  static const int user = 2;
  static const int system = 3;
  static const int timestamp = 4;

  Message({required this.message, required this.type});

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'type': type,
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      message: json['message'],
      type: json['type'],
    );
  }
}

class Config {
  String name;
  String baseUrl;
  String apiKey;
  String model;
  String? temperature;
  String? frequencyPenalty;
  String? presencePenalty;
  String? maxTokens;

  Config({required this.name, required this.baseUrl, 
    required this.apiKey, required this.model,
    this.temperature, this.frequencyPenalty, 
    this.presencePenalty, this.maxTokens});

  @override
  String toString() {
    return 'Config{name: $name, baseUrl: $baseUrl, apiKey: $apiKey, model: $model, '
    'temperature: $temperature, frequencyPenalty: $frequencyPenalty, '
    'presencePenalty: $presencePenalty, maxTokens: $maxTokens}';
  }
}

String msgListToJson(List<Message> messages) {
  List<Map<String, dynamic>> jsonList = messages.map((message) => message.toJson()).toList();
  return jsonEncode(jsonList);
}

List<Message> jsonToMsg(String jsonString) {
  List<dynamic> jsonList = jsonDecode(jsonString);
  return jsonList.map((json) => Message.fromJson(json)).toList();
}

List<List<String>> parseMsg(String prompt, List<Message> messages) {
  List<List<String>> msg = [];
  msg.add(["system",prompt]);
  for (var m in messages) {
    if (m.type == Message.assistant) {
      msg.add(["assistant",m.message.replaceAll("\\\\", "\\")]);
    } else if (m.type == Message.user) {
      msg.add(["user",m.message]);
    } else if (m.type == Message.system) {
      msg.add(["system",m.message]);
    } else if (m.type == Message.timestamp) {
      DateTime t = DateTime.fromMillisecondsSinceEpoch(int.parse(m.message));
      const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
      var timestr =
          "${t.year}年${t.month}月${t.day}日星期${weekday[t.weekday]}"
          "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}";
      msg.add(["system","下面的对话开始于 $timestr"]);
    }
  }
  return msg;
}

String randomizeBackslashes(String resp) {
  Random random = Random();
  StringBuffer result = StringBuffer();

  for (int i = 0; i < resp.length; i++) {
    if (resp[i] == '\\') {
      if (random.nextInt(3) == 0) {
        result.write('\\\\');
      } else {
        result.write('\\');
      }
    } else {
      result.write(resp[i]);
    }
  }

  return result.toString();
}

void snackBarAlert(BuildContext context, String msg) {
  if(!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(msg),
      showCloseIcon: true
    ),
  );
}

void errDialog(BuildContext context, String content) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Error"),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    if (newText.isEmpty || newText == '.') {
      return newValue;
    }
    final newDouble = double.tryParse(newText);
    if (newDouble == null) {
      return oldValue;
    }
    return newValue;
  }
}
