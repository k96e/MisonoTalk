import 'dart:convert';
import 'package:eventflux/eventflux.dart';
import 'utils.dart' show Config;

String removeTailSlash(String input) {
  return input.trimRight().endsWith('/')
      ? input.trimRight().substring(0, input.trimRight().length - 1)
      : input.trimRight();
}

Future<void> completion(Config config, List<List<String>> message,
    Function onEevent, Function onDone, Function onErr) async {

  Map<String, dynamic> data = {
    'model': config.model,
    'messages':
        message.map((e) => {'role': e[0], 'content': e[1]}).toList(),
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
  // print(data);
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
            onEevent(json.decode(data.data)["choices"][0]["delta"]["content"]);
          } catch (e) {
            if (data.data.contains("DONE")) {
              onDone();
            } else if(e is FormatException) {
              onErr("Unexpected response: \n$data");
            }
          }
        });
      },
      onError: (oops) => onErr(oops.message));
}
