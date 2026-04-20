import 'package:flutter/widgets.dart';

/// Global route observer used to pause/resume media when routes change.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
