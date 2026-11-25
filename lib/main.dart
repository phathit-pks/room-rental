import 'package:flutter/material.dart';
import 'package:room_rental/app/app.dart';
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/core/theme/theme_store.dart';
import 'package:room_rental/features/locations/data/location_store.dart';

import 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'package:flutter_web_plugins/url_strategy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await SupabaseConfig.initialize();
  await LocationStore.instance.load();
  await ThemeStore.instance.load();
  runApp(const RoomRentalApp());
}
