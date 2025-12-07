class NotificationItemModel {
  final String title;
  final String message;
  final String time;
  final bool isRead;

  NotificationItemModel({
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'time': time,
      'isRead': isRead,
    };
  }

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      title: json['title'] as String,
      message: json['message'] as String,
      time: json['time'] as String,
      isRead: json['isRead'] as bool,
    );
  }
}
