import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/user_facing_errors.dart';
import '../models/chat_summary_model.dart';
import '../services/chat_service.dart';

class ChatController extends ChangeNotifier {
  ChatController({required String uid}) : _uid = uid {
    _start();
  }

  final String _uid;
  final ChatService _chatService = ChatService();

  List<ChatSummaryModel> _summaries = [];
  List<ChatSummaryModel> get summaries => _summaries;

  int _totalUnread = 0;
  int get totalUnread => _totalUnread;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  StreamSubscription<List<ChatSummaryModel>>? _inboxSub;
  StreamSubscription<int>? _unreadSub;

  void _start() {
    if (_uid.isEmpty) return;
    _inboxSub = _chatService.watchInbox(_uid).listen(
      (list) {
        _summaries = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = messageForFirestore(e);
        _loading = false;
        notifyListeners();
      },
    );
    _unreadSub = _chatService.watchTotalUnread(_uid).listen(
      (count) {
        _totalUnread = count;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _inboxSub?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }
}