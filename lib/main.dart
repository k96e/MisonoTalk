import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback,SystemNavigator;
import 'package:url_launcher/url_launcher_string.dart' show launchUrlString;
import 'package:window_manager/window_manager.dart';
import 'package:eventflux/eventflux.dart';
import 'package:app_links/app_links.dart';
import 'dart:io' show Platform;
import 'dart:convert' show base64, utf8;
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
import 'recordmsgs.dart';


main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
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
  final notification = NotificationHelper();
  static const String studentName = "未花";
  List<String> welcomeMsgs = [
    "Sensei你终于来啦！\\我可是个乖乖看家的好孩子哦",
    "Sensei，欢迎回来！\\我在等你哦！"
  ];
  List<List<String>> specialWelcomeMsgs = [
    ["新年快乐，Sensei！ \\\\虽然是这样的我\\今年也请多多指教哦☆","1-1"],
    ["万圣节快乐☆\\好像有卖今天限定的饰品哦！\\\\一起去购物之类的，怎么样呀？","10-31","11-1"],
    ["是神圣的夜晚呢，Sensei\\今天有什么计划吗？\\\\...可以的话\\要不要和我一起过呢☆","12-24","12-25"],

  ];
  Config config = Config(name: "", baseUrl: "", apiKey: "", model: "");
  DateTime? currentBackPressTime;
  String userMsg = "";
  int splitCount = 0;
  bool externalPrompt = false;
  bool inputLock = false;
  bool keyboardOn = false;
  bool isForeground = true;
  bool isAutoNotification = false;
  bool isOnTop = false;
  List<Message> messages=[];
  List<Message>? lastMessages;
  List<String> recordMessages=[];
  late AppLinks appLinks;
  StreamSubscription<Uri>? linksSubscription;

  Future<void> initialize() async {
    clearMsg();
    String? msg = await getTempHistory();
    if (msg != null) {
      loadHistory(msg);
      recordMessages.add(msg);
    }
    List<Config> configs = await getApiConfigs();
    if (configs.isNotEmpty) {
      config = configs[0];
    }
    appLinks = AppLinks();
    linksSubscription = appLinks.uriLinkStream.listen((Uri uri) {
      String payload = uri.toString();
      debugPrint(payload);
      handleAppLink(uri.queryParameters);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    linksSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    super.didChangeAppLifecycleState(state);
    if(state == AppLifecycleState.resumed){
      isForeground = true;
      if(isAutoNotification){
        isAutoNotification = false;
        notification.cancelAll();
      }
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

  Future<void> handleAppLink(Map<String,String> payload) async {
    late List<Message> msgs;
    if(!payload.containsKey("m")) return;
    try {
      String msgStr = utf8.decode(base64.decode(payload['m']!));
      msgs = jsonToMsg(msgStr);
    } catch (e) {
      debugPrint(e.toString());
      debugPrint(payload['m']);
      return;
    }
    debugPrint(msgs.toString());
    if(msgs.isEmpty) return;
    if(payload["confirm"]=="true"){
      setState(() {
        messages.clear();
        messages.addAll(msgs);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setScrollPercent(1.0);
          if(msgs.last.type == Message.system || msgs.last.type == Message.user){
            sendMsg(true,forceSend: true);
          }
        });
      });
      return;
    }
    showDialog(context: context, builder: (context){
      return AlertDialog(
        title: const Text("App Link"),
        content: const Text("是否加载链接内容？"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                messages.clear();
                messages.addAll(msgs);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setScrollPercent(1.0);
                });
              });
            },
            child: const Text('Load'),
          ),
        ],
      );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setScrollPercent(1.0);
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
    lastMessages = null;
    String welcomeMsg = "";
    DateTime now = DateTime.now();
    String dateStr = "${now.month}-${now.day}";
    for (var specialOri in specialWelcomeMsgs) {
      for (var m in specialOri) {
        if (m==dateStr) {
          welcomeMsg = specialOri[0];
          break;
        }
      }
      if (welcomeMsg.isNotEmpty) break;
    }
    if (welcomeMsg.isEmpty) {
      welcomeMsg = welcomeMsgs[now.second % welcomeMsgs.length];
    }
    setState(() {
      messages.clear();
      messages.add(Message(message: welcomeMsg, type: Message.assistant));
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
    bool notificationSent= false;
    try {
      String response = "";
      await completion(config, msg, 
        (String resp){
          resp = resp.replaceAll(RegExp(r'[\n\\]+'), r'\');
          resp = randomizeBackslashes(resp);
          response += resp;
          updateResponse(response);
          if(!isForeground && !notificationSent && response.contains("\\")){
            List<String> msgs = response.split("\\");
            for(int i=0;i<msgs.length;i++){
              if(msgs[i].isEmpty || msgs[i].startsWith("*")||
                msgs[i].startsWith("（")||msgs[i].startsWith("我无法继续")){
                continue;
              }
              if(i!=msgs.length-1){
                notification.showNotification(title: studentName, body: msgs[i]);
                isAutoNotification = true;
                notificationSent = true;
                break;
              }
            }
          }
        }, (){
          debugPrint("done.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setScrollPercent(1.0);
          });
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          if(messages.last.message.contains("\\")){
            String msg = msgListToJson(messages);
            setTempHistory(msg);
            recordMessages.add(msg);
          }
          if(!isForeground && !notificationSent){
            isAutoNotification = true;
            notificationSent = true;
            notification.showNotification(title: "Done", body: "" ,showAvator: false);
          }
          lastMessages = null;
        }, (err){
          setState(() {
            inputLock = false;
          });
          debugPrint("inputUnlocked");
          errDialog(err.toString());
          if(!isForeground){
            isAutoNotification = true;
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
        isAutoNotification = true;
        notification.showNotification(title: "Error", body: "", showAvator: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if(!Platform.isAndroid) return;
        if (didPop) return;
        if(currentBackPressTime==null||DateTime.now().difference(currentBackPressTime!) > const Duration(seconds: 2)){
          currentBackPressTime = DateTime.now();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Center(child: Text('再次返回以退出')),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }else{
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 50,
          title: const DragToMoveArea(
            child: SizedBox(
              height: 22,
              child: Image(
                image: AssetImage("assets/momotalk.webp"),
                fit: BoxFit.scaleDown)
            )
          ),
          flexibleSpace: DragToMoveArea(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xffff899e), Color(0xfff79bac)],
                ),
              ),
            )
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
                  value: 'Records',
                  child: Text('Records...'),
                ),
                const PopupMenuItem(
                  value: 'Msgs',
                  child: Text('Msgs...'),
                ),
                const PopupMenuItem(
                  value: 'Settings',
                  child: Text('Settings...'),
                ),
                if (inputLock)
                  const PopupMenuItem(
                    value: 'Stop',
                    child: Text('Stop'),
                  ),
                if (Platform.isWindows)
                  PopupMenuItem(
                    value: 'OnTop',
                    child: Text('OnTop ${isOnTop?"√":"×"}'),
                  ),
                if (Platform.isWindows)
                  const PopupMenuItem(
                    value: 'Exit',
                    child: Text('Exit'),
                  ),
              ],
              onSelected: (String value) async {
                if (value == 'Clear') {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Clear"),
                      content: const Text("确认清除当前对话上下文？"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            clearMsg();
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
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
                          builder: (context) => 
                            ConfigPage(updateFunc: updateConfig, currentConfig: config)));
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
                  int promptLength = (await getPrompt(withExternal: externalPrompt)).length;
                  if(!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MsgEditor(msgs: messages, 
                      promptLength: promptLength,)
                    )
                  ).then((msgs){
                    if(msgs!=null){
                      setState(() {
                        messages.clear();
                        messages.addAll(msgs);
                      });
                    }
                  });
                }else if (value == 'Draw') {
                  sdWorkflow();
                }else if (value == 'Exit') {
                  if (Platform.isWindows) {
                    windowManager.close();
                  }
                }else if (value == 'OnTop') {
                  if (Platform.isWindows) {
                    setState(() {
                      isOnTop = !isOnTop;
                    });
                    windowManager.setAlwaysOnTop(isOnTop);
                  }
                }else if (value == 'Stop') {
                  EventFlux.instance.disconnect().then((val){
                    debugPrint(val.toString());
                    setState(() {
                      inputLock = false;
                    });
                  });
                }else if (value == 'Records') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecordMsgs(
                        msgs: recordMessages.reversed.toList(),
                        updateMsg: loadHistory)
                    )
                  );
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
                                        if(message.isHide) return;
                                        onMsgPressed(index, details);
                                      },
                                      child: Opacity(opacity: message.isHide?0.3:1.0,
                                        child: ChatElement(
                                          message: message.message,
                                          type: message.type,
                                          stuName: studentName,
                                        )
                                      )
                                    )
                                  ],
                                );
                              }
                              return GestureDetector(
                                onLongPressStart: (LongPressStartDetails details) {
                                  if(message.isHide) return;
                                  onMsgPressed(index, details);
                                  fn.unfocus();
                                },
                                child: Opacity(opacity: message.isHide?0.3:1.0,
                                  child: ChatElement(
                                  message: message.message, 
                                  type: message.type,
                                  stuName: studentName
                                  )
                                )
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
        )
      )
    );
  }
}
