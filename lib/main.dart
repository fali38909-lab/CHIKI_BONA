import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

const String defaultApiBase = 'http://157.20.104.34:8000';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChikiBonaApp());
}

class ChikiBonaApp extends StatelessWidget {
  const ChikiBonaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CHIKI BONA',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070812),
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
          brightness: Brightness.dark,
        ),
      ),
      home: const ChikiBonaHome(),
    );
  }
}

class VideoItem {
  final String id;
  final String title;
  final String folder;
  final String status;
  final String? streamUrl;
  final String? thumbnailUrl;
  final int? fileSize;
  final double? duration;
  final double? modified;

  const VideoItem({
    required this.id,
    required this.title,
    required this.folder,
    required this.status,
    this.streamUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.duration,
    this.modified,
  });

  factory VideoItem.fromJson(Map<String, dynamic> j, String base) {
    return VideoItem(
      id: '${j['id'] ?? j['name'] ?? ''}',
      title: '${j['name'] ?? 'Untitled Video'}',
      folder: '${j['folder'] ?? 'All Videos'}',
      status: '${j['status'] ?? 'Ready'}',
      streamUrl: _absoluteUrl(base, j['stream_url'] ?? (j['video'] != null ? '/video/${j['video']}' : null)),
      thumbnailUrl: _absoluteUrl(base, j['thumbnail_url'] ?? (j['thumbnail'] != null ? '/thumbnail/${j['thumbnail']}' : null)),
      fileSize: _toInt(j['file_size']),
      duration: _toDouble(j['duration']),
      modified: _toDouble(j['modified']),
    );
  }

