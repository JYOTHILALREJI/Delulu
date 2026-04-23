import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

class ChatContact {
  final String name;
  final String initial;
  final String lastMessage;
  final String time;
  final bool isOnline;
  final int unreadCount;

  const ChatContact({
    required this.name,
    required this.initial,
    required this.lastMessage,
    required this.time,
    required this.isOnline,
    this.unreadCount = 0,
  });
}

class ChatListScreen extends StatelessWidget {
  ChatListScreen({super.key});

  final List<ChatContact> _contacts = const [
    ChatContact(
      name: 'Mystic_Rose',
      initial: 'M',
      lastMessage: 'That midnight lounge aesthetic is exactly what we need...',
      time: '11:43 PM',
      isOnline: true,
      unreadCount: 2,
    ),
    ChatContact(
      name: 'Luna',
      initial: 'L',
      lastMessage: 'You: Sounds like a plan. See you at 8.',
      time: '10:15 PM',
      isOnline: true,
      unreadCount: 0,
    ),
    ChatContact(
      name: 'Scarlet',
      initial: 'S',
      lastMessage: 'I sent you that vinyl track we talked about.',
      time: '9:02 PM',
      isOnline: false,
      unreadCount: 1,
    ),
    ChatContact(
      name: 'Aria',
      initial: 'A',
      lastMessage: 'The architecture in that photo is stunning.',
      time: 'Yesterday',
      isOnline: false,
      unreadCount: 0,
    ),
    ChatContact(
      name: 'Elena',
      initial: 'E',
      lastMessage: 'You: I love the silence between jazz notes too.',
      time: 'Yesterday',
      isOnline: true,
      unreadCount: 0,
    ),
    ChatContact(
      name: 'Maya',
      initial: 'M',
      lastMessage: 'Let\'s skip the small talk next time.',
      time: 'Mon',
      isOnline: false,
      unreadCount: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 16, bottom: 20),
        itemCount: _contacts.length,
        separatorBuilder: (context, index) => Divider(
          color: AppColors.whiteAlpha05,
          indent: 88,
          endIndent: 24,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return _ChatTile(
            contact: contact,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    userName: contact.name,
                    userInitial: contact.initial,
                    isOnline: contact.isOnline,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatContact contact;
  final VoidCallback onTap;

  const _ChatTile({
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.purpleAccent, AppColors.pinkAccent],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      contact.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                if (contact.isOnline)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.greenGlow,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        contact.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: contact.unreadCount > 0
                              ? AppColors.pinkAccent
                              : AppColors.textDim,
                          fontWeight: contact.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          contact.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: contact.unreadCount > 0
                                ? AppColors.whiteAlpha80
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (contact.unreadCount > 0) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.pinkAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          child: Text(
                            '${contact.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}