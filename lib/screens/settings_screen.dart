import 'package:flutter/material.dart';
  import '../services/github_service.dart';
  import '../services/prefs_service.dart';
  import '../theme.dart';

  class SettingsScreen extends StatefulWidget {
    final GitHubService github;
    const SettingsScreen({super.key, required this.github});
    @override State<SettingsScreen> createState() => _SettingsScreenState();
  }
  class _SettingsScreenState extends State<SettingsScreen> {
    final _patCtrl = TextEditingController();
    bool _visible = false, _validating = false; bool? _valid;
    @override void initState() { super.initState(); _load(); }
    @override void dispose() { _patCtrl.dispose(); super.dispose(); }
    Future<void> _load() async { final p=await PrefsService.getPat(); if(p!=null&&mounted){_patCtrl.text=p;setState((){});} }
    Future<void> _validate() async {
      final p=_patCtrl.text.trim(); if(p.isEmpty)return;
      setState(() { _validating = true; _valid = null; });
      widget.github.setPat(p); await PrefsService.savePat(p);
      final ok=await widget.github.validatePat();
      if (mounted) setState(() { _validating = false; _valid = ok; });
    }
    Future<void> _clear() async { _patCtrl.clear(); widget.github.setPat(''); await PrefsService.clearPat(); if(mounted)setState(()=>_valid=null); }
    @override
    Widget build(BuildContext context) => Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, elevation: 0,
        leading: GestureDetector(onTap:()=>Navigator.pop(context),
          child: Container(margin:const EdgeInsets.all(8), decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(7),border:Border.all(color:kBorder)),
            child:const Icon(Icons.arrow_back_ios_new,size:13,color:kMuted2))),
        title:const Text('Parametres'),
        bottom:const PreferredSize(preferredSize:Size.fromHeight(0.5),child:Divider(height:0.5,color:kBorder))),
      body: ListView(padding:const EdgeInsets.all(20), children:[
        _lbl('GITHUB TOKEN (PAT)'), const SizedBox(height:4),
        const Text("Requis pour lire et ecrire les prompts dans le depot GitHub.", style:TextStyle(color:kMuted,fontSize:12,height:1.5)),
        const SizedBox(height:12),
        Container(
          decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(10),border:Border.all(color:_valid==true?kGreen:_valid==false?kRed:kBorder)),
          padding:const EdgeInsets.all(14),
          child:Column(children:[
            TextField(controller:_patCtrl, obscureText:!_visible,
              style:const TextStyle(color:kText,fontSize:12.5,fontFamily:'monospace'),
              decoration:InputDecoration(hintText:'ghp_xxxxxxxxxxxxxxxxxxxx',hintStyle:const TextStyle(color:kMuted,fontFamily:'monospace'),
                border:InputBorder.none,isDense:true,contentPadding:EdgeInsets.zero,
                suffixIcon:GestureDetector(onTap:()=>setState(()=>_visible=!_visible),
                  child:Icon(_visible?Icons.visibility_off_outlined:Icons.visibility_outlined,size:16,color:kMuted)))),
            const SizedBox(height:12),
            Row(children:[
              if(_valid!=null) Row(children:[
                Icon(_valid!?Icons.check_circle_outline:Icons.error_outline,size:13,color:_valid!?kGreen:kRed),
                const SizedBox(width:5),
                Text(_valid!?'Token valide':'Token invalide',style:TextStyle(color:_valid!?kGreen:kRed,fontSize:11.5,fontWeight:FontWeight.w600)),
              ]),
              const Spacer(),
              if(_patCtrl.text.isNotEmpty) GestureDetector(onTap:_clear,child:const Text('Effacer',style:TextStyle(color:kMuted,fontSize:12))),
              const SizedBox(width:12),
              GestureDetector(onTap:_validating?null:_validate,
                child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:7),
                  decoration:BoxDecoration(color:kAccent,borderRadius:BorderRadius.circular(8)),
                  child:_validating?const SizedBox(width:13,height:13,child:CircularProgressIndicator(color:Colors.white,strokeWidth:1.5)):const Text('Valider',style:TextStyle(color:Colors.white,fontSize:12.5,fontWeight:FontWeight.w600)))),
            ]),
          ])),
        const SizedBox(height:28), _lbl('DEPOT'), const SizedBox(height:10),
        _row('Owner','ferelking242'), _row('Repo','agentbase'), _row('Site','ferelking242.github.io/agentbase'),
        const SizedBox(height:28), _lbl('APPLICATION'), const SizedBox(height:10),
        _row('Version','3.0.0'),
      ]),
    );
    Widget _lbl(String t) => Text(t, style:const TextStyle(color:kMuted,fontSize:9.5,fontWeight:FontWeight.w700,letterSpacing:0.8));
    Widget _row(String l, String v) => Container(margin:const EdgeInsets.only(bottom:1),padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
      decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(7),border:Border.all(color:kBorder)),
      child:Row(children:[Text(l,style:const TextStyle(color:kMuted2,fontSize:12.5)),const Spacer(),Text(v,style:const TextStyle(color:kText2,fontSize:12,fontFamily:'monospace'))]));
  }