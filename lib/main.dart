import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'horizon_page.dart';
// Referenced so the @pragma('vm:entry-point') `overlayMain` is retained by
// the tree-shaker and reachable when flutter_overlay_window spawns its
// secondary isolate.
// ignore: unused_import
import 'overlay/overlay_entrypoint.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const KinetosisApp());
}

class KinetosisApp extends StatelessWidget {
  const KinetosisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kinetosis Horizon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const HorizonPage(),
    );
  }
}
