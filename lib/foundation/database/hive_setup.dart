import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

class HiveSetup {
  static const String serversBoxName = 'servers';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    await _openBoxes();
  }

  static Future<void> _openBoxes() async {
    await Hive.openBox(serversBoxName);
    await Hive.openBox(settingsBoxName);
  }

  static Box get serversBox => Hive.box(serversBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}
