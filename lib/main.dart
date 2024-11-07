import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:url_launcher/url_launcher_string.dart' show launchUrlString;
import 'dart:io' show Platform;
import 'dart:async' show Timer;
import 'chatview.dart';
import 'configpage.dart';
import 'notifications.dart';
import 'popups.dart';
import 'theme.dart';
import 'history.dart';
import 'openai.dart';
import 'storage.dart';
import 'utils.dart';
import 'webdav.dart';
import 'msgeditor.dart';
import 'aidraw.dart';


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
  final notification= NotificationHelper();
  static const String studentName = "未花";
  static const String originalMsg = "Sensei你终于来啦！\\我可是个乖乖看家的好孩子哦";
  Config config = Config(name: "", baseUrl: "", apiKey: "", model: "");
  String userMsg = "";
  int splitCount = 0;
  bool externalPrompt = false;
  bool inputLock = false;
  bool keyboardOn = false;
  bool isForeground = true;
  List<Message> messages = [
    Message(message: originalMsg, type: Message.assistant),
  ];
  List<Message>? lastMessages;

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
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state == AppLifecycleState.resumed){
      isForeground = true;
    } else {
      isForeground = false;
    }
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
      if(ModalRoute.of(context)?.isCurrent != true){
        return;
      }
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
    HapticFeedback.heavyImpact();
    if(messages[index].type == Message.assistant){
      assistantPopup(context, messages[index].message, details, studentName, (String edited){
        debugPrint("edited: $edited");
        edited = edited.replaceAll("\n", "\\");
        if(edited=="FORMAT"){
          String msg = messages[index].message.replaceAll(":", "：");
          String var1="$studentName：",var2="Sensei：";
          List<String> msgs = splitString(msg, [var1,var2]);
          debugPrint("msgs: $msgs");
          setState(() {
            messages.removeAt(index);
            for(int i=0;i<msgs.length;i++){
              if(msgs[i].startsWith(var1)){
                messages.insert(index+i, Message(
                  message: msgs[i].substring(var1.length), 
                  type: Message.assistant));
              } else if(msgs[i].startsWith(var2)){
                messages.insert(index+i, Message(
                  message: msgs[i].substring(var2.length).replaceAll("\\\\", "\\"), 
                  type: Message.user));
              }
            }
          });
          return;
        }
        if(edited.isEmpty){
          setState(() {
            messages.removeRange(index, messages.length);
          });
          return;
        }
        setState(() {
          messages[index].message = edited;
        });
      });
    } else if(messages[index].type == Message.user){
      userPopup(context, messages[index].message, details, (String edited,bool isResend){
        debugPrint("edited: $edited");
        edited = edited.replaceAll("\n", "\\");
        if(edited.isEmpty){
          setState(() {
            messages.removeRange(index, messages.length);
          });
          return;
        }
        setState(() {
          messages[index].message = edited;
        });
        if(isResend){
          textController.clear();
          lastMessages = messages.sublist(index+1,messages.length);
          messages.removeRange(index+1, messages.length);
          sendMsg(true);
        }
      });
    } else if(messages[index].type == Message.timestamp){
      timePopup(context, int.parse(messages[index].message), details, (bool ifTransfer, DateTime? newTime){
        if(ifTransfer){
          setState(() {
            messages[index].type = Message.system;
            messages[index].message = timestampToSystemMsg(messages[index].message);
          });
        } else {
          debugPrint(newTime.toString());
          setState(() {
            messages[index].message = newTime!.millisecondsSinceEpoch.toString();
          });
        }
      });
    } else if(messages[index].type == Message.system){
      systemPopup(context, messages[index].message, (String edited,bool isSend){
        debugPrint("edited: $edited");
        if(edited.isEmpty){
          setState(() {
            messages.removeAt(index);
          });
        } else {
          setState(() {
            messages[index].message = edited;
          });
          if(isSend){
            messages.removeRange(index+1, messages.length);
            sendMsg(true,forceSend: true);
          }
        }
      });
    } else if(messages[index].type == Message.image){
      imagePopup(context, details, (bool edited){
        if(edited){
          launchUrlString(messages[index].message);
        } else {
          setState(() {
            messages.removeAt(index);
          });
        }
      });
    }
  }

  void sdWorkflow() async {
    bool isBuild = false;
    TextEditingController controller = TextEditingController();
    showDialog(context: context, builder: (context){
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("AiDraw"),
          content: TextField(
            maxLines: null,
            minLines: 1,
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Build prompt?",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () async {
                if(isBuild){
                  Navigator.of(context).pop(controller.text);
                } else {
                  controller.text = "Building...";
                  String prompt = "";
                  List<List<String>> msg = parseMsg(await getPrompt(withExternal: externalPrompt), messages);
                  msg.add(["user", "system instruction:暂停角色扮演，根据上下文，详细描述$studentName给Sensei发送的图片内容或是当前Sensei所看到的场景"]);
                  completion(config, msg, (resp){
                    const String a="我无法继续作为",b="代替玩家言行";
                    prompt += resp;
                    if(prompt.startsWith(a) && prompt.contains(b)){
                      prompt = prompt.replaceAll(RegExp('^$a.*?$b'), "");
                    }
                    controller.text = prompt;
                  }, (){
                    debugPrint("done.");
                    setState(() {
                      isBuild = true;
                    });
                  }, (err){
                    errDialog(err.toString(),canRetry: false);
                  });
                }
              },
              child: Text(isBuild? 'Done':'Build'),
            ),
          ],
        );
      });
    }).then((res){
      debugPrint("res: $res");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AiDraw(msg:res, config: config)
        )
      ).then((imageUrl){
        if(imageUrl!=null){
          setState(() {
            messages.add(Message(message: imageUrl, type: Message.image));
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setScrollPercent(1.0);
          });
        }
      });
    });
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
        const String a="我无法继续作为",b="代替玩家言行";
        if(response.startsWith(a) && response.contains(b)){
          response = response.replaceAll(RegExp('^$a.*?$b'), "");
        }
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

  void errDialog(String content,{bool canRetry=true}){
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
          if(canRetry) TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              sendMsg(true,forceSend: true);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    ).then((val){
      if(val==null&&lastMessages!=null){
        setState(() {
          messages.addAll(lastMessages!);
        });
      }
    });
  }

  Future<void> sendMsg(bool realSend,{bool forceSend=false}) async {
    if (inputLock) {
      return;
    }
    if(!forceSend){
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
    }
    setState(() {
      inputLock = true;
      debugPrint("inputLocked");
    });
    List<List<String>> msg = parseMsg(await getPrompt(withExternal: externalPrompt), messages);
    logMsg(msg.sublist(1));
    try {
      String response = "";
      await completion(config, msg, (resp){
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
          if(!isForeground) {
            List<String> msgs = response.split("\\");
            int index = 0;
            Timer.periodic(const Duration(milliseconds: 500), (timer) {
              if (index < msgs.length && !isForeground) {
                if (msgs[index].isNotEmpty) {
                  notification.showNotification(title: studentName, body: msgs[index]);
                }
                index++;
              } else {
                timer.cancel();
              }
            });
          }
        }, (err){
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          errDialog(err.toString());
          if(!isForeground){
            notification.showNotification(title: "Error", body: "", showAvator: false);
          }
        });
    } catch (e) {
      setState(() {
        inputLock = false;
      });
      debugPrint("inputUnlocked");
      debugPrint(e.toString());
      if(!mounted) return;
      errDialog(e.toString());
      if(!isForeground){
        notification.showNotification(title: "Error", body: "", showAvator: false);
      }
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
                  value: 'System',
                  child: Text('System'),
                ),
                PopupMenuItem(
                  value: 'ExtPrompt',
                  child: Text('ExtPrompt ${externalPrompt?"√":"×"}'),
                ),
                const PopupMenuItem(
                  value: 'Backup',
                  child: Text('Backup...'),
                ),
                const PopupMenuItem(
                  value: 'Draw',
                  child: Text('AiDraw...'),
                ),
                const PopupMenuItem(
                  value: 'History',
                  child: Text('History...'),
                ),
                const PopupMenuItem(
                  value: 'Msgs',
                  child: Text('Msgs...'),
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
                  String prompt = await getPrompt(withExternal: externalPrompt);
                  if(!context.mounted) return;
                  String? value = await namingHistory(context, "", config, studentName, parseMsg(prompt, messages));
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
                } else if (value == 'System') {
                  systemPopup(context, "", (String edited,bool isSend){
                    setState(() {
                      if(edited.isNotEmpty){
                        messages.add(Message(message: edited, type: Message.system));
                        if(isSend){
                          sendMsg(true,forceSend: true);
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setScrollPercent(1.0);
                        });
                      }
                    });
                  });
                } else if (value == 'Settings') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ConfigPage(updateFunc: updateConfig)));
                } else if (value == 'Backup'){
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => WebdavPage(
                            currentMessages: msgListToJson(messages),
                            onRefresh: loadHistory)));

                }else if (value == 'History') {
                  showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      scrollControlDisabledMaxHeightRatio: 0.9,
                      builder: (BuildContext context) => HistoryPage(updateFunc: loadHistory));
                }else if (value == 'ExtPrompt') {
                  setState(() {
                    externalPrompt = !externalPrompt;
                  });
                  snackBarAlert(context, "ExtPrompt ${externalPrompt?"on":"off"}");
                }else if (value == 'Msgs') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MsgEditor(msgs: messages)
                    )
                  ).then((msgs){setState(() {});});
                }else if (value == 'Draw') {
                  sdWorkflow();
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
                                        type: message.type,
                                        stuName: studentName,
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
                                  message: message.message, 
                                  type: message.type,
                                  stuName: studentName)
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
                              } else if(textController.text.isNotEmpty){
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
