import 'package:flutter/material.dart';

// Data class for Contact
// You would typically fetch this data from a backend or local storage.
class Contact {
  final String name;
  final String message;
  final int unreadCount;
  final String? avatarAssetName; // Path to asset image, e.g., "assets/avatars/shigure.png"
  final bool isFavorite;

  Contact({
    required this.name,
    required this.message,
    required this.unreadCount,
    this.avatarAssetName,
    this.isFavorite = false,
  });
}

class LeftPanelWidget extends StatelessWidget {
  LeftPanelWidget({super.key});

  // Sample data for contacts.
  // Replace with your actual data source and ensure asset paths are correct
  // and images are included in your pubspec.yaml.
  final List<Contact> _contacts = [
    Contact(name: "シグレ (温泉)", message: "先生、旧校舎の湯船にお湯が...", unreadCount: 2, avatarAssetName: "assets/shigure_avatar.png"),
    Contact(name: "フブキ (水着)", message: "私だけのパラダイスを見つけた...", unreadCount: 2, avatarAssetName: "assets/fubuki_avatar.png", isFavorite: true),
    Contact(name: "セイア", message: "申し訳ない", unreadCount: 1, avatarAssetName: "assets/seia_avatar.png", isFavorite: true),
    Contact(name: "ナギサ", message: "私たちだって、いつもケーキや...", unreadCount: 0, avatarAssetName: "assets/nagisa_avatar.png", isFavorite: true),
    Contact(name: "ミカ", message: "あと……いつもありがとね", unreadCount: 0, avatarAssetName: "assets/mika_avatar.png", isFavorite: true),
    Contact(name: "アイリ", message: "...", unreadCount: 1, avatarAssetName: "assets/airi_avatar.png"), // Assuming unreadCount:1 based on red dot in image
    // Add more contacts as needed
  ];

