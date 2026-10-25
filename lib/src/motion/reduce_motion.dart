import 'package:flutter/widgets.dart';

/// Whether the user has asked for less motion, on every platform.
///
/// Android ("Remove animations") reports `disableAnimations`, which
/// [MediaQuery] exposes. iOS Reduce Motion reports only the engine's
/// `reduceMotion` accessibility feature, which [MediaQueryData] does not
/// carry, so it is read from the view's platform dispatcher as well.
bool reduceMotionOf(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return true;
  return View.maybeOf(context)?.platformDispatcher.accessibilityFeatures.reduceMotion ?? false;
}
