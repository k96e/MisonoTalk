import 'package:flutter/material.dart';
import 'dart:convert' show utf8;
import 'utils.dart' show Message, copyMsgs, msgListToJson;

class MsgEditor extends StatefulWidget {
  final List<Message> msgs;
  final int promptLength;
  const MsgEditor({super.key, required this.msgs, required this.promptLength});

  @override
  MsgEditorState createState() => MsgEditorState();
}

class MsgEditorState extends State<MsgEditor> {
  late List<bool> selected;
  late List<Message> msgs;
  int lastSwipe = -1;
  int hideLength = 0;
  int wordCount = 0;
  double fileSize = 0.0;

  @override
  void initState() {
    msgs = copyMsgs(widget.msgs);
    selected = List.filled(msgs.length, false, growable: true);
    for (Message msg in msgs) {
      if (msg.isHide) hideLength += msg.message.length;
    }
    calcWordCount();
    super.initState();
  }

  void calcWordCount(){
    if (msgs.isEmpty) wordCount = 0;
    wordCount = msgs.map((msg){
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
    int encodedLengh = utf8.encode(msgListToJson(msgs)).length+widget.promptLength+30;
    fileSize = encodedLengh*1.33/1024 - 6.18;
  }

  String typeDesc(int type){
    switch(type){
      case Message.user: return "U ";
      case Message.assistant: return "A ";
      case Message.system: return "S ";
      case Message.timestamp: return "T ";
      default: return "? ";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Msg Editor'),
      ),
      body: Column(
        children: <Widget>[
          Center(
            child: hideLength==0? Text('共${msgs.length}条消息, ${widget.promptLength+wordCount}字, 约${fileSize.toStringAsFixed(2)}KB')
              :Text('共${msgs.length}条消息, ${widget.promptLength+wordCount}字, '
                'hide后约${widget.promptLength+wordCount-hideLength+9}字')
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    lastSwipe = -1;
                    setState(() {
                      selected.fillRange(0, selected.length, false);
                    });
                  },
                  child: const Text('全不选'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      msgs.removeWhere((element) => selected[msgs.indexOf(element)]);
                      selected.removeWhere((element) => element);
                      lastSwipe = -1;
                      hideLength = 0;
                      for (Message msg in msgs) {
                        if (msg.isHide) hideLength += msg.message.length;
                      }
                      calcWordCount();
                    });
                  },
                  child: const Text('删除'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      hideLength = 0;
                      for (Message msg in msgs) {
                        if (selected[msgs.indexOf(msg)]){
                          msg.isHide = !msg.isHide;
                        }
                        if (msg.isHide) hideLength += msg.message.length;
                      }
                      selected.fillRange(0, selected.length, false);
                      lastSwipe = -1;
                    });
                  },
                  onLongPress: () {
                    setState(() {
                      for (Message msg in msgs) {
                        msg.isHide = false;
                      }
                    });
                  },
                  child: const Text('*Hide'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, msgs);
                  },
                  child: const Text('确认'),
                ),
              ],
            )
          ),
          Expanded(
            child: ListView.builder(
              itemCount: msgs.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  child: Card(
                    child: ListTile(
                      selected: selected[index],
                      title: Text((msgs[index].isHide?'*':'')+typeDesc(msgs[index].type)+msgs[index].message,
                        maxLines: 2, overflow: TextOverflow.ellipsis,),
                    ),
                  ),
                  onHorizontalDragEnd: (details) {
                    debugPrint(details.velocity.pixelsPerSecond.dx.toString());
                    if (details.velocity.pixelsPerSecond.dx != 0) {
                      if (lastSwipe != -1) {
                        if (lastSwipe != index) {
                          setState(() {
                            if (lastSwipe<index){
                              selected.fillRange(lastSwipe, index+1, true);
                            } else{
                              selected.fillRange(index, lastSwipe+1, true);
                            }
                          });
                          lastSwipe = -1;
                        }
                      }
                      lastSwipe = index;
                    }
                  },
                  onTap: () {
                    lastSwipe = index;
                    setState(() {
                      selected[index] = !selected[index];
                    });
                  },
                );
              },
            ),
          ),
        ]
      )
    );
  }
}