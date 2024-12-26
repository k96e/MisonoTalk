import 'package:flutter/material.dart';
import 'utils.dart' show Message, jsonToMsg;
import 'storage.dart' show setTempHistory;

class RecordMsgs extends StatefulWidget {
  final List<String> msgs;
  final Function(String) updateMsg;
  const RecordMsgs({super.key, required this.msgs, required this.updateMsg});

  @override
  RecordMsgsState createState() => RecordMsgsState();
}

class RecordMsgsState extends State<RecordMsgs> {

  @override
  void initState() {
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
                            content: SingleChildScrollView(
                              child: Text(widget.msgs[index]),
                            ),
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
                                  setTempHistory(widget.msgs[index]);
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