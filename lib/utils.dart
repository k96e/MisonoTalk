import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


// type 1:asstant 2:user 3:system 4:timestamp
class Message {
  String message;
  int type;
  bool isHide = false;
  static const int assistant = 1;
  static const int user = 2;
  static const int system = 3;
  static const int timestamp = 4;
  static const int image = 5;

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

class SdConfig {
  String prompt;
  String negativePrompt;
  String model;
  String sampler;
  int? width;
  int? height;
  int? steps;
  int? cfg;

  SdConfig({required this.prompt, required this.negativePrompt, required this.model, 
    required this.sampler, this.width, this.height, this.steps, this.cfg});
}

String msgListToJson(List<Message> messages) {
  List<Map<String, dynamic>> jsonList = messages.map((message) => message.toJson()).toList();
  return jsonEncode(jsonList);
}

List<Message> jsonToMsg(String jsonString) {
  List<dynamic> jsonList = jsonDecode(jsonString);
  return jsonList.map((json) => Message.fromJson(json)).toList();
}

String timestampToSystemMsg(String timestr) {
  DateTime t = DateTime.fromMillisecondsSinceEpoch(int.parse(timestr));
  const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
  var result =
      "${t.year}年${t.month}月${t.day}日星期${weekday[t.weekday]}"
      "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}";
  return "下面的对话开始于 $result";
}

List<List<String>> parseMsg(String prompt, List<Message> messages) {
  List<List<String>> msg = [];
  msg.add(["system",prompt]);
  bool hideFlag = false;
  for (var m in messages) {
    if(m.isHide){
      if(!hideFlag){
        msg.add(["system","此处部分对话已略过"]);
        hideFlag = true;
      }
      continue;
    }
    hideFlag = false;
    if (m.type == Message.assistant) {
      msg.add(["assistant",m.message.replaceAll("\\\\", "\\")]);
    } else if (m.type == Message.user) {
      msg.add(["user",m.message]);
    } else if (m.type == Message.system) {
      msg.add(["system",m.message]);
    } else if (m.type == Message.timestamp) {
      var timestr = timestampToSystemMsg(m.message);
      msg.add(["system","下面的对话开始于$timestr"]);
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

List<String> splitString(String input, List<String> patterns) {
  String var1 = patterns[0], var2 = patterns[1];
    List<String> result = [];
  int i = 0;
  while (i < input.length) {
    if (input.startsWith(var1, i)) {
      int nextIndex = input.indexOf(var2, i);
      if (nextIndex == -1) {
        result.add(input.substring(i));
        break;
      }
      result.add(input.substring(i, nextIndex));
      i = nextIndex;
    }
    else if (input.startsWith(var2, i)) {
      int nextIndex = input.indexOf(var1, i);
      if (nextIndex == -1) {
        result.add(input.substring(i));
        break;
      }
      result.add(input.substring(i, nextIndex));
      i = nextIndex;
    }
  }
  return result;
}

void snackBarAlert(BuildContext context, String msg) {
  if(!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(msg),
      showCloseIcon: true
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
