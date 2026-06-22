import 'package:flutter/material.dart';
  import 'services/github_service.dart';
  import 'screens/home_screen.dart';
  import 'theme.dart';

  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(AgentBaseApp());
  }

  class AgentBaseApp extends StatelessWidget {
    final _github = GitHubService();
    AgentBaseApp({super.key});
    @override
    Widget build(BuildContext context) => MaterialApp(
      title: 'AgentBase',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: HomeScreen(github: _github),
    );
  }