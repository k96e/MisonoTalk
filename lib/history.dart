import 'package:flutter/material.dart';
import 'storage.dart';
import 'openai.dart' show completion;
import 'utils.dart' show snackBarAlert, Config;
import 'msglist.dart' show msgsListWidget;

class HistoryPage extends StatefulWidget {
  final Function(String) updateFunc;
  const HistoryPage({super.key, required this.updateFunc});

  @override
  HistoryPageState createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  final storage = StorageService();
  List<List<String>> historys = [];
  @override
  void initState() {
    super.initState();
    storage.getHistorys().then((List<List<String>> results) {
      setState(() {
        historys = results;
        historys.sort((a, b) => int.parse(b[1]).compareTo(int.parse(a[1])));
      });
    });
  }

  String getTimeStr(int index){
    int timeStamp = int.parse(historys[index][1]);
    DateTime t = DateTime.fromMillisecondsSinceEpoch(timeStamp);
    const weekday = ["", "一", "二", "三", "四", "五", "六", "日"];
    return "${t.year}年${t.month}月${t.day}日星期${weekday[t.weekday]}"
        "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
        itemCount: historys.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text(getTimeStr(index)),
              subtitle: Text(historys[index][0]),
              isThreeLine: true,
              onTap: () {
                showDialog(context: context, builder: (context) => AlertDialog(
                  title: Text(getTimeStr(index)),
                  content: msgsListWidget(context,historys[index][2]),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.updateFunc(historys[index][2]);
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('恢复'),
                    ),
                  ],
                ));
              },
              onLongPress: () {
                showDialog(
                  context: context, builder: (context) => AlertDialog(
                    content: msgsListWidget(context, historys[index][2]),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: (){
                          showDialog(context: context, builder: (context) => AlertDialog(
                            title: const Text('删除'),
                            content: const Text('确认删除?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  storage.deleteHistory("history_${historys[index][1]}");
                                  setState(() {
                                    historys.removeAt(index);
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text('删除'),
                              ),
                            ],
                          )).then((value) async {
                            Navigator.pop(context);
                          });
                        },
                        child: const Text('删除'),
                      ),
                    ],
                  )
                );
              },
            ),
          );
        },
      )),
    );
  }
}

Future<String?> namingHistory(BuildContext context,String timeStr,Config config,
                              String stuName, List<List<String>> msg) async {
  return showDialog(context: context, builder: (context) {
    final TextEditingController controller = TextEditingController(text: timeStr);
    return AlertDialog(
      title: const Text('Save History'),
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
          onPressed: () async {
            msg.add(["system","上面的对话暂时结束，现在为了记住这次对话，你需要继续模仿$stuName的语气，用一句话总结该对话，不分隔句子或换行，尽量简短"]);
            String result = "";
            for (var m in msg) {
              debugPrint("${m[0]}: ${m[1]}");
            }
            debugPrint("model: ${config.model}");
            controller.text = "Generating...";
            await completion(config, msg, (chunk){
              result += chunk;
              controller.text = result;
            }, (){
              snackBarAlert(context, "完成");
              controller.text = result.split("</think>").last;
            }, (e){
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Error"),
                  content: Text(e.toString()),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            });
          },
          child: const Text('AI'),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isEmpty) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pop(controller.text);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  });
}