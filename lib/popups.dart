import 'package:flutter/material.dart';
import 'notifications.dart';
import 'dart:async' show Timer;
import 'utils.dart' show Config;
import 'storage.dart' show StorageService;
import 'avatars.dart';

Future<String> replaceStr(BuildContext context, String target) async {
  TextEditingController fromStr = TextEditingController(text: '');
  TextEditingController toStr = TextEditingController(text: '');
  var res = await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('替换'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromStr,
              decoration: const InputDecoration(labelText: '查找'),
            ),
            TextField(
              controller: toStr,
              decoration: const InputDecoration(labelText: '替换'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              String result = target.replaceAll(fromStr.text, toStr.text);
              if(fromStr.text=="~") result = target.replaceAll("～", toStr.text);
              Navigator.of(context).pop(result);
            },
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  if (res is String) {
    return res;
  } else {
    return target;
  }
}

void assistantPopup(BuildContext context, String msg, LongPressStartDetails details,
                    String stuName, Function(String) onEdited, String? reasoningContent) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  TextEditingController controller = TextEditingController(text: msg);
  msg = msg.replaceAll(":", "：");
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 2, child: Text('编辑')),
      const PopupMenuItem(value: 1, child: Text('创建通知')),
      if (msg.split("$stuName：").length > 3) 
        const PopupMenuItem(value: 3, child: Text('格式化')),
      if (reasoningContent != null)
        const PopupMenuItem(value: 4, child: Text('查看推理')),
    ],
  ).then((value) {
    if (value == 1) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: const Text('创建通知'),
          content: TextField(
            maxLines: null,
            minLines: 1,
            controller: controller,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final NotificationHelper notification = NotificationHelper();
                Future.delayed(const Duration(seconds: 5), () {
                  List<String> msgs = controller.text.split("\\");
                  int index = 0;
                  Timer.periodic(const Duration(milliseconds: 500), (timer) {
                    if (index < msgs.length) {
                      if (msgs[index].isNotEmpty) {
                        notification.showNotification(title: stuName, body: msgs[index]);
                      }
                      index++;
                    } else {
                      timer.cancel();
                    }
                  });
                });
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      });
    } else if (value == 2) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: const Text('编辑'),
          content: TextField(
            maxLines: null,
            minLines: 1,
            controller: controller,
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.clear();
              },
              child: const Text('清空'),
            ),
            TextButton(
              onPressed: () {
                replaceStr(context, controller.text).then((value) {
                  controller.text = value;
                });
              },
              child: const Text('替换'),
            ),
            TextButton(
              onPressed: () {
                onEdited(controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            )
          ],
        );
      });
    } else if (value == 3) {
      onEdited("FORMAT");
    } else if (value == 4) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: const Text('Reasoning Content'),
          content: SingleChildScrollView(
            child: Text(reasoningContent!),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            )
          ],
        );
      });
    }
  });
}

void userPopup(BuildContext context, String msg, LongPressStartDetails details, Function(String,bool) onEdited) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  TextEditingController controller = TextEditingController(text: msg);
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 1, child: Text('编辑')),
      const PopupMenuItem(value: 2, child: Text('重发'))
    ],
  ).then((value) {
    if (value == 1) {
      showDialog(context: context, builder: (context) {
        return AlertDialog(
          title: const Text('编辑'),
          content: TextField(
            maxLines: null,
            minLines: 1,
            controller: controller,
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.clear();
              },
              child: const Text('清空'),
            ),
            TextButton(
              onPressed: () {
                onEdited(controller.text, false);
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
            TextButton(
              onPressed: () {
                onEdited(controller.text, true);
                Navigator.of(context).pop();
              },
              child: const Text('确定并重发'),
            )
          ],
        );
      });
    } else if (value == 2) {
      onEdited(msg, true);
    }
  });
}

