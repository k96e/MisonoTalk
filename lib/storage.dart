import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

// List 0:base_url 1:api_key 2:model_name
Future<void> setApiConfig(String name,List<String> config) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setStringList("api_$name", config);
  debugPrint("set api $name: ${config.toString()}");
}

Future<void> setCurrentApiConfig(String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString("current_api", "api_$name");
  debugPrint("set current api $name");
}

Future<void> deleteApiConfig(String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove("api_$name");
  debugPrint("delete api $name");
}

Future<List<List<String>>> getApiConfigs() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<List<String>> configs = [];
  String current = prefs.getString("current_api") ?? "";
  Set<String> keys = prefs.getKeys();
  if (current.isNotEmpty) {
    if (prefs.getStringList(current) == null) {
      await prefs.remove("current_api");
    } else {
      configs.add([current.replaceFirst("api_", "")]+(prefs.getStringList(current) ?? ['','','','']));
    }
  }
  for (String key in keys) {
    if (key.startsWith("api_") && key != current) {
      configs.add([key.replaceFirst("api_", "")]+(prefs.getStringList(key) ?? ['','','','']));
    }
  }
  debugPrint("query api configs: ${configs.toString()}");
  return configs;
}

// 0:intro 1:timestamp 2:msg
Future<List<List<String>>> getHistorys() async{
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<List<String>> historys = [];
  Set<String> keys = prefs.getKeys();
  for (String key in keys) {
    if (key.startsWith("history_")) {
      String timeStamp = key.replaceFirst("history_", "");
      List<String> history = prefs.getStringList(key) ?? ["",""];
      historys.add([history[0],timeStamp,history[1]]);
    }
  }
  return historys;
}

Future<void> addHistory(String msg,String name) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
  await prefs.setStringList("history_$timeStamp", [name,msg]);
}

void deleteHistory(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey(key)) {
    await prefs.remove(key);
  } else {
    debugPrint("key not found: $key");
  }
}

Future<String> convertToJson() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  
  Map<String, dynamic> allPrefs = {};
  for (String key in keys) {
    allPrefs[key] = prefs.get(key);
  }
  return jsonEncode(allPrefs);
}

Future<void> restoreFromJson(jsonString) async {
  if (jsonString.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  Map<String, dynamic> allPrefs = jsonDecode(jsonString);

  for (String key in allPrefs.keys) {
    var value = allPrefs[key];
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, value.map((item) => item.toString()).toList());
    }
  }
}

Future<bool> writeFileAndroid(String data) async {
  var status = await Permission.manageExternalStorage.status;
  if (!status.isGranted) {
    status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      debugPrint('MANAGE_EXTERNAL_STORAGE permission denied');
      return false;
    }
  }
  try {
    String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    File file = File('/storage/emulated/0/Download/momoBackup_$timeStamp.json');
    await file.writeAsString(data);
    debugPrint('write file: ${file.path}');
    return true;
  } catch (e) {
    debugPrint('Error writing file: $e');
    return false;
  }
}

Future<bool> writeFileWindows(String data) async {
  try {
    Directory? directory = await getDownloadsDirectory();
    String path = directory?.path ?? '';
    String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    File file = File('$path/momoBackup_$timeStamp.json');
    await file.writeAsString(data);
    debugPrint('write file: ${file.path}');
    return true;
  } catch (e) {
    debugPrint('Error writing file: $e');
    return false;
  }
}

Future<bool> writeFile(String data) async {
  if (Platform.isAndroid) {
    return await writeFileAndroid(data);
  } else if (Platform.isWindows) {
    return await writeFileWindows(data);
  } else {
    debugPrint('Unsupported platform');
    return false;
  }
}

Future<String?> pickFile() async{
  FilePickerResult? result = await FilePicker.platform.pickFiles(type:FileType.custom, allowedExtensions: ['json']);
  if(result != null) {
    File file = File(result.files.single.path!);
    String content = await file.readAsString();
    return content;
  } else {
    return null;
  }
}