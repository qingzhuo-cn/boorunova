import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StyledOverlayRegion extends StatelessWidget {
  const StyledOverlayRegion({
    super.key,
    required this.child,
    this.nightMode = false,
  });

  final Widget child;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final brightness =
        nightMode ? Brightness.dark : Theme.of(context).brightness;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor:
            brightness == Brightness.dark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
    return child;
  }
}
