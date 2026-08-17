class SocketEvent {

  final String type;
  final Map<String, dynamic> payload;

  SocketEvent({
    required this.type,
    required this.payload,
});

  factory SocketEvent.fromJson(Map<String,dynamic> json){
    return SocketEvent(type: json["type"] as String, payload: Map<String, dynamic>.from(json["payload"] as Map));
  }
}