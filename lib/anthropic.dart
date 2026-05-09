import 'dart:convert';
import 'package:eventflux/eventflux.dart';
import 'utils.dart' show Config, removeTailSlash;

/// Ensures messages alternate user/assistant, merging consecutive same-role messages.
/// Extracts system messages to a separate list.
(List<String> systemPrompts, List<List<String>> prepareMessages) splitAndAlternate(
    List<List<String>> messages) {
  List<String> systemPrompts = [];
  List<List<String>> rest = [];
  for (var msg in messages) {
    if (msg[0] == "system") {
      systemPrompts.add(msg[1]);
    } else {
      rest.add(msg);
    }
  }
  if (rest.isEmpty) return (systemPrompts, []);

  List<List<String>> result = [];
  List<String> current = [rest[0][0], rest[0][1]];
  for (int i = 1; i < rest.length; i++) {
    if (rest[i][0] == current[0]) {
      current[1] += '\n${rest[i][1]}';
    } else {
      result.add(current);
      current = [rest[i][0], rest[i][1]];
    }
  }
  result.add(current);

  // Anthropic requires first message to be 'user'
  if (result.isNotEmpty && result[0][0] != "user") {
    result.insert(0, ["user", "..."]);
  }

  return (systemPrompts, result);
}

Future<void> completion(Config config, List<List<String>> message,
    Function(String) onEvent,
    Function() onDone,
    Function(String) onErr,
    {Function(Map<String, dynamic>)? onUsage}) async {

  var (systemPrompts, messages) = splitAndAlternate(message);

  Map<String, dynamic> data = {
    'model': config.model,
    "cache_control": {"type": "ephemeral"},
    'max_tokens': int.tryParse(config.maxTokens ?? '') ?? 4096,
    'stream': true,
    if (systemPrompts.isNotEmpty)
      'system': systemPrompts.join('\n'),
    'messages': messages.map((e) => {'role': e[0], 'content': e[1]}).toList(),
    if (config.temperature != null && double.tryParse(config.temperature!) != null)
      'temperature': double.parse(config.temperature!),
  };

  bool isThinking = false;
  bool hasContent = false;

  EventFlux.instance.connect(EventFluxConnectionType.post,
    "${removeTailSlash(config.baseUrl)}/messages",
    header: {
      'x-api-key': config.apiKey,
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
      'User-Agent': 'MisonoTalk/beta',
    },
    body: data,
    onSuccessCallback: (EventFluxResponse? response) {
      response?.stream?.listen((data) {
        try {
          var decoded = jsonDecode(data.data);
          final type = decoded["type"] as String?;

          if (type == "content_block_start") {
            final block = decoded["content_block"];
            if (block["type"] == "thinking") {
              isThinking = true;
              onEvent('<think>');
            }
            return;
          }

          if (type == "content_block_delta") {
            final delta = decoded["delta"];
            final deltaType = delta["type"] as String?;
            if (deltaType == "thinking_delta") {
              onEvent(delta["thinking"] ?? '');
              return;
            }
            if (deltaType == "text_delta") {
              if (isThinking) {
                isThinking = false;
                onEvent('</think>');
              }
              hasContent = true;
              onEvent(delta["text"] ?? '');
              return;
            }
          }

          if (type == "content_block_stop") {
            return;
          }

          if (type == "message_stop") {
            return;
          }

          if (type == "message_delta") {
            if (decoded.containsKey("usage")) {
              onUsage?.call(Map<String, dynamic>.from(decoded["usage"]));
            }
            return;
          }

          if (type == "error") {
            final err = decoded["error"];
            onErr("${err["type"]}: ${err["message"]}");
            return;
          }
        } catch (e) {
          if (data.data.contains("DONE")) {
            // stream ended
          } else if (e is FormatException) {
            if (data.data.isNotEmpty) {
              onErr("Unexpected response: \n${data.data}");
            }
          } else {
            onErr(e.toString());
          }
        }
      });
    },
    onConnectionClose: () {
      if (hasContent) {
        onDone();
      } else {
        onErr("Server response is empty");
      }
    },
    onError: (oops) => onErr(oops.message ?? "no message"),
  );
}
