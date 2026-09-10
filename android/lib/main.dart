import 'package:flutter/material.dart';

import 'src/anomicon_app.dart';
import 'src/local_store.dart';
import 'src/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localStore = await LocalStore.create();
  final repository = await AnomiconRepository.create();
  runApp(AnomiconApp(repository: repository, localStore: localStore));
}
