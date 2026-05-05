import '../models/message_model.dart';

enum ViewOnceState {
  unopenedRecipient,
  openedRecipient,
  senderDirect,
  senderGroup,
  expired,
}

class ViewOnceHelpers {
  ViewOnceHelpers._();

  static ViewOnceState state({
    required MessageModel message,
    required String currentUid,
    required bool isGroup,
  }) {
    final mediaUrl = message.mediaUrl ?? '';
    final storagePath = message.storagePath ?? '';
    final cleanedUp = message.metadata['cleanedUpAt'] != null;

    if (cleanedUp || (mediaUrl.isEmpty && storagePath.isEmpty)) {
      return ViewOnceState.expired;
    }

    final isSender = message.senderId == currentUid;
    if (isSender) {
      return isGroup ? ViewOnceState.senderGroup : ViewOnceState.senderDirect;
    }

    if (message.viewedBy.contains(currentUid)) {
      return ViewOnceState.openedRecipient;
    }

    return ViewOnceState.unopenedRecipient;
  }

  static bool canOpen({
    required MessageModel message,
    required String currentUid,
  }) {
    if (message.senderId == currentUid) return false;
    if (message.viewedBy.contains(currentUid)) return false;
    final mediaUrl = message.mediaUrl ?? '';
    if (mediaUrl.isEmpty) return false;
    if (message.metadata['cleanedUpAt'] != null) return false;
    return true;
  }

  static String displayLabel({
    required MessageModel message,
    required String currentUid,
    required bool isGroup,
  }) {
    final s = state(
      message: message,
      currentUid: currentUid,
      isGroup: isGroup,
    );
    final isVideo = message.type == 'video';
    switch (s) {
      case ViewOnceState.unopenedRecipient:
        return isVideo ? 'View video' : 'View photo';
      case ViewOnceState.openedRecipient:
        return 'Opened';
      case ViewOnceState.senderDirect:
        return isVideo ? 'View-once video' : 'View-once photo';
      case ViewOnceState.senderGroup:
        final count = message.viewedBy.length;
        if (count == 0) {
          return isVideo ? 'View-once video' : 'View-once photo';
        }
        return 'Viewed by $count';
      case ViewOnceState.expired:
        return 'No longer available';
    }
  }
}
