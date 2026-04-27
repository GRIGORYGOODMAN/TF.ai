import 'package:flutter/material.dart';

import 'chat_home_page.dart';

void main() {
  runApp(const TfAiApp());
}

class TfAiApp extends StatelessWidget {
  const TfAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TF.ai',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffb14c70),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff14171d),
      ),
      home: const ChatHomePage(),
    );
  }
}
