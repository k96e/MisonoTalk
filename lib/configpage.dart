// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'storage.dart';
import 'prompteditor.dart';
import 'utils.dart' show snackBarAlert, Config, DecimalTextInputFormatter;

class ConfigPage extends StatefulWidget {
  final Function(Config) updateFunc;
  const ConfigPage({super.key, required this.updateFunc});

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends State<ConfigPage> {
  String? selectedConfig;
  List<Config> apiConfigs = [];
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
    getApiConfigs().then((List<Config> value) {
      setState(() {
        apiConfigs = value;
        if (apiConfigs.isNotEmpty) {
          selectedConfig = apiConfigs[0].name;
          nameController.text = apiConfigs[0].name;
          urlController.text = apiConfigs[0].baseUrl;
          keyController.text = apiConfigs[0].apiKey;
          modelController.text = apiConfigs[0].model;
          temperatureController.text = apiConfigs[0].temperature ?? "";
          frequencyPenaltyController.text = apiConfigs[0].frequencyPenalty ?? "";
          presencePenaltyController.text = apiConfigs[0].presencePenalty ?? "";
          maxTokensController.text = apiConfigs[0].maxTokens ?? "";
          widget.updateFunc(apiConfigs[0]);
        }
      });
    });
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
                      deleteApiConfig(config);
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
        child: Column(
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
                setCurrentApiConfig(selectedConfig!);
              },
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
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: 'model'),
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
                      setApiConfig(newConfig);
                      setCurrentApiConfig(nameController.text);
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
                    String j = await convertToJson();
                    debugPrint(j);
                    if(await writeFile(j)){
                      snackBarAlert(context, "备份成功");
                    } else {
                      snackBarAlert(context, "备份失败");
                    }
                  },
                ),
                ElevatedButton(
                  child: const Text('恢复'),
                  onPressed: () async {
                    String? j = await pickFile();
                    if (j != null) {
                      try {
                        debugPrint(j);
                        await restoreFromJson(j);
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
            const Spacer(),
            const Center(child: Opacity(opacity: 0.3,child: Text("@k96e"))),
          ],
        ),
      ),
    );
  }
}
