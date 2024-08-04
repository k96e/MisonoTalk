// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'storage.dart';
import 'utils.dart' show snackBarAlert;

class ConfigPage extends StatefulWidget {
  final Function(List<String>) updateFunc;
  const ConfigPage({super.key, required this.updateFunc});

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends State<ConfigPage> {
  String? selectedConfig;
  List<List<String>> apiConfigs = [];
  TextEditingController nameController = TextEditingController();
  TextEditingController urlController = TextEditingController();
  TextEditingController keyController = TextEditingController();
  TextEditingController modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getApiConfigs().then((List<List<String>> value) {
      setState(() {
        apiConfigs = value;
        if (apiConfigs.isNotEmpty) {
          selectedConfig = apiConfigs[0][0];
          nameController.text = apiConfigs[0][0];
          urlController.text = apiConfigs[0][1];
          keyController.text = apiConfigs[0][2];
          modelController.text = apiConfigs[0][3];
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
                  for (List<String> c in apiConfigs) {
                    if (c[0] == config) {
                      deleteApiConfig(config);
                      apiConfigs.remove(c);
                      if (selectedConfig == config) {
                        if (apiConfigs.isNotEmpty) {
                          selectedConfig = apiConfigs[0][0];
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
              items: apiConfigs.map((List<String> config) {
                return DropdownMenuItem<String>(
                  value: config[0],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(config[0]),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          deleteConfirm(context, config[0]);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedConfig = newValue;
                  for (List<String> c in apiConfigs) {
                    if (c[0] == newValue) {
                      nameController.text = c[0];
                      urlController.text = c[1];
                      keyController.text = c[2];
                      modelController.text = c[3];
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
                        for (List<String> c in apiConfigs) {
                          if (c[0] == nameController.text) {
                            snackBarAlert(context, "名称重复");
                            return;
                          }
                        }
                      }
                      setApiConfig(
                        nameController.text,
                        [
                          urlController.text,
                          keyController.text,
                          modelController.text,
                        ],
                      );
                      setCurrentApiConfig(nameController.text);
                      setState(() {
                        apiConfigs.add([
                          nameController.text,
                          urlController.text,
                          keyController.text,
                          modelController.text
                        ]);
                        selectedConfig = nameController.text;
                      });
                    }
                  },
                ),
                ElevatedButton(
                  child: const Text("确定"),
                  onPressed: () {
                    widget.updateFunc([
                      nameController.text,
                      urlController.text,
                      keyController.text,
                      modelController.text,
                    ]);
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
