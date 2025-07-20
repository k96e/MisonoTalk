import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'bawidgets.dart' show Bawidgets;

class Contact {
  final String name;
  final String message;
  final int unreadCount;
  final ImageProvider avatarImage;
  final bool isFavorite;

  Contact({
    required this.name,
    required this.message,
    required this.unreadCount,
    required this.avatarImage,
    this.isFavorite = false,
  });
}

class LeftPanelWidget extends StatelessWidget {
  LeftPanelWidget({super.key, this.msgStr, required this.avatarImage});
  final String? msgStr;
  final ImageProvider avatarImage;
  final baWidgets = Bawidgets();

  List<Contact> get _contacts => [
    Contact(name: "未花", message: "あと……いつもありがとね", unreadCount: 0, avatarImage: avatarImage, isFavorite: true),
  ];

  Widget _buildLeftTabBar() {
    return Container(
      width: 72,
      color: const Color(0xFF4C5B70),
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          IconButton(
            icon: SvgPicture.asset(
              'assets/a.svg',
              width: 32,
              height: 32,
            ),
            onPressed: () {},
          ),
          const SizedBox(height: 15),
          IconButton(
            icon: SvgPicture.asset(
              'assets/b.svg',
              width: 26,
              height: 26,
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 8.0, 8.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const Text(
            '未读信息',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: <Widget>[
              baWidgets.buildButton1(cornerRadius: 5),
              baWidgets.buildButton2(cornerRadius: 5)
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildContactListItem(BuildContext context, Contact contact) {
    return Material(
      //color: bgColor,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: avatarImage
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      msgStr ?? contact.message,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (contact.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${contact.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactList(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            _buildContactListItem(context, _contacts[index]),
            if (index < _contacts.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 66,
                endIndent: 10,
                color: Colors.grey[200]
              )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftTabBar(),
        Expanded(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: _buildContactList(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}