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

abstract final class ChatReactionEmojis {
  static const String defaultReaction = '❤️';

  static const List<String> quickPick = [
    '❤️',
    '😂',
    '🔥',
    '👏',
    '😮',
    '😢',
    '😍',
    '👍',
  ];
}

abstract final class ChatAssets {
  static const String searchBar = 'assets/vyooO_icons/Chat/search_bar.svg';
  static const String yourNoteLabel = 'assets/vyooO_icons/Chat/your_note.svg';
  static const String noteBubble = 'assets/vyooO_icons/Chat/note_bubble.svg';
  static const String messagesTitle =
      'assets/vyooO_icons/Chat/messages_title.svg';
  static const String requestsTitle =
      'assets/vyooO_icons/Chat/requests_title.svg';
  static const String newChatIcon = 'assets/vyooO_icons/Chat/new_chat.svg';
  static const String chatUnreadDot =
      'assets/vyooO_icons/Chat/chat_unread_dot.svg';
  static const String chatTileCamera =
      'assets/vyooO_icons/Chat/chat_tile_camera.svg';
  static const String chatForwardButton =
      'assets/vyooO_icons/Chat/chat_forward_button.svg';
  static const String inputGalleryIcon =
      'assets/vyooO_icons/Chat/input_gallery.svg';
  static const String inputStickerIcon =
      'assets/vyooO_icons/Chat/input_sticker.svg';
  static const String audioCallIcon = 'assets/vyooO_icons/Chat/audio_call.svg';
  static const String videoCallIcon = 'assets/vyooO_icons/Chat/video_call.svg';
}
