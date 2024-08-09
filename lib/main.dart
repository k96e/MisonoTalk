import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'chatview.dart';
import 'configpage.dart';
import 'notifications.dart';
import 'popups.dart';
import 'theme.dart';
import 'history.dart';
import 'openai.dart';
import 'storage.dart';
import 'utils.dart';


main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationHelper notificationHelper = NotificationHelper();
  await notificationHelper.initialize();
  runApp(const MomotalkApp());
}

class MomotalkApp extends StatelessWidget {
  const MomotalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MomoTalk',
      home: const MainPage(),
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> with WidgetsBindingObserver{
  final fn = FocusNode();
  final textController = TextEditingController();
  final scrollController = ScrollController();
  static const String originalMsg = "Sensei你终于来啦！\\我可是个乖乖看家的好孩子哦";
  Config config = Config(name: "", baseUrl: "", apiKey: "", model: "");
  String userMsg = "";
  int splitCount = 0;
  bool inputLock = false;
  bool keyboardOn = false;
  List<Message> messages = [
    Message(message: originalMsg, type: Message.assistant),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getTempHistory().then((msg) {
      if (msg != null) {
        loadHistory(msg);
      }
    });
    getApiConfigs().then((configs) {
      if (configs.isNotEmpty) {
        config = configs[0];
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if(!Platform.isAndroid){
      return;
    }
    final bottom = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if(bottom>10 && !keyboardOn){
      debugPrint("keyboard on");
      keyboardOn = true;
      Future.delayed(const Duration(milliseconds: 200), () => setScrollPercent(1.0));
    } else if(bottom<10 && keyboardOn){
      debugPrint("keyboard off");
      keyboardOn = false;
    }
  }

  double getScrollPercent() {
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final percent = currentScroll / maxScroll;
    debugPrint("scroll percent: $percent");
    return percent;
  }

  void setScrollPercent(double percent) {
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = maxScroll * percent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollController.animateTo(currentScroll,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void updateConfig(Config c){
    config = c;
    debugPrint("update config: ${c.toString()}");
  }

  void onMsgPressed(int index,LongPressStartDetails details){
    debugPrint("index: $index");
    debugPrint("type: ${messages[index].type}");
    if(messages[index].type == Message.assistant){
      assistantPopup(context, messages[index].message, details, (edited){
        debugPrint("edited: $edited");
        setState(() {
          messages[index].message = edited;
        });
      });
    } else if(messages[index].type == Message.user){
      userPopup(context, messages[index].message, details, (edited,isResend){
        debugPrint("edited: $edited");
        setState(() {
          messages[index].message = edited;
        });
        if(isResend){
          textController.clear();
          messages.removeRange(index+1, messages.length);
          sendMsg(true);
        }
      });
    } else if(messages[index].type == Message.timestamp){
      timePopup(context, int.parse(messages[index].message), (newTime){
        debugPrint(newTime.toString());
        setState(() {
          messages[index].message = newTime.millisecondsSinceEpoch.toString();
        });
      });
    }
  }

  void loadHistory(String msg) {
    List<Message> msgs = jsonToMsg(msg);
    setState(() {
      messages.clear();
      messages.addAll(msgs);
    });
  }

  void updateResponse(String response) {
    setState(() {
      if (messages.last.type != Message.assistant) {
        splitCount = 0;
        messages.add(Message(message: response, type: Message.assistant));
      } else {
        messages.last.message = response;
      }
    });
    var currentSplitCount = response.split("\\").length;
    if (splitCount != currentSplitCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setScrollPercent(1.0);
      });
      splitCount = currentSplitCount;
    }
  }

  void clearMsg() {
    setState(() {
      messages.clear();
      messages.add(Message(message: originalMsg, type: Message.assistant));
      setTempHistory(msgListToJson(messages));
    });
  }

  void logMsg(List<List<String>> msg) {
    for (var m in msg) {
      debugPrint("${m[0]}: ${m[1]}");
    }
    debugPrint("model: ${config.model}");
  }

  Future<void> sendMsg(bool realSend) async {
    if (inputLock) {
      return;
    }
    if((!realSend)||(realSend&&textController.text.isNotEmpty)){
      setState(() {
        if(messages.last.type == Message.user){
          userMsg = "$userMsg\\${textController.text}";
          messages.last.message = userMsg;
        } else {
          if (messages.length==1) {
            messages.add(Message(message: DateTime.now().millisecondsSinceEpoch.toString(), type: Message.timestamp));
          }
          userMsg = textController.text;
          messages.add(Message(message: userMsg, type: Message.user));
        }
        textController.clear();
      });
      debugPrint(userMsg);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setScrollPercent(1.0);
      });
      if(!realSend){return;}
    }
    userMsg = "";
    setState(() {
      inputLock = true;
      debugPrint("inputLocked");
    });
    List<List<String>> msg = parseMsg(await getPrompt(), messages);
    logMsg(msg.sublist(1));
    try {
      String response = "";
      completion(config, msg, (resp){
          if(resp.toString().contains("\\")){
            resp = randomizeBackslashes(resp.replaceAll("\\\\", "\\"));
          }
          response += resp.replaceAll("\n", '');
          updateResponse(response);
        }, (){
          debugPrint("done.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setScrollPercent(1.0);
          });
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          setTempHistory(msgListToJson(messages));
        }, (e){
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          errDialog(context, e);
        });
    } catch (e) {
      setState(() {
        inputLock = false;
      });
      debugPrint("inputUnlocked");
      debugPrint(e.toString());
      if(!mounted) return;
      errDialog(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          toolbarHeight: 50,
          title: const SizedBox(
              height: 22,
              child: Image(
                  image: AssetImage("assets/momotalk.webp"),
                  fit: BoxFit.scaleDown)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xffff899e), Color(0xfff79bac)],
              ),
            ),
          ),
          actions: <Widget>[
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 40,
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'Clear',
                  child: Text('Clear'),
                ),
                const PopupMenuItem(
                  value: 'Save',
                  child: Text('Save'),
                ),
                const PopupMenuItem(
                  value: 'Time',
                  child: Text('Time'),
                ),
                const PopupMenuItem(
                  value: 'History',
                  child: Text('History...'),
                ),
                const PopupMenuItem(
                  value: 'Settings',
                  child: Text('Settings...'),
                ),
              ],
              onSelected: (String value) async {
                if (value == 'Clear') {
                  clearMsg();
                } else if (value == 'Save') {
                  String prompt = await getPrompt();
                  if(!context.mounted) return;
                  String? value = await namingHistory(context, "", config, parseMsg(prompt, messages));
                  if (value != null) {
                    debugPrint(value);
                    addHistory(msgListToJson(messages),value);
                    if(!context.mounted) return;
                    snackBarAlert(context, "已保存");
                  } else {
                    debugPrint("cancel");
                  }
                } else if (value == 'Time') {
                  if(messages.last.type != Message.timestamp){
                    setState(() {
                      messages.add(Message(message: DateTime.now().millisecondsSinceEpoch.toString(), type: Message.timestamp));
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setScrollPercent(1.0);
                    });
                  }
                } 
                else if (value == 'Settings') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ConfigPage(updateFunc: updateConfig)));
                } else if (value == 'History') {
                  showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      scrollControlDisabledMaxHeightRatio: 0.9,
                      builder: (BuildContext context) => HistoryPage(updateFunc: loadHistory));
                }
              },
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            fn.unfocus();
          },
          child: Column(
            children: [
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: SingleChildScrollView(
                          controller: scrollController,
                          child: ListView.builder(
                            itemCount: messages.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              if (index == 0) {
                                return Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onLongPressStart: (LongPressStartDetails details) {
                                        onMsgPressed(index, details);
                                      },
                                      child: ChatElement(
                                        message: message.message,
                                        type: message.type
                                      )
                                    )
                                  ],
                                );
                              }
                              return GestureDetector(
                                onLongPressStart: (LongPressStartDetails details) {
                                  onMsgPressed(index, details);
                                  fn.unfocus();
                                },
                                child: ChatElement(
                                  message: message.message, type: message.type)
                                );
                            },
                          )))),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                        child: TextField(
                            focusNode: fn,
                            controller: textController,
                            // enabled: !inputLock,
                            onEditingComplete: (){
                              if(textController.text.isEmpty && userMsg.isNotEmpty){
                                sendMsg(true);
                              } else {
                                sendMsg(false);
                              }
                            },
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              fillColor: const Color(0xffff899e),
                              isCollapsed: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              hintText: inputLock ? 'Responding' : 'Type a message',
                            ))),
                    const SizedBox(width: 5),
                    ElevatedButton(
                      onPressed: () => sendMsg(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(0),
                        backgroundColor: const Color(0xffff899e),
                        foregroundColor: const Color(0xffffffff),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text('Send'),
                    )
                  ],
                ),
              )
            ],
          ),
        ));
  }
}
