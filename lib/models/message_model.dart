class Message {
  final int id;
  final String roomId;
  final String senderId;
  final String content;
  final String? fileUrl;
  final String? fileType;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.fileUrl,
    this.fileType,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      fileUrl: json['file_url'],
      fileType: json['file_type'],
      createdAt: DateTime.parse(json['created_at']),
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }
}