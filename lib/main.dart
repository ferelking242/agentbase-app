import 'dart:async';
import 'package:flutter/material.dart';
import 'services/github_service.dart';
import 'screens/shell_screen.dart';
import 'theme.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final github = GitHubService();
    try {
      await github.init();
    } catch (e) {
      debugPrint('AgentBase init warning: $e');
    }
    runApp(AgentBaseApp(github: github));
  }, (error, stack) {
    debugPrint('AgentBase fatal error: $error');
    debugPrint('$stack');
    runApp(_ErrorApp(message: error.toString()));
  });
}

class AgentBaseApp extends StatelessWidget {
  final GitHubService github;
  const AgentBaseApp({super.key, required this.github});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AgentBase',
    theme: buildTheme(),
    debugShowCheckedModeBanner: false,
    home: ShellScreen(github: github),
  );
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, size: 48, color: Color(0xFF6366F1)),
              const SizedBox(height: 16),
              const Text('AgentBase',
                style: TextStyle(color: Color(0xFFECECEC), fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Erreur de demarrage\n$message',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
            ],
          ),
        ),
      ),
    ),
  );
}
