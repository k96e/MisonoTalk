import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:transparent_image/transparent_image.dart';
import 'dart:convert';

class AiDraw extends StatefulWidget {
  const AiDraw({super.key});

  @override
  AiDrawState createState() => AiDrawState();
}

class AiDrawState extends State<AiDraw>{
  TextEditingController logController = TextEditingController();
  String? imageUrl;

  Future<void> makeRequest() async {
    final dio = Dio(BaseOptions(baseUrl: "https://hf-proxy.k96e.workers.dev/"));
    final String sessionHash = const Uuid().v4();
    print(sessionHash);
    logController.text = '$sessionHash\n$logController.text';
    // Load model request
    await dio.post(
      "/queue/join",
      data: {
        "data": ["yodayo-ai/kivotos-xl-2.0", "None", "txt2img"],
        "fn_index": 12,
        "session_hash": sessionHash,
      },
    );

    // Load model queue
    final Response<ResponseBody> loadModelQueue = await dio.get<ResponseBody>(
      "/queue/data",
      queryParameters: {"session_hash": sessionHash},
      options: Options(responseType: ResponseType.stream),
    );

    // Process streaming data

    await for (var chunk in loadModelQueue.data!.stream) {
      logController.text = utf8.decode(chunk) + logController.text;
    }

    await dio.post(
      "/queue/join",
      data: {
        "data": [
          "1girl, mika (blue archive), misono mika, blue archive, hiten, masterpiece, best quality,1girl, library, selfie, winking, playful expression, smile, school uniform, pink hair, single side bun, blue hydrangea hair ornament, sunlight, bookshelf, study atmosphere, solo, looking at viewer, indoors",
          "nsfw, (low quality, worst quality:1.2), very displeasing, 3d, watermark, signatrue, ugly, poorly drawn",
          1,
          30,
          7,
          true,
          -1,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          null,
          0.33,
          "Euler a",
          1024,
          1024,
          "yodayo-ai/kivotos-xl-2.0",
          "vaes/sdxl_vae-fp16fix-c-1.1-b-0.5.safetensors",
          "txt2img",
          null,
          null,
          512,
          1024,
          null,
          null,
          null,
          0.55,
          100,
          200,
          0.1,
          0.1,
          1,
          0,
          1,
          false,
          "Classic",
          null,
          1.2,
          0,
          8,
          30,
          0.55,
          "Use same sampler",
          "",
          "",
          false,
          true,
          1,
          true,
          false,
          true,
          true,
          true,
          "./images",
          false,
          false,
          false,
          true,
          1,
          0.55,
          false,
          false,
          false,
          true,
          false,
          "Use same sampler",
          false,
          "",
          "",
          0.35,
          true,
          true,
          false,
          4,
          4,
          32,
          false,
          "",
          "",
          0.35,
          true,
          true,
          false,
          4,
          4,
          32,
          false,
          null,
          null,
          "plus_face",
          "original",
          0.7,
          null,
          null,
          "base",
          "style",
          0.7,
          0,
          false,
          false,
          59
        ],
        "fn_index": 13,
        "session_hash": sessionHash,
      },
    );

    // Inference queue
    final Response<ResponseBody> inferQueue = await dio.get<ResponseBody>(
      "/queue/data",
      queryParameters: {"session_hash": sessionHash},
      options: Options(responseType: ResponseType.stream),
    );
    String lastUrl = '';
    final regex = RegExp(r'"(https?://[^"]+)"');
    await for (var chunk in inferQueue.data!.stream) {
      String data = utf8.decode(chunk);
      logController.text = data + logController.text;
      final match = regex.firstMatch(data);
      if (match != null) {
        lastUrl = match.group(1)!;
      }
      if (data.contains('close_stream')) {
        if(!mounted) return;
        setState(() {
          imageUrl = lastUrl;
        });
        break;
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AiDraw'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
              onPressed: () {
                makeRequest();
              },
              child: const Text('Draw')),
          Expanded(
            child: imageUrl == null
                ? TextField(
                    controller: logController,
                    maxLines: null,
                  )
                : FadeInImage(placeholder: MemoryImage(kTransparentImage), image: NetworkImage(imageUrl!))
          ),
        ],
      ),
    );
  }
}
