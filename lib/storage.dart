import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'utils.dart' show Config, SdConfig;

class StorageService {
  static final StorageService _instance = StorageService._internal();
  late SharedPreferences _prefs;

  StorageService._internal();

  factory StorageService() {
    return _instance;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // List 0:base_url 1:api_key 2:model_name 3:temperature 4:frequency_penalty 5:presence_penalty 6:max_tokens
  Future<void> setApiConfig(Config config) async {
    List<String> configList = [config.baseUrl,config.apiKey,config.model];
    if (config.temperature != null) {
      configList.add(config.temperature!);
    } else {
      configList.add('');
    }
    if (config.frequencyPenalty != null) {
      configList.add(config.frequencyPenalty!);
    } else {
      configList.add('');
    }
    if (config.presencePenalty != null) {
      configList.add(config.presencePenalty!);
    } else {
      configList.add('');
    }
    if (config.maxTokens != null) {
      configList.add(config.maxTokens!);
    } else {
      configList.add('');
    }
    await _prefs.setStringList("api_${config.name}", configList);
    debugPrint("set api ${config.name}: ${config.toString()}");
  }

  Future<void> setCurrentApiConfig(String name) async {
    await _prefs.setString("current_api", "api_$name");
    debugPrint("set current api $name");
  }

  Future<void> deleteApiConfig(String name) async {
    await _prefs.remove("api_$name");
    debugPrint("delete api $name");
  }

  Future<List<Config>> getApiConfigs() async {
    List<Config> configs = [];
    String current = _prefs.getString("current_api") ?? "";
    Set<String> keys = _prefs.getKeys();
    if (current.isNotEmpty) {
      if (_prefs.getStringList(current) == null) {
        await _prefs.remove("current_api");
      } else {
        List<String> currentConfig = _prefs.getStringList(current) ?? ['','','',''];
        if(currentConfig.length==3){
          configs.add(Config(name: current.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
            apiKey: currentConfig[1], model: currentConfig[2]));
        } else if(currentConfig.length==7){
          configs.add(Config(name: current.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
            apiKey: currentConfig[1], model: currentConfig[2], temperature: currentConfig[3],
            frequencyPenalty: currentConfig[4], presencePenalty: currentConfig[5], maxTokens: currentConfig[6]));
        }
      }
    }
    for (String key in keys) {
      if (key.startsWith("api_") && key != current) {
        List<String> currentConfig = _prefs.getStringList(key) ?? ['','','',''];
        if(currentConfig.length==3){
          configs.add(Config(name: key.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
            apiKey: currentConfig[1], model: currentConfig[2]));
        } else if(currentConfig.length==7){
          configs.add(Config(name: key.replaceFirst("api_", ""), baseUrl: currentConfig[0], 
            apiKey: currentConfig[1], model: currentConfig[2], temperature: currentConfig[3],
            frequencyPenalty: currentConfig[4], presencePenalty: currentConfig[5], maxTokens: currentConfig[6]));
        }
      }
    }
    // debugPrint("query api configs: ${configs.toString()}");
    return configs;
  }

  // 0:intro 1:timestamp 2:msg
  Future<List<List<String>>> getHistorys() async{
    List<List<String>> historys = [];
    Set<String> keys = _prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith("history_")) {
        String timeStamp = key.replaceFirst("history_", "");
        List<String> history = _prefs.getStringList(key) ?? ["",""];
        historys.add([history[0],timeStamp,history[1]]);
      }
    }
    return historys;
  }

  Future<void> addHistory(String msg,String name) async {
    String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
    await _prefs.setStringList("history_$timeStamp", [name,msg]);
  }

  void deleteHistory(String key) async {
    if (_prefs.containsKey(key)) {
      await _prefs.remove(key);
    } else {
      debugPrint("key not found: $key");
    }
  }

  void setTempHistory(String msg) async {
    await _prefs.setString("temp_history", msg);
  }

  Future<String?> getTempHistory() async {
    return _prefs.getString("temp_history");
  }

  Future<String> convertToJson() async {
    final keys = _prefs.getKeys();
    
    Map<String, dynamic> allPrefs = {};
    for (String key in keys) {
      allPrefs[key] = _prefs.get(key);
    }
    return jsonEncode(allPrefs);
  }

  Future<String> getPrompt({bool isDefault=false,bool isRaw=false,bool withExternal=false}) async {
    String? prompt = _prefs.getString("custom_prompt");
    if (prompt == null || prompt.length < 200 || isDefault) {
      prompt = await rootBundle.loadString('assets/prompt.txt');
    }
    if (isRaw) {
      return prompt;
    }
    String flag = "prompt_split";
    if (withExternal) {
      return prompt.replaceFirst(flag, "");
    }
    int ind = prompt.indexOf(flag);
    if (ind != -1) {
      prompt = prompt.substring(ind+flag.length);
    }
    return prompt.trimLeft();
  }

  Future<void> setPrompt(String prompt) async {
    await _prefs.setString("custom_prompt", prompt);
  }

  Future<List<String>> getWebdav() async {
    Set<String> keys = _prefs.getKeys();
    if (keys.contains("webdav")) {
      return _prefs.getStringList("webdav") ?? ["","",""];
    } else {
      return ["","",""];
    }
  }

  Future<void> setWebdav(String url, String username, String password) async {
    await _prefs.setStringList("webdav", [url,username,password]);
  }

  Future<void> setDrawUrl(String url) async {
    await _prefs.setString("draw_url", url);
  }

  Future<String?> getDrawUrl() async {
    return _prefs.getString("draw_url");
  }

  Future<void> setSdConfig(SdConfig config) async {
    List<String> configList = [config.prompt, config.negativePrompt, config.model, 
      config.sampler, config.width?.toString()??'', config.height?.toString()??'',
      config.steps?.toString()??'', config.cfg?.toString()??''];
    await _prefs.setStringList("sd_config", configList);
  }

  Future<SdConfig> getSdConfig() async {
    List<String> configList = _prefs.getStringList("sd_config") ?? ['','','','','','','',''];
    return SdConfig(prompt: configList[0], negativePrompt: configList[1], model: configList[2],
      sampler: configList[3], width: int.tryParse(configList[4]), height: int.tryParse(configList[5]),
      steps: int.tryParse(configList[6]), cfg: int.tryParse(configList[7]));
  }

  Future<void> restoreFromJson(jsonString) async {
    if (jsonString.isEmpty) return;

    Map<String, dynamic> allPrefs = jsonDecode(jsonString);

    for (String key in allPrefs.keys) {
      var value = allPrefs[key];
      if (value is String) {
        await _prefs.setString(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      } else if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is List) {
        await _prefs.setStringList(key, value.map((item) => item.toString()).toList());
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
}