  static String? _absoluteUrl(String base, dynamic value) {
    if (value == null || '$value'.isEmpty) return null;
    final s = '$value';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return '${base.replaceFirst(RegExp(r'/*$'), '')}/${s.replaceFirst(RegExp(r'^/+'), '')}';
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse('$value');
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

class ChikiApi {
  final String baseUrl;
  ChikiApi(String baseUrl) : baseUrl = _clean(baseUrl);

  static String _clean(String value) => value.trim().replaceFirst(RegExp(r'/*$'), '');

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> health() async {
    final r = await http.get(_uri('/api/v1/health')).timeout(const Duration(seconds: 15));
    return _json(r);
  }

  Future<List<String>> folders() async {
    final r = await http.get(_uri('/api/v1/folders')).timeout(const Duration(seconds: 15));
    final data = _json(r);
    return List<String>.from(data['folders'] ?? const []);
  }

  Future<List<VideoItem>> videos({
    String query = '',
    String folder = '',
    String status = '',
    String sort = 'name_asc',
  }) async {
    final params = <String, String>{'sort': sort};
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (folder.isNotEmpty && folder != 'All Videos') params['folder'] = folder;
    if (status.isNotEmpty) params['status'] = status;
    final r = await http.get(_uri('/api/v1/videos', params)).timeout(const Duration(seconds: 20));
    final data = _json(r);
    final list = (data['videos'] as List? ?? const []);
    return list.map((x) => VideoItem.fromJson(Map<String, dynamic>.from(x), baseUrl)).toList();
  }

  Future<VideoItem> video(String id) async {
    final r = await http.get(_uri('/api/v1/videos/${Uri.encodeComponent(id)}')).timeout(const Duration(seconds: 15));
    final data = _json(r);
    return VideoItem.fromJson(Map<String, dynamic>.from(data['video'] ?? {}), baseUrl);
  }

  Future<Map<String, dynamic>> upload({
    required String path,
    required String filename,
    required String folder,
    required String pin,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/upload'));
    request.headers['X-Upload-PIN'] = pin;
    request.fields['folder'] = folder.isEmpty ? 'All Videos' : folder;
    request.files.add(await http.MultipartFile.fromPath('video', path, filename: filename));
    final streamed = await request.send().timeout(const Duration(minutes: 30));
    final body = await streamed.stream.bytesToString();
    final data = body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(body));
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Upload failed.', streamed.statusCode);
    }
    return data;
  }

  Map<String, dynamic> _json(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Server returned ${response.statusCode}.', response.statusCode);
    }
    return data;
  }
}

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}

class AnimatedAurora extends StatefulWidget {
  const AnimatedAurora({super.key});
  @override
  State<AnimatedAurora> createState() => _AnimatedAuroraState();
}

class _AnimatedAuroraState extends State<AnimatedAurora> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(child: AnimatedBuilder(
    animation: _controller,
    builder: (_, __) => CustomPaint(painter: _AuroraPainter(_controller.value * math.pi * 2), size: Size.infinite),
  ));
}

class _AuroraPainter extends CustomPainter {
  final double angle;
  _AuroraPainter(this.angle);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF070812), Color(0xFF0B0D20), Color(0xFF10091A)],
    ).createShader(rect));
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(center, radius, Paint()..shader = RadialGradient(
        colors: [color.withOpacity(.20), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius)));
    }
    glow(Offset(size.width * .10 + math.sin(angle) * 50, size.height * .03), 260, const Color(0xFF8B5CF6));
    glow(Offset(size.width * .90 + math.cos(angle * .8) * 55, size.height * .12), 250, const Color(0xFF38BDF8));
    glow(Offset(size.width * .50 + math.sin(angle * .65) * 70, size.height * .98), 290, const Color(0xFFF472B6));
  }
  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.angle != angle;
}

class ChikiBonaHome extends StatefulWidget {
  const ChikiBonaHome({super.key});
  @override
  State<ChikiBonaHome> createState() => _ChikiBonaHomeState();
}

class _ChikiBonaHomeState extends State<ChikiBonaHome> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _server = TextEditingController(text: defaultApiBase);
  final TextEditingController _pin = TextEditingController();
  late ChikiApi _api;
  Timer? _syncTimer;
  List<String> folders = ['All Videos'];
  List<VideoItem> videos = [];
  String _selectedFolder = 'All Videos';
  String _sort = 'Name A-Z';
  int _navIndex = 0;
  bool _loading = true;
  bool _busy = false;
  bool _online = false;
  String _statusText = 'Connecting to server...';

  @override
  void initState() {
    super.initState();
    _api = ChikiApi(defaultApiBase);
    _loadAll();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) => _silentSync());
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _search.dispose(); _server.dispose(); _pin.dispose();
    super.dispose();
  }

  Future<void> _loadAll({bool showLoader = true}) async {
    if (showLoader) setState(() { _loading = true; _statusText = 'Loading library...'; });
    try {
      final f = await _api.folders();
      final v = await _api.videos(query: _search.text, folder: _selectedFolder, sort: _sortValue);
      if (!mounted) return;
      final fs = ['All Videos', ...f.where((x) => x != 'All Videos')];
      setState(() { folders = fs.toSet().toList(); videos = v; _online = true; _loading = false; _statusText = '${v.length} videos • server online'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _online = false; _loading = false; _statusText = _friendlyError(e); });
    }
  }

  Future<void> _silentSync() async {
    if (_busy) return;
    try {
      final v = await _api.videos(query: _search.text, folder: _selectedFolder, sort: _sortValue);
      final f = await _api.folders();
      if (!mounted) return;
      setState(() {
        videos = v;
        folders = ['All Videos', ...f.where((x) => x != 'All Videos')].toSet().toList();
        _online = true;
        _statusText = '${v.length} videos • synced';
      });
    } catch (_) {
      if (mounted) setState(() => _online = false);
    }
  }

  String get _sortValue {
    switch (_sort) {
      case 'Name Z-A': return 'name_desc';
      case 'Newest': return 'newest';
      case 'Oldest': return 'oldest';
      case 'Largest': return 'size_desc';
      case 'Smallest': return 'size_asc';
      case 'Longest': return 'duration_desc';
      case 'Shortest': return 'duration_asc';
      default: return 'name_asc';
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return e.message;
    return 'Server connection failed.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: AnimatedAurora()),
        SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 850;
          return Column(children: [
            _topBar(desktop),
            Expanded(child: _navIndex == 0 ? _home(desktop) : _navIndex == 1 ? _foldersPage(desktop) : _settingsPage(desktop)),
          ]);
        })),
      ]),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _topBar(bool desktop) => Padding(
    padding: EdgeInsets.fromLTRB(desktop ? 22 : 12, 12, desktop ? 22 : 12, 8),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xCC090A14), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(.10)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 35, offset: const Offset(0,15))]),
      child: Row(children: [
        _brand(desktop), const SizedBox(width: 14), Expanded(child: _searchBox()),
        if (desktop) ...[const SizedBox(width: 12), _onlinePill()]
      ]),
    ),
  );

  Widget _brand(bool desktop) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: desktop ? 44 : 38, height: desktop ? 44 : 38, decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFFEC4899)]), boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(.45), blurRadius: 22)]), child: Center(child: Text('CB', style: TextStyle(fontSize: desktop ? 17 : 14, fontWeight: FontWeight.w900)))),
    const SizedBox(width: 10),
    if (desktop) const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ _GradientText('CHIKI BONA', 20), Text('PREMIUM VIDEO', style: TextStyle(color: Color(0xFF858BAA), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w600)) ]) else const _GradientText('CHIKI BONA', 16),
  ]);

  Widget _searchBox() => TextField(
    controller: _search,
    onChanged: (_) => _loadAll(showLoader: false),
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(hintText: 'Search videos...', hintStyle: const TextStyle(color: Color(0xFF737B9E), fontSize: 12), prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8990B0)), filled: true, fillColor: Colors.white.withOpacity(.045), contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(.09))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(.09))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xAA8B5CF6))),
    ),
  );

  Widget _onlinePill() => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: const Color(0x1238BDF8), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0x3038BDF8))), child: Row(children: [Icon(Icons.circle, size: 7, color: _online ? const Color(0xFF22C55E) : Colors.redAccent), const SizedBox(width: 7), Text(_online ? 'ONLINE' : 'OFFLINE', style: const TextStyle(color: Color(0xFFA5F3FC), fontSize: 11, fontWeight: FontWeight.w800))]));

  Widget _home(bool desktop) => RefreshIndicator(
    onRefresh: () => _loadAll(showLoader: false),
    child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(desktop ? 22 : 12, 8, desktop ? 22 : 12, 90), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _hero(desktop), const SizedBox(height: 24), _sectionTitle('CHIKI BONA LIBRARY', 'Select a folder'), const SizedBox(height: 12), _folderStrip(desktop), const SizedBox(height: 24),
      Row(children: [const Text('Video Collection', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const Spacer(), PopupMenuButton<String>(initialValue: _sort, onSelected: (v) { setState(() => _sort = v); _loadAll(showLoader: false); }, itemBuilder: (_) => const [PopupMenuItem(value:'Name A-Z',child:Text('Name A-Z')),PopupMenuItem(value:'Name Z-A',child:Text('Name Z-A')),PopupMenuItem(value:'Newest',child:Text('Newest')),PopupMenuItem(value:'Oldest',child:Text('Oldest')),PopupMenuItem(value:'Largest',child:Text('Largest')),PopupMenuItem(value:'Smallest',child:Text('Smallest')),PopupMenuItem(value:'Longest',child:Text('Longest')),PopupMenuItem(value:'Shortest',child:Text('Shortest'))], child: _sortButton())]),
      const SizedBox(height: 13), Text(_statusText, style: const TextStyle(color: Color(0xFF737B9E), fontSize: 11)), const SizedBox(height: 14),
      if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())) else if (videos.isEmpty) _empty() else GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: videos.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: desktop ? 3 : 1, crossAxisSpacing: 18, mainAxisSpacing: 18, childAspectRatio: desktop ? 1.48 : 1.42), itemBuilder: (_, i) => _videoCard(videos[i])),
    ])),
  );

  Widget _hero(bool desktop) => Container(width: double.infinity, padding: EdgeInsets.all(desktop ? 40 : 26), decoration: BoxDecoration(borderRadius: BorderRadius.circular(desktop ? 28 : 22), gradient: const LinearGradient(begin: Alignment.topLeft,end: Alignment.bottomRight,colors:[Color(0x667C3AED),Color(0x332563EB),Color(0x55EC4899)]), border: Border.all(color: Colors.white.withOpacity(.10)), boxShadow:[BoxShadow(color:Colors.black.withOpacity(.38),blurRadius:55,offset:const Offset(0,20))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(color:const Color(0x1F8B5CF6),borderRadius:BorderRadius.circular(99),border:Border.all(color:const Color(0x33C4B5FD))),child:const Text('CHIKI BONA COLLECTION',style:TextStyle(color:Color(0xFFDDD6FE),fontSize:10,fontWeight:FontWeight.w900,letterSpacing:1.5))),const SizedBox(height:14),_GradientText('Watch.\nEnjoy.',desktop?62:45,bold:true),const SizedBox(height:10),const Text('Explore your premium video collection\nin a smooth, modern and cinematic experience.',style:TextStyle(color:Color(0xFFC4C8DF),height:1.55,fontSize:13))]));

  Widget _sectionTitle(String badge, String title) => Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(badge,style:const TextStyle(color:Color(0xFFA5B4FC),fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.5)),const SizedBox(height:5),Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800))]);

  Widget _folderStrip(bool desktop) {
    return SizedBox(
      height: desktop ? 118 : 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final folder = folders[i];
          final active = _selectedFolder == folder;
          final count = folder == 'All Videos'
              ? videos.length
              : videos.where((v) => v.folder == folder).length;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedFolder = folder);
              _loadAll(showLoader: false);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: desktop ? 178 : 145,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: LinearGradient(
                  colors: active
                      ? const [Color(0x5534D399), Color(0x332563EB)]
                      : const [Color(0xFF171725), Color(0xFF0F1018)],
                ),
                border: Border.all(
                  color: active
                      ? const Color(0xAA8B5CF6)
                      : Colors.white.withOpacity(.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📁', style: TextStyle(fontSize: 27)),
                  const Spacer(),
                  Text(
                    folder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count videos',
                    style: const TextStyle(
                      color: Color(0xFF737B9E),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sortButton() => Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),decoration:BoxDecoration(color:const Color(0x18141422),borderRadius:BorderRadius.circular(10),border:Border.all(color:Colors.white.withOpacity(.10))),child:Row(children:[const Icon(Icons.sort_rounded,size:15),const SizedBox(width:5),Text(_sort,style:const TextStyle(fontSize:10))]));

  Widget _videoCard(VideoItem v) => InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>_openPlayer(v),child:Container(clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),color:const Color(0xB2121426),border:Border.all(color:Colors.white.withOpacity(.10)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.25),blurRadius:30,offset:const Offset(0,14))]),child:Column(children:[Expanded(child:Stack(fit:StackFit.expand,children:[
    if (v.thumbnailUrl != null) Image.network(v.thumbnailUrl!, fit: BoxFit.cover, errorBuilder:(_,__,___)=>_thumbFallback()) else _thumbFallback(),
    Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,Colors.black.withOpacity(.55)])))),
    Center(child:Container(width:56,height:56,decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[Color(0xFF8B5CF6),Color(0xFF2563EB),Color(0xFFEC4899)]),boxShadow:[BoxShadow(color:const Color(0xFF8B5CF6).withOpacity(.55),blurRadius:28)]),child:const Icon(Icons.play_arrow_rounded,size:31))),
    Positioned(right:9,bottom:8,child:_badge(_durationText(v.duration))),
  ])),Padding(padding:const EdgeInsets.all(13),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(v.title,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:12,height:1.45,fontWeight:FontWeight.w800)),const SizedBox(height:7),Text('${v.folder} • ${_sizeText(v.fileSize)}',style:const TextStyle(color:Color(0xFF737B9E),fontSize:9))])),const Icon(Icons.chevron_right_rounded,color:Color(0xFF737B9E))]))])));

  Widget _thumbFallback() => Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF24145C),Color(0xFF143B67),Color(0xFF5A194D)])),child:const Center(child:Icon(Icons.movie_filter_rounded,size:54,color:Color(0xBFFFFFFF))));
  Widget _badge(String text)=>Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:4),decoration:BoxDecoration(color:Colors.black.withOpacity(.78),borderRadius:BorderRadius.circular(5)),child:Text(text,style:const TextStyle(fontSize:8)));
  Widget _empty()=>Container(width:double.infinity,padding:const EdgeInsets.all(45),decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white.withOpacity(.10))),child:const Column(children:[Icon(Icons.video_library_outlined,size:45,color:Color(0xFF737B9E)),SizedBox(height:10),Text('No videos found',style:TextStyle(color:Color(0xFF9EA4C7)))]));

  Widget _foldersPage(bool desktop) => SingleChildScrollView(padding:EdgeInsets.fromLTRB(desktop?22:12,20,desktop?22:12,90),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_sectionTitle('LIVE FROM VPS','All folders'),const SizedBox(height:16),...folders.map((f){final c=f=='All Videos'?videos.length:videos.where((v)=>v.folder==f).length;return Padding(padding:const EdgeInsets.only(bottom:10),child:ListTile(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16),side:BorderSide(color:Colors.white.withOpacity(.08))),tileColor:const Color(0x99121426),leading:const Icon(Icons.folder_rounded,color:Color(0xFFA78BFA)),title:Text(f,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('$c videos',style:const TextStyle(color:Color(0xFF737B9E))),trailing:const Icon(Icons.chevron_right),onTap:(){setState(()=>_selectedFolder=f);_navIndex=0;_loadAll();}));})]));

  Widget _settingsPage(bool desktop) => SingleChildScrollView(padding:EdgeInsets.fromLTRB(desktop?22:12,20,desktop?22:12,90),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_sectionTitle('CONNECTION','Server settings'),const SizedBox(height:16),Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xB2121426),borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white.withOpacity(.10))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('VPS API URL',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),TextField(controller:_server,decoration:const InputDecoration(hintText:'http://IP:PORT',prefixIcon:Icon(Icons.cloud_rounded))),const SizedBox(height:12),const Text('Upload PIN',style:TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:8),TextField(controller:_pin,obscureText:true,decoration:const InputDecoration(hintText:'Enter upload PIN',prefixIcon:Icon(Icons.lock_rounded))),const SizedBox(height:16),Row(children:[Expanded(child:ElevatedButton.icon(onPressed:_applyServer,icon:const Icon(Icons.link_rounded),label:const Text('CONNECT'))),const SizedBox(width:10),IconButton(onPressed:()=>_showHealth(),icon:const Icon(Icons.monitor_heart_rounded))]),const SizedBox(height:12),Text(_statusText,style:TextStyle(color:_online?const Color(0xFF86EFAC):const Color(0xFFFCA5A5),fontSize:11))]))]));

  Future<void> _applyServer() async { FocusScope.of(context).unfocus(); final value=_server.text.trim(); if(value.isEmpty)return; setState(()=>_busy=true); try { _api=ChikiApi(value); await _loadAll(); if(mounted) _showSnack('Server connected.'); } catch(e) { if(mounted)_showSnack(_friendlyError(e)); } finally { if(mounted)setState(()=>_busy=false); } }

  Future<void> _showHealth() async { try { final h=await _api.health(); if(!mounted)return; final v=Map<String,dynamic>.from(h['videos']??{}); showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('CHIKI BONA SERVER'),content:Text('API: ${h['api_version'] ?? '1.0'}\nTotal: ${v['total'] ?? 0}\nReady: ${v['ready'] ?? 0}\nProcessing: ${v['processing'] ?? 0}\nFailed: ${v['failed'] ?? 0}'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('OK'))])); } catch(e){if(mounted)_showSnack(_friendlyError(e));}}

  Future<void> _pickAndUpload() async {
    if (_pin.text.trim().isEmpty) { _showUploadPinDialog(); return; }
    final result=await FilePicker.platform.pickFiles(type:FileType.video,allowMultiple:true,withData:false);
    if(result==null)return;
    setState(()=>_busy=true);
    try {
      final folder=_selectedFolder=='All Videos'?'All Videos':_selectedFolder;
      for(final f in result.files){
        final path = f.path;
        if(path == null || path.isEmpty) { _showSnack('Could not read ${f.name}.'); continue; }
        await _api.upload(path:path,filename:f.name,folder:folder,pin:_pin.text.trim());
      }
      if(mounted)_showSnack('${result.files.length} video(s) uploaded. Processing will continue on VPS.');
      await _loadAll(showLoader:false);
    } catch(e) { if(mounted)_showSnack(_friendlyError(e)); }
    finally { if(mounted)setState(()=>_busy=false); }
  }

  void _showUploadPinDialog() { final c=TextEditingController(); showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('Upload PIN'),content:TextField(controller:c,obscureText:true,keyboardType:TextInputType.number,decoration:const InputDecoration(hintText:'Enter PIN')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('CANCEL')),ElevatedButton(onPressed:(){_pin.text=c.text;Navigator.pop(context);_pickAndUpload();},child:const Text('CONTINUE'))])); }

  Widget _bottomNav()=>NavigationBar(backgroundColor:const Color(0xF00F0F12),indicatorColor:const Color(0x333F36A8),selectedIndex:_navIndex,onDestinationSelected:(i)=>setState(()=>_navIndex=i),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'Home'),NavigationDestination(icon:Icon(Icons.folder_outlined),selectedIcon:Icon(Icons.folder_rounded),label:'Folders'),NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings_rounded),label:'Settings')]);

  void _openPlayer(VideoItem v) {
    if(v.streamUrl==null){_showSnack('Video stream is not ready.');return;}
    Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ChikiPlayer(video:v)));
  }

  void _showSnack(String text){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text),behavior:SnackBarBehavior.floating));}

  String _durationText(double? seconds){if(seconds==null||seconds<=0)return '--:--';final s=seconds.round();final h=s~/3600;final m=(s%3600)~/60;final sec=s%60;return h>0?'$h:${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}':'${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';}
  String _sizeText(int? bytes){if(bytes==null)return '—';const units=['B','KB','MB','GB','TB'];double n=bytes.toDouble();int i=0;while(n>=1024&&i<units.length-1){n/=1024;i++;}return '${n.toStringAsFixed(i==0?0:1)} ${units[i]}';}
}

class ChikiPlayer extends StatefulWidget {
  final VideoItem video;
  const ChikiPlayer({super.key, required this.video});
  @override
  State<ChikiPlayer> createState()=>_ChikiPlayerState();
}

class _ChikiPlayerState extends State<ChikiPlayer> {
  late VideoPlayerController _controller;
  bool _ready=false;
  @override
  void initState(){super.initState();_controller=VideoPlayerController.networkUrl(Uri.parse(widget.video.streamUrl!))..initialize().then((_){if(!mounted)return;setState(()=>_ready=true);_controller.play();});}
  @override
  void dispose(){_controller.dispose();super.dispose();}
  void _seek(int seconds){final p=_controller.value.position;final d=_controller.value.duration;var target=p+Duration(seconds:seconds);if(target<Duration.zero)target=Duration.zero;if(target>d)target=d;_controller.seekTo(target);}
  @override
  Widget build(BuildContext context){return Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,title:Text(widget.video.title,maxLines:1,overflow:TextOverflow.ellipsis)),body:SafeArea(child:Column(children:[Expanded(child:Center(child:_ready?AspectRatio(aspectRatio:_controller.value.aspectRatio==0?16/9:_controller.value.aspectRatio,child:VideoPlayer(_controller)):const CircularProgressIndicator())),if(_ready)VideoProgressIndicator(_controller,allowScrubbing:true,padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),colors:VideoProgressColors(playedColor:Color(0xFF8B5CF6),bufferedColor:Color(0x554C1D95),backgroundColor:Color(0xFF25253A))),Padding(padding:const EdgeInsets.fromLTRB(14,6,14,20),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[IconButton(onPressed:()=>_seek(-10),icon:const Icon(Icons.replay_10_rounded)),IconButton(onPressed:()=>setState(()=>_controller.value.isPlaying?_controller.pause():_controller.play()),icon:Icon(_controller.value.isPlaying?Icons.pause_circle_filled_rounded:Icons.play_circle_fill_rounded,size:48)),IconButton(onPressed:()=>_seek(10),icon:const Icon(Icons.forward_10_rounded)),const SizedBox(width:12),IconButton(onPressed:()=>_controller.setVolume(_controller.value.volume>0?0:1),icon:Icon(_controller.value.volume>0?Icons.volume_up_rounded:Icons.volume_off_rounded))]))])));}
}

class _GradientText extends StatelessWidget {
  final String text; final double size; final bool bold;
  const _GradientText(this.text,this.size,{this.bold=false});
  @override
  Widget build(BuildContext context)=>ShaderMask(shaderCallback:(bounds)=>const LinearGradient(colors:[Color(0xFFFFFFFF),Color(0xFFC4B5FD),Color(0xFF7DD3FC),Color(0xFFF9A8D4)]).createShader(bounds),child:Text(text,style:TextStyle(color:Colors.white,fontSize:size,height:.96,letterSpacing:size>40?-2.0:1.2,fontWeight:bold?FontWeight.w900:FontWeight.w900)));
}
