import 'package:flutter/material.dart';
  import 'package:url_launcher/url_launcher.dart';
  import '../services/github_service.dart';
  import '../theme.dart';
  import 'home_screen.dart';
  import 'rooms_screen.dart';
  import 'problems_screen.dart';
  import 'settings_screen.dart';

  class ShellScreen extends StatefulWidget {
    final GitHubService github;
    const ShellScreen({super.key, required this.github});
    @override
    State<ShellScreen> createState() => _ShellScreenState();
  }

  class _ShellScreenState extends State<ShellScreen> {
    int _page = 0;
    final _titles = ['Accueil','Problemes & Solutions','Rooms'];

    void _goto(int p) { setState(() => _page = p); Navigator.of(context).pop(); }

    @override
    Widget build(BuildContext context) {
      final body = [
        HomeScreen(github: widget.github, onSection: (i) => setState(() => _page = i)),
        ProblemsScreen(github: widget.github),
        RoomsScreen(github: widget.github),
      ][_page];

      return Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kSidebar,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Builder(builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 20, color: kMuted2),
            onPressed: () => Scaffold.of(ctx).openDrawer())),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 22, height: 22,
              decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.bolt, size: 13, color: Colors.white)),
            const SizedBox(width: 8),
            const Text('AgentBase', style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ]),
          centerTitle: true,
          bottom: const PreferredSize(preferredSize: Size.fromHeight(0.5), child: Divider(height: 0.5, color: kBorder)),
        ),
        drawer: _Drawer(current: _page, onTap: _goto, onSettings: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(github: widget.github)));
        }),
        floatingActionButton: FloatingActionButton(
          backgroundColor: kSurface2,
          onPressed: () => launchUrl(Uri.parse('https://github.com/ferelking242/agentbase'), mode: LaunchMode.externalApplication),
          child: const Icon(Icons.code, color: kMuted2, size: 20),
          mini: true,
          tooltip: 'GitHub',
        ),
        body: body,
      );
    }
  }

  class _Drawer extends StatelessWidget {
    final int current;
    final ValueChanged<int> onTap;
    final VoidCallback onSettings;
    const _Drawer({required this.current, required this.onTap, required this.onSettings});

    @override
    Widget build(BuildContext context) {
      return Drawer(
        backgroundColor: kSidebar,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder, width: 0.5))),
            child: Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.bolt, size: 18, color: Colors.white)),
              const SizedBox(width: 10),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AgentBase', style: TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                Text('ferelking242', style: TextStyle(color: kMuted, fontSize: 11)),
              ]),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14,16,14,6),
            child: const Align(alignment: Alignment.centerLeft, child: Text('NAVIGATION', style: TextStyle(color: kMuted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8)))),
          _NavItem(icon: Icons.home_outlined,      label: 'Accueil',                  sel: current==0, onTap: () => onTap(0)),
          _NavItem(icon: Icons.lightbulb_outlined, label: "Problemes & Solutions",    sel: current==1, onTap: () => onTap(1)),
          _NavItem(icon: Icons.workspaces_outlined, label: 'Rooms',                   sel: current==2, onTap: () => onTap(2)),
          const Spacer(),
          const Divider(color: kBorder, height: 0.5),
          _NavItem(icon: Icons.settings_outlined, label: 'Parametres', sel: false, onTap: onSettings),
          const SizedBox(height: 12),
        ]),
      );
    }
  }

  class _NavItem extends StatelessWidget {
    final IconData icon; final String label; final bool sel; final VoidCallback onTap;
    const _NavItem({required this.icon, required this.label, required this.sel, required this.onTap});
    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: sel ? kSurface2 : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, size: 16, color: sel ? kAccentL : kMuted2),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: sel ? kText : kText2, fontSize: 13.5, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }