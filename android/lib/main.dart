import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/anomicon_app.dart';
import 'src/local_store.dart';
import 'src/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appVersion = await const MethodChannel('anomicon/app_info')
      .invokeMethod<String>('getVersion');
  if (appVersion == null || appVersion.isEmpty) {
    throw StateError('Android did not return an installed app version');
  }
  final localStore = await LocalStore.create();
  final repository = await AnomiconRepository.create();
  runApp(
    AnomiconApp(
      repository: repository,
      localStore: localStore,
      appVersion: appVersion,
    ),
  );
}
