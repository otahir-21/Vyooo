import 'dart:async';
import 'username_service.dart';

/// Mock implementation for development. Replace with real API client later.
class MockUsernameService implements UsernameService {
  @override
  Future<UsernameCheckResult> checkAvailability(String username) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final lower = username.toLowerCase();
    // Simulate: reserved names (any case).
    const taken = {'admin', 'vyooo', 'test', 'user', 'support'};
    final available = !taken.contains(lower);
    final suggestions = available
        ? <String>[]
        : <String>[
            '${username}_official',
            '${username}123',
            'the_$username',
            '${username}_app',
          ];
    return UsernameCheckResult(available: available, suggestions: suggestions);
  }

  @override
  Stream<UsernameCheckResult> watchAvailability(
    String username, {
    required String excludeUid,
  }) async* {
    yield await checkAvailability(username);
  }
}
