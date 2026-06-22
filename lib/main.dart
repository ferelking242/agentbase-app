import 'dart:async';
import 'package:flutter/material.dart';
import 'services/github_service.dart';
import 'screens/shell_screen.dart';
import 'theme.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final github = GitHubService();
    await github.init();
    runApp(AgentBaseApp(github: github));
  }, (error, stack) {
    debugPrint('AgentBase fatal error: $error');
    debugPrint('$stack');
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
