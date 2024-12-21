import 'package:flutter/material.dart';
import 'utils.dart' show Message;

class MsgEditor extends StatefulWidget {
  final List<Message> msgs;
  const MsgEditor({super.key, required this.msgs});

  @override
  MsgEditorState createState() => MsgEditorState();
}

class MsgEditorState extends State<MsgEditor> {
  late List<bool> selected;
  int lastSwipe = -1;

  @override
  void initState() {
    selected = List.filled(widget.msgs.length, false, growable: true);
    super.initState();
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
          Padding(padding: const EdgeInsets.all(8.0),
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
                    widget.msgs.removeWhere((element) => selected[widget.msgs.indexOf(element)]);
                    selected.removeWhere((element) => element);
                  });
                },
                child: const Text('删除'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    for (Message msg in widget.msgs) {
                      if (selected[widget.msgs.indexOf(msg)]){
                        msg.isHide = !msg.isHide;
                      }
                    }
                  });
                },
                child: const Text('*Hide'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, widget.msgs);
                },
                child: const Text('确认'),
              ),
            ],
          )
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.msgs.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  child: Card(
                    child: ListTile(
                      selected: selected[index],
                      title: Text((widget.msgs[index].isHide?'*':'')+typeDesc(widget.msgs[index].type)+widget.msgs[index].message,
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