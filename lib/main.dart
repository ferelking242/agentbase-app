import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/github_service.dart';
import 'screens/shell_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch all Flutter widget build errors and show them visually
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFCC0000),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          'ERREUR:\n${details.exception}\n\n${details.stack}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  };

  // Catch all uncaught Dart errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final github = GitHubService();
  try {
    await github.init();
  } catch (_) {}
  runApp(AgentBaseApp(github: github));
}

class AgentBaseApp extends StatelessWidget {
  final GitHubService github;
  const AgentBaseApp({super.key, required this.github});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AgentBase',
    theme: buildTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.green,
      body: const Center(
        child: Text('FLUTTER MARCHE', style: TextStyle(color: Colors.black, fontSize: 36, fontWeight: FontWeight.bold)),
      ),
    ),
  );
}
