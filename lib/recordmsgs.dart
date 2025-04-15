import 'package:flutter/material.dart';
import 'utils.dart' show Message, jsonToMsg, msgsListWidget;
import 'storage.dart';

class RecordMsgs extends StatefulWidget {
  final List<String> msgs;
  final Function(String) updateMsg;
  final int promptLength;
  const RecordMsgs({super.key, required this.msgs, required this.updateMsg, required this.promptLength});

  @override
  RecordMsgsState createState() => RecordMsgsState();
}

class RecordMsgsState extends State<RecordMsgs> {
  final storage = StorageService();
  String desc = "";

  int wordCount(List<Message> msgs){
    if (msgs.isEmpty) return 0;
    return msgs.map((msg){
      switch(msg.type){
        case Message.user:
        case Message.assistant:
        case Message.system:
          return msg.message.length;
        case Message.timestamp:
          return 28;
        default:
          return 0;
      }
    }).reduce((a,b)=>a+b);
  }

  Future<void> countText() async {
    int count = 0;
    for (var msg in widget.msgs) {
      List<Message> record = jsonToMsg(msg);
      count += (wordCount(record)+widget.promptLength);
    }
    setState(() {
      desc = "共${widget.msgs.length}次请求, $count字";
    });
  }

  @override
  void initState() {
    countText();
    super.initState();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorded Messages'),
      ),
      body: Column(
        children: <Widget>[
          Center(
            child: Text(desc),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: widget.msgs.length,
              itemBuilder: (BuildContext context, int index) {
                List<Message> record = jsonToMsg(widget.msgs[index]);
                if(record.isEmpty) return const SizedBox.shrink();
                return Card(
                  child: ListTile(
                    title:Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if(record.length>1) 
                          Text(record[record.length-2].message, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if(record.length>1) const Divider(height: 2),
                        Text(record.last.message, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    onTap: () {
                      showDialog(context: context, builder: 
                        (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Content'),
                            content: msgsListWidget(context, widget.msgs[index]),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  widget.updateMsg(widget.msgs[index]);
                                  storage.setTempHistory(widget.msgs[index]);
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                }, 
                                child: const Text('确定')
                              )
                            ],
                          );
                        }
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}