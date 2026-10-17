import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'internet_audio.dart';
import 'audio_preloader.dart';
import 'ad_banner.dart';
import 'interstitial_ads.dart';
import 'ad_consent.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const WhatSoundApp());
}

class WhatSoundApp extends StatelessWidget {
  const WhatSoundApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WhatSound',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D111B),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8C6BFF), brightness: Brightness.dark),
    ),
    home: const LibraryScreen(),
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final search = TextEditingController();
  final interstitialAds = WhatSoundInterstitialAds();

  final player = AudioPlayer();
  final service = OnlineAudioService();
  final preloader = AudioPreloader();
  final Set<String> unavailable = {};
  int searchGeneration = 0;
  final List<OnlineSound> downloadQueue = [];
  final Set<String> queuedUrls = {};
  int activeDownloads = 0;
  int completedDownloads = 0;
  List<OnlineSound> results = [];
  List<OnlineSound> library = [];
  bool adsAllowed = false;
  bool searching = false;
  bool onlyLibrary = false;
  String? activeUrl;
  String? sharingUrl;
  String? error;

  @override
  void initState() {
    super.initState();
    search.addListener(_onSearchChanged);
    _loadLibrary();
    _initializeAds();
  }

  Future<void> _initializeAds() async {
    final allowed = await WhatSoundAdConsent.request();
    if (!mounted || !allowed) return;
    setState(() => adsAllowed = true);
    interstitialAds.preload();
  }

  void _onSearchChanged() {
    if (activeUrl != null) {
      player.stop();
      if (mounted) setState(() { activeUrl = null; });
    }
  }
  Future<void> _loadLibrary() async {
    try {
      final items = await service.verifiedLinks();
      if (mounted) setState(() => library = items);
    } catch (_) {}
  }

  Future<void> _showAbout() async {
    String version = 'No disponible';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (${info.buildNumber})';
    } catch (_) {}
    if (!mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'WhatSound',
      applicationVersion: version,
      applicationIcon: const Icon(Icons.graphic_eq, size: 42, color: Color(0xFFA992FF)),
      applicationLegalese: '© 2026 RoboTop Studios',
      children: const [
        SizedBox(height: 12),
        Text('Desarrollado por RoboTop Studios.'),
        SizedBox(height: 8),
        Text('Buscador de frases y sonidos para escuchar, compartir y guardar enlaces.'),
      ],
    );
  }

  Future<void> _search() async {
    final q = search.text.trim();
    if (q.isEmpty || searching) return;
    final generation = ++searchGeneration;
    downloadQueue.clear();
    queuedUrls.clear();
    completedDownloads = 0;
    setState(() { searching = true; error = null; onlyLibrary = false; unavailable.clear(); results = []; });
    try {
      final found = await service.search(q, onResults: (partial) {
        if (!mounted || generation != searchGeneration) return;
        final previousUrls = results.map((s) => s.url).toSet();
        final fresh = partial.where((s) => !previousUrls.contains(s.url)).toList();
        if (fresh.isEmpty) return;
        setState(() => results = [...results, ...fresh]);
        _preloadProgressively(fresh, generation);
      });
      if (mounted && generation == searchGeneration) {
        setState(() { results = found; if (found.isEmpty) error = 'No encontramos esa frase. Probá el nombre del personaje o palabras de la frase.'; });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'No se pudo consultar Internet. Revisá la conexión e intentá de nuevo.');
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  void _preloadProgressively(List<OnlineSound> sounds, int generation) {
    if (generation != searchGeneration) return;
    for (final sound in sounds) {
      if (queuedUrls.add(sound.url)) downloadQueue.add(sound);
    }
    _pumpDownloads(generation);
  }

  void _pumpDownloads(int generation) {
    if (!mounted || generation != searchGeneration) return;
    // Up to three initial audio downloads concurrently. After six, one at a
    // time to reserve bandwidth for playback and user-triggered downloads.
    final limit = completedDownloads < 6 ? 3 : 1;
    while (activeDownloads < limit && downloadQueue.isNotEmpty) {
      final sound = downloadQueue.removeAt(0);
      activeDownloads++;
      preloader.prepare(sound.url).then((_) {
        if (mounted && generation == searchGeneration) {
          unavailable.remove(sound.url);
          setState(() {});
        }
      }).catchError((Object _) {
        if (mounted && generation == searchGeneration) {
          unavailable.add(sound.url);
          setState(() {});
        }
      }).whenComplete(() {
        activeDownloads--;
        if (generation == searchGeneration) completedDownloads++;
        _pumpDownloads(generation);
      });
    }
  }
  Future<void> _play(OnlineSound sound) async {
    try {
      if (activeUrl == sound.url) {
        await player.stop();
        if (mounted) setState(() => activeUrl = null);
        return;
      }
      await player.stop();
      final file = await preloader.prepare(sound.url);
      if (!mounted) return;
      await player.setFilePath(file.path);
      if (unavailable.remove(sound.url) && mounted) setState(() {});
      if (mounted) setState(() { activeUrl = sound.url; });
      await player.play();
    } catch (_) {
      if (mounted) setState(() => activeUrl = null);
      if (mounted) setState(() => unavailable.add(sound.url));
      _message('No pudimos cargar este audio. Podés intentar de nuevo.');
    }
  }

  Future<void> _share(OnlineSound sound) async {
    if (sharingUrl != null) return;
    setState(() => sharingUrl = sound.url);
    File? temp;
    try {
      temp = await preloader.prepare(sound.url);
      if (mounted && unavailable.remove(sound.url)) setState(() {});
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(temp.path)], text: sound.title));
      // The share sheet returning does not prove WhatsApp sent the message.
      // The link is recorded only as technically accessible and shareable.
      await service.saveVerified(sound);
      await _loadLibrary();
    } catch (e) {
      _message('No se pudo preparar este audio: $e');
    } finally {
      if (mounted) setState(() => sharingUrl = null);
      // Keep the temporary file until the receiving app has had a chance to read it.
    }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  void dispose() {
    search.dispose();

    player.dispose();
    preloader.dispose();
    interstitialAds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = onlyLibrary ? library : results;
    return Scaffold(
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (adsAllowed) const WhatSoundAdBanner(),
        NavigationBar(
        selectedIndex: onlyLibrary ? 1 : 0,
        onDestinationSelected: (i) {
          if ((i == 1) == onlyLibrary) return;
          setState(() => onlyLibrary = i == 1);
          if (adsAllowed) interstitialAds.onNavigation(isAudioPlaying: activeUrl != null, isSharing: sharingUrl != null);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Buscar'),
          NavigationDestination(icon: Icon(Icons.bookmark_outline), label: 'Biblioteca'),
        ],
      )]),
      body: SafeArea(child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 24),
          Row(children: [
            const Icon(Icons.graphic_eq, color: Color(0xFFA992FF), size: 32),
            const SizedBox(width: 10),
            const Expanded(child: Text('WhatSound', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800))),
            PopupMenuButton<String>(
              tooltip: 'Información y privacidad',
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'about') {
                  await _showAbout();
                } else if (value == 'privacy') {
                  ConsentForm.showPrivacyOptionsForm((error) {
                    if (error != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Las opciones de privacidad no están disponibles por ahora.')),
                      );
                    }
                  });
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'about', child: Text('Acerca de WhatSound')),
                PopupMenuItem(value: 'privacy', child: Text('Opciones de privacidad')),
              ],
            ),
          ]),
          const SizedBox(height: 7),
          const Text('Buscá sonidos en Internet y compartilos.', style: TextStyle(color: Color(0xFFABB3C4))),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Gallo Claudio, frases, sonidos...',
                filled: true,
                fillColor: const Color(0xFF1B2231),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            )),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: searching ? null : _search, tooltip: 'Buscar en Internet', icon: const Icon(Icons.arrow_forward)),
          ]),
          const SizedBox(height: 20),
          Text(onlyLibrary ? 'Enlaces comprobados' : 'Resultados de Internet', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(onlyLibrary ? 'Enlaces que ya se pudieron preparar para compartir' : 'Frases cortas y sonidos de varias fuentes',
            style: const TextStyle(color: Color(0xFFABB3C4), fontSize: 12)),
          if (searching) const LinearProgressIndicator(),
          if (error != null && !onlyLibrary) Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(error!, style: const TextStyle(color: Color(0xFFFFB6B6))),
          ),
          const SizedBox(height: 12),
          items.isEmpty
            ? Center(child: Text(onlyLibrary ? 'Todavía no hay enlaces comprobados.' : 'Escribí una frase y tocá Buscar.',
              textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFABB3C4))))
            : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final sound = items[index];
                final sending = sharingUrl == sound.url;
                final ready = preloader.isReady(sound.url);
                final failed = unavailable.contains(sound.url);
                return Card(
                  color: const Color(0xFF1A2232),
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: IconButton(
                        tooltip: 'Escuchar',
                        onPressed: () => _play(sound),
                        icon: Icon(activeUrl == sound.url ? Icons.stop_circle : ready ? Icons.play_circle : Icons.downloading, size: 34, color: const Color(0xFFB8A6FF)),
                      ),
                      title: Text(sound.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${sound.source} · ${ready ? 'Listo para escuchar' : failed ? 'No disponible · reintentar' : 'Preparando audio…'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: 'Compartir audio por WhatsApp u otra app',
                        onPressed: sharingUrl != null ? null : () => _share(sound),
                        icon: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.share_outlined),
                      ),
                    )),
                );
              },
            ),
        ]),
      ))),
    );
  }
}
