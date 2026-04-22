import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.whiteAlpha60, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.purpleAccent, AppColors.pinkAccent],
                ),
              ),
              child: const Center(
                child: Text(
                  'M',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mystic_Rose',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(fontSize: 11, color: AppColors.greenGlow),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_outline,
                color: AppColors.whiteAlpha40, size: 18),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert,
                color: AppColors.whiteAlpha40, size: 18),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.whiteAlpha05,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textDim,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                _MessageBubble(
                  isMe: false,
                  time: '11:42 PM',
                  child: const Text(
                    'The way the light leaks through these old glass panels is mesmerizing. Did you see the latest reel I posted?',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.white,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _MessageBubble(
                  isMe: true,
                  time: '11:43 PM',
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.white,
                          height: 1.45),
                      children: [
                        TextSpan(
                          text:
                              'Just watched it. That midnight lounge aesthetic is exactly what we need for the next phase. ',
                        ),
                        TextSpan(text: '\u{1F3B6}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.whiteAlpha05),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.whiteAlpha40),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.whiteAlpha05,
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: AppColors.whiteAlpha10),
                      ),
                      child: const Text(
                        'Type a message...',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: AppColors.whiteAlpha40),
                    onPressed: () {},
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMe;
  final String time;
  final Widget child;

  const _MessageBubble({
    required this.isMe,
    required this.time,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isMe
                ? LinearGradient(colors: [
                    AppColors.purpleAccent.withOpacity(0.35),
                    AppColors.purpleDeep.withOpacity(0.25),
                  ])
                : null,
            color: isMe ? null : AppColors.surfaceLight,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: isMe
                ? Border.all(
                    color: AppColors.purpleAccent.withOpacity(0.3))
                : Border.all(color: AppColors.whiteAlpha05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              child,
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}