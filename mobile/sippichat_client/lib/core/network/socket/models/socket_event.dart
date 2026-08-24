class SocketEvent {
  final String type;
  final Map<String, dynamic> data;

  const SocketEvent({
    required this.type,
    required this.data,
  });

  factory SocketEvent.fromJson(Map<String, dynamic> json) {
    return SocketEvent(
      type: json['type'] as String,
      data: json,
    );
  }
}