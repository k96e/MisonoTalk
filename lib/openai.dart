import 'dart:convert';
import 'package:eventflux/eventflux.dart';

String removeTailSlash(String input) {
  return input.trimRight().endsWith('/')
      ? input.trimRight().substring(0, input.trimRight().length - 1)
      : input.trimRight();
}

Future<void> completion(List<String> config, List<List<String>> message,
    Function onEevent, Function onDone, Function onErr) async {
  EventFlux.instance.connect(EventFluxConnectionType.post,
      "${removeTailSlash(config[1])}/chat/completions",
      header: {
        'Authorization': 'Bearer ${config[2]}',
        'Content-Type': 'application/json',
      },
      body: {
        'model': config[3],
        'messages':
            message.map((e) => {'role': e[0], 'content': e[1]}).toList(),
        'stream': true,
      },
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
