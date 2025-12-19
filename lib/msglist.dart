import 'package:flutter/material.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'utils.dart' show Message, jsonToMsg, timestampToSystemMsg;

class CompactBranchGraph extends StatelessWidget {
  final String rootText;
  final List<String> childrenTexts;
  final double nodeHeight = 26.0;
  //final double nodeWidth = 120.0;
  final double verticalSpacing = 10.0;
  final double connectorWidth = 30.0;
  const CompactBranchGraph({
    super.key,
    required this.rootText,
    required this.childrenTexts,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;
    final totalChildrenHeight = (childrenTexts.length * nodeHeight) +
        ((childrenTexts.length - 1) * verticalSpacing);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildNode(rootText, color),
        SizedBox(
          width: connectorWidth,
          height: totalChildrenHeight,
          child: CustomPaint(
            painter: BranchConnectorPainter(
              itemCount: childrenTexts.length,
              itemHeight: nodeHeight,
              spacing: verticalSpacing,
              color: color,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: childrenTexts.asMap().entries.map((entry) {
            int idx = entry.key;
            String text = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: idx != childrenTexts.length - 1 ? verticalSpacing : 0),
              child: _buildNode(text, color),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNode(String text, Color color) {
    return Container(
      height: nodeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 18,
        ),
      ),
    );
  }
}

class BranchConnectorPainter extends CustomPainter {
  final int itemCount;
  final double itemHeight;
  final double spacing;
  final Color color;

  BranchConnectorPainter({
    required this.itemCount,
    required this.itemHeight,
    required this.spacing,
    this.color = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final startPoint = Offset(0, size.height / 2);
    for (int i = 0; i < itemCount; i++) {
      double currentTop = i * (itemHeight + spacing);
      double childCenterY = currentTop + (itemHeight / 2);
      final endPoint = Offset(size.width, childCenterY);
      final path = Path();
      path.moveTo(startPoint.dx, startPoint.dy);
      final controlPoint1 = Offset(size.width * 0.6, startPoint.dy);
      final controlPoint2 = Offset(size.width * 0.4, endPoint.dy);
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        endPoint.dx, endPoint.dy,
      );
      _drawArrow(canvas, paint, endPoint);
      canvas.drawPath(path, paint);
    }
  }
  void _drawArrow(Canvas canvas, Paint paint, Offset tip) {
    const arrowSize = 4.0;
    final arrowPath = Path();
    arrowPath.moveTo(tip.dx - arrowSize, tip.dy - arrowSize);
    arrowPath.lineTo(tip.dx, tip.dy);
    arrowPath.lineTo(tip.dx - arrowSize, tip.dy + arrowSize);
    canvas.drawPath(arrowPath, paint);
  }
  @override
  bool shouldRepaint(covariant BranchConnectorPainter oldDelegate) {
    return oldDelegate.itemCount != itemCount ||
           oldDelegate.itemHeight != itemHeight ||
           oldDelegate.spacing != spacing ||
           oldDelegate.color != color;
  }
}

Widget msgsListWidget(BuildContext context, String jsonMessages, {bool isReverse = true, String? jsonMsgCompare}) {
  List<Message> messages;
  List<Message>? messagesCmp;
  try {
    messages = jsonToMsg(jsonMessages);
    if (jsonMsgCompare != null && jsonMsgCompare.isNotEmpty) {
      messagesCmp = jsonToMsg(jsonMsgCompare);
    }
  } catch (e) {
    return SingleChildScrollView(
      child: Text("$e\n$jsonMessages"),
    );
  }
  return StatefulBuilder(
    builder: (context, setState) {
      bool isDiffOn = true; 
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          List<dynamic> displayList = [];
          int commonCount = 0;
          if (messagesCmp != null && isDiffOn) {
            int len = messages.length < messagesCmp.length ? messages.length : messagesCmp.length;
            for (int i = 0; i < len; i++) {
              if (messages[i].message == messagesCmp[i].message && 
                  messages[i].type == messagesCmp[i].type) {
                commonCount++;
              } else {
                break;
              }
            }
            if (commonCount > 0) {
              String tip = "";
              String pct = (commonCount * 100 / messages.length).toStringAsFixed(0);
              if (commonCount == messages.length && messages.length == messagesCmp.length) {
                tip = "no diff ($commonCount - $pct%)";
              } else if (commonCount == messagesCmp.length) {
                tip = "longer than current ($commonCount - $pct%)";
              } else if (commonCount == messages.length) {
                tip = "subset of current ($commonCount - $pct%)";
              } else {
                tip = "diff start after msg $commonCount ($pct%)";
              }
              displayList.add(tip);
              if (tip.startsWith("diff start") && messages[commonCount-1].type == Message.user) {
                displayList.add(messages[commonCount-1]);
              }
              for (int i = commonCount; i < messages.length; i++) {
                displayList.add(messages[i]);
              }
            } else {
              displayList = List.from(messages);
            }
          } else {
            displayList = List.from(messages);
          }
          if (isReverse) {
            displayList = displayList.reversed.toList();
          }
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              children: [
                if (messagesCmp != null)
                  SizedBox(
                    height: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                        const Text("show diff"),
                        Checkbox(
                          value: isDiffOn,
                          onChanged: (val) {
                          setState(() {
                            isDiffOn = val ?? false;
                          });
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: displayList.length,
                    reverse: isReverse,
                    itemBuilder: (context, index) {
                      final item = displayList[index];
                      if (item is String) {
                        return Center(
                          child: JustTheTooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            enableFeedback: false,
                            tailBaseWidth: 15,
                            tailLength: 10,
                            isModal: true,
                            content: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: CompactBranchGraph(
                                rootText: "$commonCount (same)",
                                childrenTexts: [
                                  "${messagesCmp!.length - commonCount} (current)",
                                  "${messages.length - commonCount} (this)",
                                ],
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ),
                        );
                      }
                      else if (item is Message) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              item.type == Message.timestamp
                                  ? timestampToSystemMsg(item.message)
                                  : item.message,
                              style: item.type == Message.assistant
                                  ? const TextStyle(color: Color(0xff1a85ff))
                                  : null,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  );
}