  // Builds the narrow vertical tab bar on the far left
  Widget _buildLeftTabBar() {
    return Container(
      width: 60, // Width of the tab bar
      color: const Color(0xFFE7E8EC), // Background color from image
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Top icon (e.g., profile or settings)
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 30, color: Color(0xFFA8A9AD)), // Greyish inactive icon
            onPressed: () { /* Handle navigation to profile/settings */ },
          ),
          const SizedBox(height: 15),
          // Message icon (active tab in the image) with unread count badge
          SizedBox(
            width: 40, // Ensures badge is positioned relative to the icon's space
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none, // Allows badge to render outside SizedBox bounds
              children: <Widget>[
                const Icon(Icons.sms, size: 30, color: Color(0xFFEA5A78)), // Pinkish color like MomoTalk logo
                Positioned(
                  right: -8, // Adjust for desired badge overlap
                  top: -8,   // Adjust for desired badge overlap
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10), // Circular badge
                      border: Border.all(color: const Color(0xFFE7E8EC), width: 1.5) // Border matching tab bar background
                    ),
                    constraints: const BoxConstraints( // Minimum size for the badge
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Column( // For stacking "173" and "..."
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                         Text(
                          '173',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                         Text(
                          '...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            height: 0.7, // Reduces space between lines
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.5 // Makes dots appear closer
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Add other tab icons here if needed
        ],
      ),
    );
  }

  // Builds the top bar within the contacts list panel (Unread messages, Latest, Sort)
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 8.0, 8.0), // Padding for content
      decoration: BoxDecoration(
        color: Colors.white, // Background of this bar
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)), // Bottom divider line
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const Text(
            '未読メッセージ(173)', // "Unread Messages (173)"
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          Row(
            children: <Widget>[
              // "Latest" filter button
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero, // Remove default min size
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
                ),
                onPressed: () { /* Handle filter change */ },
                child: Row(
                  children: const [
                    Text('最新', style: TextStyle(fontSize: 12, color: Color(0xFF555555))), // "Latest"
                    Icon(Icons.arrow_drop_down, color: Color(0xFF555555), size: 18),
                  ],
                ),
              ),
              // Sort button
              IconButton(
                icon: const Icon(Icons.sort, color: Color(0xFF555555), size: 18), // Standard sort icon
                // For a custom icon like "三↓":
                // icon: Column(mainAxisSize: MainAxisSize.min, children:[Text("三", style: TextStyle(fontSize:10, fontWeight:FontWeight.bold, color: Color(0xFF555555))), Text("↓",style: TextStyle(fontSize:10, fontWeight:FontWeight.bold, color: Color(0xFF555555))) ]),
                padding: const EdgeInsets.all(4.0),
                constraints: const BoxConstraints(), // Remove default constraints for tighter padding
                tooltip: 'Sort',
                onPressed: () { /* Handle sort action */ },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builds a single item in the contact list
  Widget _buildContactListItem(BuildContext context, Contact contact) {
    Widget avatarDisplay;
    // Attempt to load asset image, fallback to placeholder
    // In a real app, ensure `contact.avatarAssetName` points to a valid asset
    // defined in your `pubspec.yaml` (e.g. "assets/avatars/character.png")
    if (contact.avatarAssetName != null && contact.avatarAssetName!.isNotEmpty) {
      // Placeholder for actual image loading. For this example, we'll use colored circles.
      // To use real images:
      // avatarDisplay = CircleAvatar(
      //   radius: 22,
      //   backgroundImage: AssetImage(contact.avatarAssetName!),
      //   onBackgroundImageError: (_, __) { /* Handle error, maybe show placeholder */ },
      // );
       avatarDisplay = CircleAvatar(
        radius: 22,
        backgroundColor: Colors.primaries[contact.name.hashCode % Colors.primaries.length].withOpacity(0.7),
        child: Text(
          contact.name.isNotEmpty ? contact.name.substring(0, 1) : "?",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    } else {
      // Default placeholder if no asset name is provided
      avatarDisplay = CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, color: Colors.white, size: 28),
      );
    }

    return Material(
      color: Colors.white, // Ensures InkWell effect is visible
      child: InkWell(
        onTap: () { /* Handle tapping on a contact, e.g., open chat */ },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              // Avatar with optional favorite star
              Stack(
                clipBehavior: Clip.none,
                children: [
                  avatarDisplay,
                  if (contact.isFavorite)
                    Positioned(
                      bottom: -4, // Adjust for star position
                      right: -4,  // Adjust for star position
                      child: Container(
                        padding: const EdgeInsets.all(1.5), // Small padding around the star
                        decoration: const BoxDecoration(
                            color: Colors.white, // White background to make star pop
                            shape: BoxShape.circle
                        ),
                        child: const Icon(Icons.star, color: Color(0xFFFFC700), size: 15) // Yellow star
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10), // Spacing between avatar and text
              // Name and last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.message,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Unread message count badge (if any)
              if (contact.unreadCount > 0) ...[
                const SizedBox(width: 8), // Spacing before badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10), // Rounded badge
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

  // Builds the scrollable list of contacts
  Widget _buildContactList(BuildContext context) {
    return Container(
      color: Colors.white, // Background for the list area
      child: ListView.builder(
        padding: EdgeInsets.zero, // Remove default ListView padding
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          // Add a divider between contact items, but not after the last one
          return Column(
            children: [
              _buildContactListItem(context, _contacts[index]),
              if (index < _contacts.length - 1)
                Divider(
                  height: 1, // Height of the divider line
                  thickness: 0.5, // Thickness of the line
                  indent: 66, // Indent from the left, aligning past avatar and padding
                  endIndent: 10, // Indent from the right
                  color: Colors.grey[200] // Light grey color for divider
                )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The main structure of the left panel: TabBar | ContactsArea
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Aligns TabBar to the top if its content varies
      children: [
        _buildLeftTabBar(), // The narrow icon bar
        // The main area for contact list and its controls
        Expanded(
          child: Container(
            color: Colors.white, // Background for the contacts panel
            child: Column(
              children: [
                _buildTopBar(), // Bar with "Unread messages", filter, sort
                Expanded(
                  child: _buildContactList(context), // The scrollable list of contacts
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}