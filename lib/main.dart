import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:room_rental/app/app.dart';
import 'package:room_rental/core/config/supabase_config.dart';
import 'package:room_rental/features/locations/data/location_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await SupabaseConfig.initialize();
  await LocationStore.instance.load();
  runApp(const RoomRentalApp());
}
