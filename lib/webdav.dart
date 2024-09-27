// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webdav_client/webdav_client.dart';
import 'storage.dart';
import 'utils.dart' show snackBarAlert;

class WebdavPage extends StatefulWidget {
  final Function(String) onRefresh;
  const WebdavPage({super.key, required this.onRefresh});
  @override
  WebdavPageState createState() => WebdavPageState();
}

class WebdavPageState extends State<WebdavPage> {
  TextEditingController urlController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

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

  void backupCurrent() {
    getTempHistory().then((msg) async {
      if(msg != null) {
        try {
          var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
          Uint8List data = utf8.encode(msg);
          await client.write("momotalk/temp.json", data);
          if(!context.mounted) return;
          snackBarAlert(context, "Backup OK");
        } catch (e) {
          errDialog(e.toString());
        }
      } else {
        if(!context.mounted) return;
        snackBarAlert(context, "No data to backup");
      }
    });
  }

  Future<void> restoreCurrent() async {
    try {
      var client = newClient(urlController.text, user: usernameController.text, password: passwordController.text);
      client.read("momotalk/temp.json").then((data) {
        String msg = utf8.decode(data);
        setTempHistory(msg);
        widget.onRefresh(msg);
        if(!context.mounted) return;
        snackBarAlert(context, "Restore OK");
      });
    } catch (e) {
      errDialog(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    getWebdav().then((webdav) {
      if (webdav[0].isNotEmpty) {
        setState(() {
          urlController.text = webdav[0];
          usernameController.text = webdav[1];
          passwordController.text = webdav[2];
        });
      }
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
        child: SingleChildScrollView(
          child: Column(
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(child: const Text('保存'), onPressed: () async {
                    await setWebdav(urlController.text, usernameController.text, passwordController.text);
                    if(!context.mounted) return;
                    snackBarAlert(context, 'Saved');
                  }),
                  ElevatedButton(onPressed: testWebdav, child: const Text('测试')),
                ]
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => backupCurrent(),
                    child: const Text('备份当前'),
                  ),
                  ElevatedButton(
                    onPressed: () => restoreCurrent(),
                    child: const Text('恢复当前'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}