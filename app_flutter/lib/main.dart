import 'package:flutter/material.dart';

import 'ui/home_page.dart';
import 'ui/theme.dart';

void main() => runApp(const SisaKulkasApp());

class SisaKulkasApp extends StatelessWidget {
  const SisaKulkasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SisaKulkas',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomePage(),
    );
  }
}
