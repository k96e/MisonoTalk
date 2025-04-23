import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


// type 1:asstant 2:user 3:system 4:timestamp
class Message {
  String message;
  int type;
  bool isHide = false;
  String? reasoningContent;
  static const int assistant = 1;
  static const int user = 2;
  static const int system = 3;
  static const int timestamp = 4;
  static const int image = 5;

  Message({required this.message, required this.type, 
    this.isHide = false, this.reasoningContent});

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

  @override
  String toString() {
    return 'Message{message: $message, type: $type, isHide: $isHide}';
  }
}

List<Message> copyMsgs(List<Message> msgs) {
  List<Message> newMsgs = [];
  for (var m in msgs) {
    newMsgs.add(Message(message: m.message, type: m.type, 
      isHide: m.isHide, reasoningContent: m.reasoningContent));
  }
  return newMsgs;
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

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      name: json['name'],
      baseUrl: json['baseUrl'],
      apiKey: json['apiKey'],
      model: json['model']
    );
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

List<List<String>> parseMsg(String prompt, List<Message> messages, List<String> welcomeMsgs) {
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
      msg.add(["assistant",formatMsg(m.message,clearMiddle: true)]);
    } else if (m.type == Message.user) {
      msg.add(["user",m.message]);
    } else if (m.type == Message.system) {
      msg.add(["system",m.message]);
    } else if (m.type == Message.timestamp) {
      var timestr = timestampToSystemMsg(m.message);
      msg.add(["system","下面的对话开始于$timestr"]);
    }
  }
  bool multipleAssistantMsgs = msg.where((m) => m[0] == "assistant").length > 1;
  if (multipleAssistantMsgs && msg.length > 1 && msg[1][0] == "assistant" && 
      welcomeMsgs.contains(msg[1][1])) {
    msg.removeAt(1);
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

String removeTailSlash(String input) {
  return input.trimRight().endsWith('/')
      ? input.trimRight().substring(0, input.trimRight().length - 1)
      : input.trimRight();
}

String formatMsg(String input, {bool clearMiddle = false}) {
  final reasonReg = RegExp(r'<think>(.{0,5})</think>');
  reasonReg.allMatches(input).forEach((match) {
    input = input.replaceRange(match.start, match.end, '');
  });
  if (clearMiddle) {
    input = input.replaceAll(RegExp(r'\\+'), '\\');
  }
  return input.replaceAll(RegExp(r'^\\+|\\+$'), '');
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

Widget msgsListWidget(BuildContext context, String jsonMessages, {bool isReverse = true}) {
  List<Message> messages;
  try{
    messages = jsonToMsg(jsonMessages);
  } catch (e) {
    return SingleChildScrollView(
      child: Text("$e\n$jsonMessages"),
    );
  }
  if(isReverse) {
    messages = messages.reversed.toList();
  }
  return SizedBox(
    height: MediaQuery.of(context).size.height*0.8,
    width: MediaQuery.of(context).size.width*0.8,
    child:ListView.builder(
      itemCount: messages.length,
      reverse: isReverse,
      itemBuilder: (context, index) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              messages[index].type==Message.timestamp ? 
                timestampToSystemMsg(messages[index].message) : messages[index].message,
              style: messages[index].type==Message.assistant ? 
                const TextStyle(color: Color(0xff1a85ff)) : null,
            ),
          )
        );
      },
    )
  );
}