abstract final class ChatCollections {
  static const String chats = 'chats';
  static const String messages = 'messages';
  static const String users = 'users';
  static const String chatSummaries = 'chatSummaries';
}

abstract final class ChatLimits {
  static const int messagePreviewMaxLength = 100;
  static const int initialMessagePageSize = 40;
  static const int maxGroupSize = 256;
  static const int minGroupSize = 3;
  static const int deleteForEveryoneWindowMinutes = 15;
}

abstract final class ChatMessageTypes {
  static const String text = 'text';
  static const String image = 'image';
  static const String video = 'video';
  static const String audio = 'audio';
  static const String gif = 'gif';
  static const String system = 'system';
  static const String call = 'call';
}

abstract final class ChatTypes {
  static const String direct = 'direct';
  static const String group = 'group';
}

abstract final class RequestStatus {
  static const String none = 'none';
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
}
