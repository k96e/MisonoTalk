import 'package:flutter/material.dart';
import 'storage.dart' show getPrompt, setPrompt;

class PromptEditor extends StatefulWidget {
  const PromptEditor({super.key});

  @override
  PromptEditorState createState() => PromptEditorState();
}

class PromptEditorState extends State<PromptEditor> {
  TextEditingController controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    getPrompt().then((String value) {
      controller.text = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Editor'),
      ),
      body:  Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async{
                  controller.text = await getPrompt(isDefault: true);
                },
                child: const Text('恢复'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setPrompt(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
          Expanded(child:
          Padding(padding: const EdgeInsets.all(8.0),
            child: 
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: InputBorder.none
                ),
                style: const TextStyle(fontSize: 16,fontFamily: "Courier"),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              )
            )
          ),
        ],
      ),
    );
  }
}