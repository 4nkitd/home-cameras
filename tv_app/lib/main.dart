import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_feed.dart';
import 'model.dart';
import 'platform_bridge.dart';
import 'setup_sheet.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final preferences = await SharedPreferences.getInstance();
  runApp(
    HomeCamerasApp(store: AppStore(SecureCameraRepository(), preferences)),
  );
}

class HomeCamerasApp extends StatelessWidget {
  const HomeCamerasApp({
    super.key,
    required this.store,
    this.renderVideo = true,
  });
  final AppStore store;
  final bool renderVideo;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Home Cameras',
    debugShowCheckedModeBanner: false,
    theme: homeTheme(),
    home: HomeScreen(store: store, renderVideo: renderVideo),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, this.renderVideo = true});
  final AppStore store;
  final bool renderVideo;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStore get store => widget.store;
  final Map<String, FocusNode> _cameraFocus = {};
  final Map<String, FeedStatus> _statuses = {};
  final _fullFeed = GlobalKey<LiveFeedState>();
  String _page = 'home';
  String? _fullId;
  bool _favorites = false;
  bool _audio = false;
  bool _suspendFeeds = false;
  bool _networkAllowed = true;
  int _pageIndex = 0;
  Timer? _clock;

  List<CameraConfig> get _filtered =>
      store.cameras.where((c) => !_favorites || c.favorite).toList();
  List<CameraConfig> get _visible {
    final cameras = _filtered;
    final pages = max(1, (cameras.length / store.pageSize).ceil());
    _pageIndex = _pageIndex.clamp(0, pages - 1);
    return cameras
        .skip(_pageIndex * store.pageSize)
        .take(store.pageSize)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
    unawaited(_load());
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    await store.load();
    if (!mounted || !store.ready) return;
    if (store.cameras.isNotEmpty) {
      try {
        final allowed = await TvPlatform.requestNetwork();
        if (mounted) setState(() => _networkAllowed = allowed);
      } catch (_) {
        if (mounted) setState(() => _networkAllowed = false);
      }
    }
    _awake();
  }

  void _awake() => unawaited(
    TvPlatform.setAwake(
      store.keepAwake &&
          (_page == 'home' || _fullId != null) &&
          store.cameras.isNotEmpty,
    ).catchError((Object _) {}),
  );

  void _changed() {
    if (!mounted) return;
    if (_fullId != null && !store.cameras.any((c) => c.id == _fullId)) {
      _fullId = null;
    }
    setState(() {});
    _awake();
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _mutate(Future<void> Function() change) async {
    try {
      await change();
    } catch (_) {
      _notice(
        'Could not save this change. Check device storage and try again.',
      );
    }
  }

  Future<void> _setup([CameraConfig? camera]) async {
    setState(() {
      _suspendFeeds = true;
      _statuses.clear();
    });
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Camera setup',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondary) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: SetupSheet(store: store, camera: camera),
      ),
      transitionBuilder: (context, animation, secondary, child) =>
          SlideTransition(
            position: Tween(
              begin: const Offset(.12, 0),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
    );
    if (!mounted) return;
    setState(() {
      _suspendFeeds = false;
      if (result != null) {
        _fullId = null;
        _page = 'home';
        _favorites = false;
        final index = store.cameras.indexWhere((c) => c.id == result);
        if (index >= 0) _pageIndex = index ~/ store.pageSize;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && result != null) _cameraFocus[result]?.requestFocus();
    });
  }

  Future<void> _layout() async {
    final count = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Room for every view.'),
        content: const Text(
          'Choose the number of camera tiles on each page. More streams require more TV decoding capacity.',
        ),
        actions: [
          TvButton(
            '4 cameras',
            selected: store.pageSize == 4,
            onPressed: () => Navigator.pop(context, 4),
          ),
          TvButton(
            '6 cameras',
            selected: store.pageSize == 6,
            onPressed: () => Navigator.pop(context, 6),
          ),
        ],
      ),
    );
    if (count != null) {
      _pageIndex = 0;
      await _mutate(() => store.setLayout(count));
    }
  }

  String _qualityLabel(ViewQuality q) => switch (q) {
    ViewQuality.automatic => 'Automatic',
    ViewQuality.high => 'High quality',
    ViewQuality.low => 'Low bandwidth',
  };

  Future<void> _quality() async {
    final quality = await showDialog<ViewQuality>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose your view.'),
        content: const Text(
          'Fullscreen uses the main stream. Low bandwidth uses a configured substream when available. The grid always prefers the substream.',
        ),
        actions: ViewQuality.values
            .map(
              (q) => TvButton(
                _qualityLabel(q),
                selected: store.quality == q,
                onPressed: () => Navigator.pop(context, q),
              ),
            )
            .toList(),
      ),
    );
    if (quality != null) await _mutate(() => store.setQuality(quality));
  }

  void _navigate(String page) {
    setState(() {
      _page = page;
      _fullId = null;
      _audio = false;
      _statuses.clear();
    });
    _awake();
  }

  void _back() {
    if (_fullId != null) {
      final id = _fullId;
      setState(() {
        _fullId = null;
        _audio = false;
        _statuses.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cameraFocus[id]?.requestFocus();
      });
    } else if (_page != 'home') {
      _navigate('home');
    }
  }

  Widget _topbar(double width) {
    final compact = width < 1450;
    final time = TimeOfDay.now().format(context);
    final visible = _visible;
    final live = visible
        .where((c) => _statuses[c.id] == FeedStatus.live)
        .length;
    return SizedBox(
      height: 72,
      child: Row(
        children: [
          const Icon(Icons.home_outlined, color: sage, size: 28),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Home Cameras',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: chalk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                store.cameras.isEmpty
                    ? 'Welcome home'
                    : _page == 'home'
                    ? '$live of ${visible.length} live'
                    : '${store.cameras.length} cameras saved',
                style: const TextStyle(fontSize: 11, color: fog),
              ),
            ],
          ),
          const Spacer(),
          for (final item in [
            ('home', 'Live view'),
            ('manage', 'Cameras'),
            ('settings', 'Settings'),
          ])
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: TvButton(
                item.$2,
                onPressed: () => _navigate(item.$1),
                selected: _page == item.$1,
                compact: width < 1000 && _page != item.$1,
                icon: width < 1000 && _page != item.$1
                    ? switch (item.$1) {
                        'home' => Icons.grid_view,
                        'manage' => Icons.videocam_outlined,
                        _ => Icons.tune,
                      }
                    : null,
              ),
            ),
          if (_page == 'home') ...[
            const SizedBox(width: 10),
            PopupMenuButton<bool>(
              tooltip: 'Camera view',
              initialValue: _favorites,
              onSelected: (v) => setState(() {
                _favorites = v;
                _pageIndex = 0;
                _statuses.clear();
              }),
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('All cameras')),
                PopupMenuItem(value: true, child: Text('Favourites')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Text(
                      _favorites ? 'Favourites' : 'All cameras',
                      style: const TextStyle(fontSize: 12, color: chalk),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more, size: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            TvButton(
              'Layout',
              onPressed: _layout,
              icon: Icons.grid_view,
              compact: compact,
            ),
            const SizedBox(width: 7),
            TvButton(
              'Add camera',
              onPressed: _setup,
              icon: Icons.add,
              primary: true,
              compact: compact,
            ),
          ],
          if (width > 950) ...[
            const SizedBox(width: 22),
            Text(time, style: const TextStyle(fontSize: 15, color: chalk)),
          ],
        ],
      ),
    );
  }

  Widget _grid() {
    if (!_networkAllowed) {
      return EmptyView(
        title: 'Network access is needed.',
        message: 'Allow local-network access to view your cameras.',
        icon: Icons.wifi_off,
        action: TvButton(
          'Allow network access',
          onPressed: _load,
          primary: true,
        ),
      );
    }
    final cameras = _visible;
    if (cameras.isEmpty) {
      return EmptyView(
        title: _favorites
            ? 'Keep your favourites close.'
            : 'A home for your cameras.',
        message: _favorites
            ? 'Mark a camera as a favourite in its settings to see it here.'
            : 'Add your first camera. Then see the places that matter, together on one screen.',
        action: TvButton(
          _favorites ? 'Manage cameras' : 'Add your first camera',
          onPressed: _favorites ? () => _navigate('manage') : _setup,
          icon: Icons.add,
          primary: true,
          autofocus: true,
        ),
      );
    }
    final count = store.pageSize == 6 ? 6 : cameras.length;
    final rows = (count / store.columns).ceil();
    final pages = max(1, (_filtered.length / store.pageSize).ceil());
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tileHeight =
                  (constraints.maxHeight - 14 * (rows - 1)) / rows;
              final tileWidth =
                  (constraints.maxWidth - 14 * (store.columns - 1)) /
                  store.columns;
              return GridView.builder(
                padding: const EdgeInsets.all(4),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: count,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: store.columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: (tileWidth - 4) / (tileHeight - 4),
                ),
                itemBuilder: (context, index) {
                  if (index >= cameras.length) {
                    return Center(
                      child: TvButton(
                        'Add camera',
                        onPressed: _setup,
                        icon: Icons.add,
                      ),
                    );
                  }
                  final camera = cameras[index];
                  final node = _cameraFocus.putIfAbsent(
                    camera.id,
                    FocusNode.new,
                  );
                  return CameraTile(
                    key: ValueKey(camera.id),
                    camera: camera,
                    focusNode: node,
                    autofocus: index == 0,
                    renderVideo: widget.renderVideo && !_suspendFeeds,
                    onStatus: (status) {
                      if (mounted) {
                        setState(() => _statuses[camera.id] = status);
                      }
                    },
                    onOpen: () => setState(() {
                      _fullId = camera.id;
                      _audio = false;
                    }),
                  );
                },
              );
            },
          ),
        ),
        if (pages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TvButton(
                  'Previous',
                  onPressed: _pageIndex == 0
                      ? null
                      : () => setState(() {
                          _pageIndex--;
                          _statuses.clear();
                        }),
                  icon: Icons.chevron_left,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Page ${_pageIndex + 1} of $pages',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TvButton(
                  'Next',
                  onPressed: _pageIndex == pages - 1
                      ? null
                      : () => setState(() {
                          _pageIndex++;
                          _statuses.clear();
                        }),
                  icon: Icons.chevron_right,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _manage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Text(
              'Your cameras',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const Spacer(),
            TvButton(
              'Add camera',
              onPressed: _setup,
              primary: true,
              icon: Icons.add,
            ),
          ],
        ),
      ),
      Expanded(
        child: store.cameras.isEmpty
            ? EmptyView(
                title: 'A home for your cameras.',
                message: 'Add a camera to get started.',
                action: TvButton(
                  'Add camera',
                  onPressed: _setup,
                  primary: true,
                ),
              )
            : ListView.separated(
                itemCount: store.cameras.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final camera = store.cameras[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        SizedBox(width: 28, child: Text('${index + 1}')),
                        Container(
                          width: 92,
                          height: 58,
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.videocam_outlined,
                            color: sage,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                camera.name,
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${camera.room.isEmpty ? 'Unassigned' : camera.room}${camera.favorite ? ' · Favourite' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TvButton(
                          'Move ${camera.name} up',
                          onPressed: index == 0 || store.busy
                              ? null
                              : () => _mutate(() => store.move(camera.id, -1)),
                          icon: Icons.keyboard_arrow_up,
                          compact: true,
                        ),
                        const SizedBox(width: 6),
                        TvButton(
                          'Move ${camera.name} down',
                          onPressed:
                              index == store.cameras.length - 1 || store.busy
                              ? null
                              : () => _mutate(() => store.move(camera.id, 1)),
                          icon: Icons.keyboard_arrow_down,
                          compact: true,
                        ),
                        const SizedBox(width: 10),
                        TvButton(
                          'Edit camera',
                          onPressed: () => _setup(camera),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    ],
  );

  Widget _settings() => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make yourself at home.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'A few preferences. A quieter way to keep an eye on things.',
          ),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Home layout'),
                      trailing: Text('${store.pageSize} camera tiles'),
                      onTap: _layout,
                      focusColor: panel,
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Keep the screen awake'),
                      subtitle: const Text('While viewing cameras in this app'),
                      value: store.keepAwake,
                      onChanged: (v) => _mutate(() => store.setKeepAwake(v)),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Fullscreen quality'),
                      trailing: Text(_qualityLabel(store.quality)),
                      onTap: _quality,
                      focusColor: panel,
                    ),
                    const Divider(),
                    const ListTile(
                      title: Text('Grid audio'),
                      trailing: Text('Always muted'),
                    ),
                    const Divider(),
                    const ListTile(
                      title: Text('On app launch'),
                      trailing: Text('Saved camera grid'),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('About & open-source licenses'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Home Cameras',
                        applicationVersion: '0.1.2',
                        applicationLegalese: 'Local-network camera viewer. Native playback libraries include mpv and FFmpeg; see the accompanying THIRD_PARTY.md for build and source links.',
                      ),
                      focusColor: panel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 36),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 30, color: sage),
                      SizedBox(height: 24),
                      Text(
                        'Home stays home.',
                        style: TextStyle(fontSize: 20, color: chalk),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Your cameras connect directly to this TV. No cloud account, analytics or recording service.',
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Version 0.1.2 · Device-test build',
                        style: TextStyle(fontSize: 11, color: sage),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _fullscreen() {
    final camera = store.cameras.firstWhere((c) => c.id == _fullId);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.renderVideo && !_suspendFeeds)
          LiveFeed(
            key: _fullFeed,
            camera: camera,
            grid: false,
            quality: store.quality,
            audio: _audio,
          ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xbb101713),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xcc101713),
                ],
                stops: [0, .22, .72, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: 22,
          left: 30,
          right: 30,
          child: Row(
            children: [
              TvButton(
                'Back to cameras',
                onPressed: _back,
                icon: Icons.chevron_left,
                compact: true,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      camera.room.isEmpty ? 'Unassigned' : camera.room,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 24,
          left: 20,
          right: 20,
          child: Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                TvButton(
                  'Previous',
                  onPressed: store.cameras.length < 2
                      ? null
                      : () => _nextCamera(-1),
                  icon: Icons.chevron_left,
                ),
                TvButton(
                  _audio ? 'Audio on' : 'Audio off',
                  onPressed: () => setState(() => _audio = !_audio),
                  icon: _audio
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  autofocus: true,
                ),
                TvButton(
                  _qualityLabel(store.quality),
                  onPressed: _quality,
                  icon: Icons.high_quality_outlined,
                ),
                TvButton(
                  'Retry',
                  onPressed: () => _fullFeed.currentState?.retryNow(),
                  icon: Icons.refresh,
                ),
                TvButton(
                  'Settings',
                  onPressed: () => _setup(camera),
                  icon: Icons.tune,
                ),
                TvButton(
                  'Next',
                  onPressed: store.cameras.length < 2
                      ? null
                      : () => _nextCamera(1),
                  icon: Icons.chevron_right,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _nextCamera(int direction) {
    final index = store.cameras.indexWhere((c) => c.id == _fullId);
    setState(() {
      _fullId = store
          .cameras[(index + direction + store.cameras.length) %
              store.cameras.length]
          .id;
      _audio = false;
    });
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    _clock?.cancel();
    for (final node in _cameraFocus.values) {
      node.dispose();
    }
    unawaited(TvPlatform.setAwake(false).catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _fullId == null && _page == 'home',
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: Scaffold(
        body: !store.ready
            ? store.loadError != null
                  ? EmptyView(
                      title: 'Your cameras are still protected.',
                      message: store.loadError!,
                      icon: Icons.lock_outline,
                      action: TvButton(
                        'Try again',
                        onPressed: _load,
                        primary: true,
                      ),
                    )
                  : const Center(child: CircularProgressIndicator())
            : _fullId != null
            ? _fullscreen()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Column(
                      children: [
                        _topbar(constraints.maxWidth),
                        Expanded(
                          child: switch (_page) {
                            'manage' => _manage(),
                            'settings' => _settings(),
                            _ => _grid(),
                          },
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(
                          height: 30,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '↑ ↓ ← →  Navigate      OK  Select      Back  Return',
                                style: TextStyle(fontSize: 10, color: fog),
                              ),
                              Text(
                                'Local network only  ·  Grid muted',
                                style: TextStyle(fontSize: 10, color: fog),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}

class CameraTile extends StatefulWidget {
  const CameraTile({
    super.key,
    required this.camera,
    required this.onOpen,
    required this.focusNode,
    required this.onStatus,
    this.autofocus = false,
    this.renderVideo = true,
  });
  final CameraConfig camera;
  final VoidCallback onOpen;
  final FocusNode focusNode;
  final ValueChanged<FeedStatus> onStatus;
  final bool autofocus;
  final bool renderVideo;
  @override
  State<CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<CameraTile> {
  bool _focused = false;
  FeedStatus _status = FeedStatus.connecting;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    focusNode: widget.focusNode,
    autofocus: widget.autofocus,
    onShowFocusHighlight: (value) => setState(() => _focused = value),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onOpen();
          return null;
        },
      ),
    },
    child: Semantics(
      button: true,
      label: '${widget.camera.name}, ${_status.name}. Open fullscreen.',
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused ? chalk : Colors.transparent,
              width: 3,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.renderVideo)
                  LiveFeed(
                    camera: widget.camera,
                    onStatus: (status) {
                      if (mounted) setState(() => _status = status);
                      widget.onStatus(status);
                    },
                  )
                else
                  const ColoredBox(
                    color: panel,
                    child: Center(
                      child: Icon(Icons.videocam_outlined, color: sage),
                    ),
                  ),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xdd101713)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xcc1d2920),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      _status == FeedStatus.live && widget.renderVideo
                          ? '●  Live'
                          : _status == FeedStatus.unavailable
                          ? '●  Offline'
                          : '●  Connecting',
                      style: TextStyle(
                        fontSize: 10,
                        color: _status == FeedStatus.unavailable ? amber : sage,
                      ),
                    ),
                  ),
                ),
                if (widget.camera.favorite)
                  const Positioned(
                    right: 14,
                    top: 13,
                    child: Icon(Icons.star_outline, color: chalk, size: 17),
                  ),
                Positioned(
                  left: 18,
                  right: 16,
                  bottom: 15,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.camera.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w500,
                                color: chalk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.camera.room.isEmpty
                                  ? 'Unassigned'
                                  : widget.camera.room,
                              style: const TextStyle(fontSize: 11, color: fog),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.fullscreen, color: fog, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
