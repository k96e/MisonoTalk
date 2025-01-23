import 'package:flutter/material.dart';
import 'storage.dart';

class PromptEditor extends StatefulWidget {
  const PromptEditor({super.key});

  @override
  PromptEditorState createState() => PromptEditorState();
}

class PromptEditorState extends State<PromptEditor> {
  TextEditingController controller = TextEditingController();
  final storage = StorageService();
  @override
  void initState() {
    super.initState();
    storage.getPrompt(isRaw: true).then((String value) {
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
                  controller.text = await storage.getPrompt(isDefault: true, isRaw: true);
                },
                child: const Text('恢复'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  storage.setPrompt(controller.text);
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
          const Text("（可通过添加'prompt_split'标记分隔ExternalPrompt）",
            style: TextStyle(fontSize: 12),
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