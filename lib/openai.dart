import 'dart:convert';
import 'package:eventflux/eventflux.dart';
import 'utils.dart' show Config;

String removeTailSlash(String input) {
  return input.trimRight().endsWith('/')
      ? input.trimRight().substring(0, input.trimRight().length - 1)
      : input.trimRight();
}

List<List<String>> mergeMessages(List<List<String>> messages) {
  if (messages.isEmpty) return [];
  List<List<String>> result = [];
  List<String>? current = messages[0];
  for (int i = 1; i < messages.length; i++) {
    if (messages[i][0] == "system"){
      messages[i][0] = "user";
      messages[i][1] = "*${messages[i][1]}*";
    }
    if (messages[i][0] == current?[0]) {
      current?[1] += '\\${messages[i][1]}';
    } else {
      result.add(current!);
      current = messages[i];
    }
  }
  result.add(current!);
  if (result[1][0] == "assistant") {
    result.removeAt(1);
  }
  return result;
}

Future<void> completion(Config config, List<List<String>> message,
    Function(String) onEevent, 
    Function(String reasoningContent) onDone, 
    Function(String) onErr) async {
  if(config.model=='deepseek-reasoner'){
    message = mergeMessages(message);
  }
  Map<String, dynamic> data = {
    'model': config.model,
    'messages':
        message.asMap().map((index, e) {
          if (e[0]=="system" && config.model.contains("claude")) {
            return MapEntry(index, {'role': 'user', 'content': "system instruction:\n${e[1]}"});
          }
          return MapEntry(index, {'role': e[0], 'content': e[1]});
        }).values.toList(),
    'stream': true,
    if (config.temperature != null && double.tryParse(config.temperature!) != null) 
      'temperature': double.parse(config.temperature!),
    if (config.frequencyPenalty != null && double.tryParse(config.frequencyPenalty!) != null)
      'frequency_penalty': double.parse(config.frequencyPenalty!),
    if (config.presencePenalty != null && double.tryParse(config.presencePenalty!) != null)
      'presence_penalty': double.parse(config.presencePenalty!),
    if (config.maxTokens != null && int.tryParse(config.maxTokens!) != null)
      'max_tokens': int.parse(config.maxTokens!),
  };
  //print(data);
  String reasoningContent = '';
  EventFlux.instance.connect(EventFluxConnectionType.post,
    "${removeTailSlash(config.baseUrl)}/chat/completions",
    header: {
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
    },
    body: data,
    onSuccessCallback: (EventFluxResponse? response) {
      response?.stream?.listen((data) {
        try {
          var decoded = jsonDecode(data.data);
          if(config.model=="deepseek-reasoner"&&decoded["choices"][0]["delta"]["reasoning_content"]!=null){
            reasoningContent += decoded["choices"][0]["delta"]["reasoning_content"];
          }
          if (decoded["choices"][0]["delta"]["content"] != null) {
            onEevent(decoded["choices"][0]["delta"]["content"]);
          }
        } catch (e) {
          if (data.data.contains("DONE")) {
            // onDone(reasoningContent);
          } else if(e is FormatException) {
            if(data.data.isEmpty && config.model=="deepseek-reasoner"){
              // print("deepseek empty response");
            } else {
              onErr("Unexpected response: \n${data.data}");
            }
          } else{
            onErr(e.toString());
          }
        }
      });
    },
    onConnectionClose: () => onDone(reasoningContent),
    onError: (oops) => onErr(oops.message??"no message")
  );
}