void systemPopup(BuildContext context, String msg, Function(String,bool) onEdited) {
  TextEditingController controller = TextEditingController(text: msg);
  showDialog(context: context, builder: (context) {
    return AlertDialog(
      title: const Text('编辑System Instruction'),
      content: TextField(
        maxLines: null,
        minLines: 1,
        controller: controller,
      ),
      actions: [
        TextButton(
          onPressed: () {
            controller.clear();
          },
          child: const Text('清空'),
        ),
        TextButton(
          onPressed: () {
            onEdited(controller.text,true);
            Navigator.of(context).pop();
          },
          child: const Text('确定并提交'),
        ),
        TextButton(
          onPressed: () {
            onEdited(controller.text,false);
            Navigator.of(context).pop();
          },
          child: const Text('确定'),
        )
      ],
    );
  });
}

// bool: true for transfer to system instruction, false for not
void timePopup(BuildContext context, int oldTime, LongPressStartDetails details, Function(bool,DateTime?) onEdited) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 1, child: Text('编辑')),
      const PopupMenuItem(value: 2, child: Text('转为系统指令'))
    ],
  ).then((value) {
    if (value == 1) {
      showDatePicker(
        context: context,
        initialDate: DateTime.fromMillisecondsSinceEpoch(oldTime),
        firstDate: DateTime(2021),
        lastDate: DateTime(2099),
      ).then((date) {
        if (date != null) {
          showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(oldTime)),
          ).then((time) {
            if (time != null) {
              DateTime newTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              onEdited(false, newTime);
            }
          });
        }
      });
    } else if (value == 2) {
      onEdited(true, null);
    }
  });
}

void imagePopup(BuildContext context, LongPressStartDetails details, Function(bool) onEdited) {
  final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(details.globalPosition.dx, details.globalPosition.dy, 0, 0),
    Offset.zero & overlay.size,
  );
  showMenu(
    context: context,
    position: position,
    items: [
      const PopupMenuItem(value: 1, child: Text('移除')),
      const PopupMenuItem(value: 2, child: Text('保存'))
    ],
  ).then((value) {
    if (value == 1) {
      onEdited(false);
    } else if (value == 2) {
      onEdited(true);
    }
  });
}


Future<Config?> quickSettingPopup(BuildContext context, RelativeRect position, 
    StorageService storage) async {
  List<Config> configs = await storage.getApiConfigs();
  if (!context.mounted) return null;
  return await showMenu(
    context: context,
    position: position,
    items: [
      for (var config in configs) 
        PopupMenuItem(value: config.name, child: Text(config.name))
    ],
  ).then((value) {
    for (var config in configs){
      if (value == config.name) {
        storage.setCurrentApiConfig(config.name);
        return config;
      }
    }
    return null;
  });
}

Future<Avatar?> logoPopup(BuildContext context, RelativeRect position) async {
  if (!context.mounted) return null;
  return await showMenu(
    context: context,
    position: position,
    items: AvatarManager().avatarList.map((avatar) {
      return PopupMenuItem(
        value: avatar,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(avatar.assetPath, width: 32, height: 32),
            ),
            const SizedBox(width: 8),
            Text(avatar.name),
          ],
        ),
      );
    }).toList(),
  ).then((value) {
    if (value is Avatar) {
      AvatarManager().avatarIndex = value.id;
      return value;
    }
    return null;
  });
}

Future<String?> addInstPopup(BuildContext context, String? currentInst) async {
  if (!context.mounted) return null;
  final value = await showDialog(
    context: context,
    builder: (context) {
      TextEditingController controller = TextEditingController(text: currentInst ?? '');
      bool isEnabled = true;
      if (currentInst != null && currentInst.startsWith("*off*")){
        isEnabled = false;
        controller.text = currentInst.replaceFirst("*off*", "");
      }
      return AlertDialog(
        title: const Text("AddInst"),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('启用'),
                  value: isEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      isEnabled = value;
                    });
                  },
                ),
                TextField(
                  controller: controller,
                  maxLines: null,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(isEnabled ? controller.text : "*off*${controller.text}");
            },
            child: const Text('保存'),
          ),
        ],
      );
    },
  );
  if (value is String) {
    return value;
  }
  return null;
}
