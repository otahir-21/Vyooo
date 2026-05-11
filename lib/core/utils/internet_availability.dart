import 'internet_availability_io.dart' if (dart.library.html) 'internet_availability_web.dart' as impl;

/// Same copy as auth and [messageForFirestore] for offline / transport failures.
const String kNoInternetUserMessage =
    'No internet connection. Check your network and try again.';

Future<bool> hasInternetAccess() => impl.hasInternetAccess();
