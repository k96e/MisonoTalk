// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart';
import 'storage.dart';
import 'aesutil.dart' show AesUtil;
import 'utils.dart' show snackBarAlert,msgsListWidget;

class WebdavPage extends StatefulWidget {
  final String currentMessages;
  final Function(String) onRefresh;
  const WebdavPage({super.key, required this.currentMessages,required this.onRefresh});
  @override
  WebdavPageState createState() => WebdavPageState();
}

class WebdavPageState extends State<WebdavPage> {
  TextEditingController urlController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController encryptController = TextEditingController();
  final storage = StorageService();
  double progress = 0;
  List<List<String>> messageRecords = [];

  void errDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget configPopup(BuildContext context) {
    return AlertDialog(
      title: const Text('Webdav配置'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
            ),
          ),
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
          ),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
            ),
          ),
          TextField(
            controller: encryptController,
            decoration: const InputDecoration(
              labelText: 'Encrypt Key',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: testWebdav,
          child: const Text('测试'),
        ),
        TextButton(
          onPressed: () async {
            await storage.setWebdav(urlController.text, usernameController.text, passwordController.text);
            await storage.setEncryptKey(encryptController.text);
            if(!context.mounted) return;
            snackBarAlert(context, 'Saved');
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> testWebdav() async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      await client.ping();
      if(!context.mounted) return;
      snackBarAlert(context, "Ping OK");
    } catch (e) {
      errDialog(e.toString());
    }
  }

  Future<void> backupTemp() async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      String payload = widget.currentMessages;
      if (encryptController.text.isNotEmpty) {
        payload = "MMTENC:${AesUtil.encrypt(widget.currentMessages, encryptController.text)}";
      }
      Uint8List data = utf8.encode(payload);
      await client.write("momotalk/temp.json", data);
      if(!context.mounted) return;
      snackBarAlert(context, "Backup OK");
    } catch (e) {
      errDialog(e.toString());
    }
  }

  Future<void> restoreTemp() async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      setState(() {
        progress = 0;
      });
      List<int> data = await client.read("momotalk/temp.json",onProgress: (count, total) {
        setState(() {
          progress = count / total;
        });
      });
      String msg = utf8.decode(data);
      if(msg.startsWith("MMTENC:")){
        if(encryptController.text.isEmpty) {
          errDialog("no encrypt key set");
          return;
        }
        msg = AesUtil.decrypt(msg.replaceFirst("MMTENC:", ""), encryptController.text);
      }
      widget.onRefresh(msg);
      storage.setTempHistory(msg);
      if(!context.mounted) return;
      snackBarAlert(context, "Restore OK");
      Navigator.of(context).pop();
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains("Invalid or corrupted pad block")) {
        errMsg = "wrong encrypt key";
      }
      errDialog(errMsg);
    }
  }

  Future<void> backupCurrent({String? fileName}) async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      String payload = widget.currentMessages;
      if (encryptController.text.isNotEmpty) {
        payload = "MMTENC:${AesUtil.encrypt(widget.currentMessages, encryptController.text)}";
      }
      Uint8List data = utf8.encode(payload);
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        progress = 0;
      });
      await client.write(fileName==null?"momotalk/$timestamp.json":"momotalk/$fileName", data, onProgress: (count, total) {
        setState(() {
          progress = count / total;
        });
      },);
      if(fileName != null){
        for (int i = 0; i < messageRecords.length; i++) {
          if (messageRecords[i][1] == fileName) {
            messageRecords[i][2] = widget.currentMessages;
            break;
          }
        }
      }
      if(!context.mounted) return;
      snackBarAlert(context, "Backup OK");
    } catch (e) {
      errDialog(e.toString());
    }
  }

  Future<String> getContent(String name) async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      setState(() {
        progress = 0;
      });
      List<int> data = await client.read("momotalk/$name", onProgress: (count, total) {
        setState(() {
          progress = count / total;
        });
      });
      String msg = utf8.decode(data);
      if(msg.startsWith("MMTENC:")){
        if(encryptController.text.isEmpty) {
          errDialog("no encrypt key set");
          return "";
        }
        msg = "dec:${AesUtil.decrypt(msg.replaceFirst("MMTENC:", ""), encryptController.text)}";
      }
      return msg;
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains("Invalid or corrupted pad block")) {
        errMsg = "wrong encrypt key";
      }
      errDialog(errMsg);
      return "";
    }
  }

  Future<void> loadItem(int index) async {
    String loadedMessage = "";
    bool isEncrypted = false;
    if (messageRecords[index].length == 3 && messageRecords[index][2].isNotEmpty) {
      loadedMessage = messageRecords[index][2];
    } else{
      loadedMessage = await getContent(messageRecords[index][1]);
      if (loadedMessage.isEmpty) return;
      messageRecords[index][2] = loadedMessage;
    }
    if (loadedMessage.startsWith("dec:")) {
      loadedMessage = loadedMessage.replaceFirst("dec:", "");
      isEncrypted = true;
    }
    showDialog(context: context, builder: 
      (BuildContext context) {
        return AlertDialog(
          title: Text(isEncrypted ? "${messageRecords[index][0]} - 🔒":messageRecords[index][0]),
          content: msgsListWidget(context, loadedMessage, isReverse: false),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                widget.onRefresh(loadedMessage);
                Navigator.of(context).popUntil((route) => route.isFirst);
              }, 
              child: const Text('恢复')
            )
          ],
        );
      }
    );
  }
  
  Future<void> freshList() async {
    try {
      setState(() {
        messageRecords.clear();
      });
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      client.readDir("momotalk").then((list) {
        List<List<String>> records = [];
        for (var item in list) {
          if (item.name?.endsWith(".json") ?? false) {
            if (int.tryParse(item.name!.replaceAll(".json", ''))!=null) {
              int timestamp = int.parse(item.name!.replaceAll(".json", ''));
                DateTime t = DateTime.fromMillisecondsSinceEpoch(timestamp);
                const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
                var result =
                  "${t.year}年${t.month}月${t.day}日 星期${weekday[t.weekday]} "
                  "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}"
                  ":${t.second.toString().padLeft(2,'0')}";
                records.add([result,item.name!,""]);
            }
          }
        }
        records.sort((a, b) => b[1].compareTo(a[1]));
        setState(() {
          messageRecords = records;
        });
      });
    } catch (e) {
      errDialog(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    storage.getWebdav().then((webdav) {
      if (webdav[0].isNotEmpty) {
        setState(() {
          urlController.text = webdav[0];
          usernameController.text = webdav[1];
          passwordController.text = webdav[2];
        });
      }
    });
    storage.getEncryptKey().then((key) {
      encryptController.text = key;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Webdav'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(child: const Text('配置'), onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return configPopup(context);
                    }
                  );
                }),
                ElevatedButton(
                  onPressed: testWebdav, 
                  child: const Text('测试')),
                ElevatedButton(
                  onPressed: freshList,
                  child: const Text('刷新列表'),
                ),
              ]
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              semanticsLabel: 'Linear progress indicator',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => backupCurrent(),
                  child: const Text('备份当前'),
                ),
                ElevatedButton(
                  onPressed: () => backupTemp(),
                  child: const Text('临时备份'),
                ),
                ElevatedButton(
                  onPressed: () => restoreTemp(),
                  child: const Text('恢复临时'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: messageRecords.isEmpty ? const Center(child: Text('无记录')) :
                ListView.builder(
                  itemCount: messageRecords.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      child: ListTile(
                        title: Text(messageRecords[index][0]),
                        onTap: () => loadItem(index),
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("覆盖保存"),
                                content: const Text("使用当前记录覆盖该项？"),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      backupCurrent(fileName: messageRecords[index][1]);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              );
                            }
                          );
                        },
                      )
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}