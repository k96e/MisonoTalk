import 'dart:io' show Platform;

import 'package:flutter/material.dart';

Widget buttonItem(BuildContext context,Icon icon, String value, String desc, void Function(String value) onTap) {
  return Card(
    child: ListTile(
      leading: icon,
      title: Text(value),
      subtitle: Text(desc),
      onTap: () {
        Navigator.of(context).pop();
        onTap(value);
      },
    ),
  );
}

Widget mainPopup(BuildContext context,bool externalPrompt, bool inputLock, bool isOnTop, void Function(String value) onSelected) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = constraints.maxWidth / 2;
      final items = [
        if (inputLock)
          buttonItem(context, const Icon(Icons.stop_circle_outlined), "Stop", "停止响应", onSelected),
        buttonItem(context, const Icon(Icons.clear_all), "Clear", "清空对话记录", onSelected),
        buttonItem(context, const Icon(Icons.save), "Save", "保存对话记录", onSelected),
        buttonItem(context, const Icon(Icons.access_time), "Time", "插入当前时间", onSelected),
        buttonItem(context, const Icon(Icons.info_outline), "System", "插入系统提示词", onSelected),
        buttonItem(context, externalPrompt?const Icon(Icons.more):const Icon(Icons.more_outlined), 
          "ExtPrompt", "扩展提示词 ${externalPrompt ? "√" : "×"}", onSelected),
        buttonItem(context, const Icon(Icons.add_comment), "AddInst", "每轮对话末尾的附加指令", onSelected),
        buttonItem(context, const Icon(Icons.backup), "Backup", "WebDav备份", onSelected),
        buttonItem(context, const Icon(Icons.brush), "Draw", "AI 绘画...", onSelected),
        buttonItem(context, const Icon(Icons.history), "History", "本地历史记录", onSelected),
        buttonItem(context, const Icon(Icons.list_alt), "Records", "会话响应记录", onSelected),
        buttonItem(context, const Icon(Icons.message), "Msgs", "消息管理", onSelected),
        buttonItem(context, const Icon(Icons.settings), "Settings", "设置", onSelected),
        if (Platform.isWindows)
          buttonItem(context, isOnTop? const Icon(Icons.push_pin):const Icon(Icons.push_pin_outlined), 
            "OnTop", "窗口置顶 ${isOnTop ? "√" : "×"}", onSelected),
        if (Platform.isWindows)
          buttonItem(context, const Icon(Icons.exit_to_app), "Exit", "退出应用", onSelected),
      ];
      const int splitWidth = 340;
      return GridView.count(
        crossAxisCount: constraints.maxWidth > splitWidth ? 2 : 1,
        shrinkWrap: true,
        childAspectRatio: constraints.maxWidth>splitWidth?(itemWidth/80):(itemWidth/40),
        children: items,
      );
      
      /*SingleChildScrollView(
        child: Wrap(
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: item,
            );
          }).toList(),
        ),
      );*/
    },
  );
}