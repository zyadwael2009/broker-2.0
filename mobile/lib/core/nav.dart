import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/models.dart' show UserDto;
import '../router.dart' show landingFor;

/// Pop with fallback to the role's landing when the route stack is
/// empty (deep link, share link, notification). `context.pop()` on a
/// route with no parent is a no-op — users tapping the back arrow after
/// deep-linking into `/listings/42` would otherwise see nothing happen.
void safePop<T>(BuildContext context, {UserDto? forRole, T? result}) {
  if (context.canPop()) {
    context.pop<T>(result);
    return;
  }
  context.go(landingFor(forRole?.role));
}

/// Convenience — no result to return.
void safePopVoid(BuildContext context, {UserDto? forRole}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(landingFor(forRole?.role));
}
