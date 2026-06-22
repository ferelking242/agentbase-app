import 'package:flutter/material.dart';
  import 'services/github_service.dart';
  import 'screens/shell_screen.dart';
  import 'theme.dart';

  void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const AgentBaseApp()); }

  class AgentBaseApp extends StatelessWidget {
    const AgentBaseApp({super.key});
    @override
    Widget build(BuildContext context) => MaterialApp(
      title: 'AgentBase', theme: buildTheme(), debugShowCheckedModeBanner: false,
      home: ShellScreen(github: GitHubService()),
    );
  }