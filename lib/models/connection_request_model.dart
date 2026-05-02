class ConnectionRequest {
  final int id;
  final String fromUserId;
  final String toUserId;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  ConnectionRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    return ConnectionRequest(
      id: json['id'],
      fromUserId: json['from_user'],
      toUserId: json['to_user'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at']) : null,
    );
  }
}