// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'storage.dart';
import 'prompteditor.dart';
import 'utils.dart' show snackBarAlert, Config, DecimalTextInputFormatter, removeTailSlash;

class ConfigPage extends StatefulWidget {
  final Function(Config) updateFunc;
  final Config currentConfig;
  const ConfigPage({super.key, required this.updateFunc, required this.currentConfig});

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends State<ConfigPage> {
  String? selectedConfig;
  List<Config> apiConfigs = [];
  final storage = StorageService();
  TextEditingController nameController = TextEditingController();
  TextEditingController urlController = TextEditingController();
  TextEditingController keyController = TextEditingController();
  TextEditingController modelController = TextEditingController();
  TextEditingController temperatureController = TextEditingController();
  TextEditingController frequencyPenaltyController = TextEditingController();
  TextEditingController presencePenaltyController = TextEditingController();
  TextEditingController maxTokensController = TextEditingController();

  @override
  void initState() {
    super.initState();
    storage.getApiConfigs().then((List<Config> value) {
      setState(() {
        apiConfigs = value;
        for (Config c in apiConfigs) {
          if (c.name == widget.currentConfig.name) {
            selectedConfig = c.name;
            break;
          }
        }
        nameController.text = widget.currentConfig.name;
        urlController.text = widget.currentConfig.baseUrl;
        keyController.text = widget.currentConfig.apiKey;
        modelController.text = widget.currentConfig.model;
        temperatureController.text = widget.currentConfig.temperature ?? "";
        frequencyPenaltyController.text = widget.currentConfig.frequencyPenalty ?? "";
        presencePenaltyController.text = widget.currentConfig.presencePenalty ?? "";
        maxTokensController.text = widget.currentConfig.maxTokens ?? "";
      });
    });
  }

  void qrShare(){
    Map<String, String> message = {
      'name': nameController.text,
      'baseUrl': urlController.text,
      'apiKey': keyController.text,
      'model': modelController.text,
    };
    String jsonString = jsonEncode(message);
    String encoded = base64.encode(utf8.encode(jsonString));
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        content: SizedBox(
          width: 500,
          child: QrImageView(
            backgroundColor: Colors.white,
            data: "misonotalk://?c=$encoded",
          ),
        )
      );
    });
  }

  Widget selectPopup(BuildContext context, List<List<String>> items) {
  return SizedBox(
    height: MediaQuery.of(context).size.height*0.8,
    width: MediaQuery.of(context).size.width*0.8,
    child: ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            title: Text(items[index][0]),
            subtitle: Text(items[index][1]),
            onTap: () {
              setState(() {
                modelController.text = items[index][0];
              });
              Navigator.pop(context);
            },
          )
        );
      },
    )
  );
  }

  Future<void> selectModelFromAPI(BuildContext context) async {
    String baseUrl = removeTailSlash(urlController.text);
    String apiKey = keyController.text;
    
    if (baseUrl.isEmpty) {
      snackBarAlert(context, "no baseurl");
      return;
    }
    
    late BuildContext dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogContext = context;
        return AlertDialog(
          title: const Text('选择模型'),
          content: const SizedBox(
            height: 80,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...')
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    
    try {
      final dio = Dio();
      dio.options.headers["Accept"] = "application/json";
      dio.options.headers["Authorization"] = "Bearer $apiKey";
      dio.options.sendTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      dio.options.connectTimeout = const Duration(seconds: 10);
      final resp = await dio.get("$baseUrl/models");
      
      List<List<String>> models = [];
      for (var model in resp.data["data"]) {
        models.add([model["id"], model["owned_by"]]);
      }
      Navigator.of(dialogContext).pop();
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('选择模型'),
            content: selectPopup(context, models),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      Navigator.of(dialogContext).pop();
      snackBarAlert(context, e.toString());
    }
  }

  Future<void> deleteConfirm(BuildContext context, String config) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('您确定要删除 "$config" 吗？'),
                const Text('此操作无法撤销。'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('删除'),
              onPressed: () {
                setState(() {
                  for (Config c in apiConfigs) {
                    if (c.name == config) {
                      storage.deleteApiConfig(config);
                      apiConfigs.remove(c);
                      if (selectedConfig == config) {
                        if (apiConfigs.isNotEmpty) {
                          selectedConfig = apiConfigs[0].name;
                        }
                      }
                      break;
                    }
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: 
        SingleChildScrollView(child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<String>(
                  value: selectedConfig,
                  hint: const Text('选择配置'),
                  //isExpanded: true,
                  items: apiConfigs.map((Config config) {
                    return DropdownMenuItem<String>(
                      value: config.name,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(config.name),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              deleteConfirm(context, config.name);
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedConfig = newValue;
                      for (Config c in apiConfigs) {
                        if (c.name == newValue) {
                          nameController.text = c.name;
                          urlController.text = c.baseUrl;
                          keyController.text = c.apiKey;
                          modelController.text = c.model;
                          temperatureController.text = c.temperature ?? "";
                          frequencyPenaltyController.text = c.frequencyPenalty ?? "";
                          presencePenaltyController.text = c.presencePenalty ?? "";
                          maxTokensController.text = c.maxTokens ?? "";
                          widget.updateFunc(c);
                          break;
                        }
                      }
                    });
                    storage.setCurrentApiConfig(selectedConfig!);
                  },
                ),
                const SizedBox(width: 10),
                IconButton(onPressed: qrShare, icon: const Icon(Icons.qr_code)),
              ]
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'base url'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: 'api key'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'model'),
                )),
                IconButton(onPressed: (){
                    selectModelFromAPI(context);
                  }, 
                  icon: const Icon(Icons.search)
                ),
              ]
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: temperatureController,
                    decoration: const InputDecoration(labelText: 'temperature'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: frequencyPenaltyController,
                    decoration: const InputDecoration(labelText: 'frequency penalty'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: presencePenaltyController,
                    decoration: const InputDecoration(labelText: 'presence penalty'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter()],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: maxTokensController,
                    decoration: const InputDecoration(labelText: 'max tokens'),
                    keyboardType: const TextInputType.numberWithOptions(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: const Text('清空'),
                  onPressed: () {
                    setState(() {
                      nameController.clear();
                      urlController.clear();
                      keyController.clear();
                      modelController.clear();
                      temperatureController.clear();
                      frequencyPenaltyController.clear();
                      presencePenaltyController.clear();
                      maxTokensController.clear();
                    });
                  },
                ),
                ElevatedButton(
                  child: const Text('保存'),
                  onPressed: () {
                    if (nameController.text.isEmpty ||
                        urlController.text.isEmpty ||
                        keyController.text.isEmpty ||
                        modelController.text.isEmpty) {
                      snackBarAlert(context, "请填写所有字段");
                    } else {
                      if (apiConfigs.isNotEmpty) {
                        for (Config c in apiConfigs) {
                          if (c.name == nameController.text) {
                            snackBarAlert(context, "名称重复");
                            return;
                          }
                        }
                      }
                      Config newConfig = Config(
                        name: nameController.text,
                        baseUrl: urlController.text,
                        apiKey: keyController.text,
                        model: modelController.text,
                        temperature: temperatureController.text.isEmpty
                            ? null
                            : temperatureController.text,
                        frequencyPenalty: frequencyPenaltyController.text.isEmpty
                            ? null
                            : frequencyPenaltyController.text,
                        presencePenalty: presencePenaltyController.text.isEmpty
                            ? null
                            : presencePenaltyController.text,
                        maxTokens: maxTokensController.text.isEmpty
                            ? null
                            : maxTokensController.text,
                      );
                      storage.setApiConfig(newConfig);
                      storage.setCurrentApiConfig(nameController.text);
                      setState(() {
                        apiConfigs.add(newConfig);
                        selectedConfig = nameController.text;
                      });
                      snackBarAlert(context, "保存成功");
                    }
                  },
                ),
                ElevatedButton(
                  child: const Text("确定"),
                  onPressed: () {
                    widget.updateFunc(Config(
                      name: nameController.text,
                      baseUrl: urlController.text,
                      apiKey: keyController.text,
                      model: modelController.text,
                      temperature: temperatureController.text.isEmpty
                          ? null
                          : temperatureController.text,
                      frequencyPenalty: frequencyPenaltyController.text.isEmpty
                          ? null
                          : frequencyPenaltyController.text,
                      presencePenalty: presencePenaltyController.text.isEmpty
                          ? null
                          : presencePenaltyController.text,
                      maxTokens: maxTokensController.text.isEmpty
                          ? null
                          : maxTokensController.text,
                    ));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: const Text('编辑Prompt'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PromptEditor()),
                    );
                  },
                ),
                ElevatedButton(
                  child: const Text('备份'),
                  onPressed: () async {
                    String j = await storage.convertToJson();
                    debugPrint(j);
                    if(await storage.writeFile(j)){
                      snackBarAlert(context, "备份成功");
                    } else {
                      snackBarAlert(context, "备份失败");
                    }
                  },
                ),
                ElevatedButton(
                  child: const Text('恢复'),
                  onPressed: () async {
                    String? j = await storage.pickFile();
                    if (j != null) {
                      try {
                        debugPrint(j);
                        await storage.restoreFromJson(j);
                        snackBarAlert(context, "恢复成功");
                      } catch (e) {
                        snackBarAlert(context, "恢复失败");
                        return;
                      }
                    } else {
                      snackBarAlert(context, "未选择文件");
                    }
                  },
                ),
              ],
            ),
            const Center(child: Opacity(opacity: 0.3,child: Text("@k96e"))),
          ],
        ),
        )
      ),
    );
  }
}
