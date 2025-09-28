import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  String _key(String ncode) => 'progress:$ncode';

  Future<int> loadOffset(String ncode) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt(_key(ncode)) ?? 0;
    // 将来的には episodeNo + pageIndex/charOffset へ拡張
  }

  Future<void> saveOffset(String ncode, int offset) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_key(ncode), offset);
  }
}
