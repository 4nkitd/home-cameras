import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'discovery.dart';
import 'live_feed.dart';
import 'model.dart';
import 'platform_bridge.dart';
import 'store.dart';
import 'theme.dart';

enum SetupStep {
  choose,
  permission,
  denied,
  scanning,
  found,
  none,
  credentials,
  profiles,
  manual,
  testing,
  preview,
  success,
  failure,
  remove,
}

typedef CameraPreviewBuilder = Widget Function(
  CameraConfig camera,
  VoidCallback onReady,
  ValueChanged<FeedStatus> onStatus,
);

class SetupSheet extends StatefulWidget {
  const SetupSheet({
    super.key,
    required this.store,
    this.camera,
    this.previewBuilder,
  });
  final AppStore store;
  final CameraConfig? camera;
  @visibleForTesting
  final CameraPreviewBuilder? previewBuilder;

  @override
  State<SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<SetupSheet> {
  final _name = TextEditingController();
  final _room = TextEditingController();
  final _url = TextEditingController();
  final _sub = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final Map<TextEditingController, FocusNode> _fieldFocus = {};
  final _form = GlobalKey<FormState>();
  final _discovery = CameraDiscovery();
  final _testFeed = GlobalKey<LiveFeedState>();
  SetupStep _step = SetupStep.choose;
  SetupStep _retryStep = SetupStep.manual;
  bool _favorite = false;
  bool _showPassword = false;
  bool _busy = false;
  bool _manual = false;
  bool _readyToSave = false;
  int _operation = 0;
  List<DiscoveredCamera> _devices = [];
  List<CameraProfile> _profiles = [];
  CameraProfile? _mainProfile;
  CameraProfile? _gridProfile;
  DiscoveredCamera? _device;
  String _error = '';
  String? _savedId;
  String? _cameraId;
  CameraConfig? _testCamera;

  @override
  void initState() {
    super.initState();
    final camera = widget.camera;
    if (camera != null) {
      _name.text = camera.name;
      _room.text = camera.room;
      _url.text = camera.mainUrl;
      _sub.text = camera.gridUrl;
      _username.text = camera.username;
      _password.text = camera.password;
      _favorite = camera.favorite;
      _step = SetupStep.manual;
      _manual = true;
      _cameraId = camera.id;
    }
  }

  void _go(SetupStep step) {
    ++_operation;
    _discovery.cancel();
    setState(() {
      _step = step;
      _busy = false;
      _error = '';
    });
  }

  void _back() {
    if (widget.store.busy) return;
    if (_busy && _step != SetupStep.scanning) {
      ++_operation;
      _discovery.cancel();
      setState(() => _busy = false);
      return;
    }
    final previous = switch (_step) {
      SetupStep.permission ||
      SetupStep.denied ||
      SetupStep.scanning ||
      SetupStep.found ||
      SetupStep.none => SetupStep.choose,
      SetupStep.credentials => SetupStep.found,
      SetupStep.profiles => SetupStep.credentials,
      SetupStep.testing ||
      SetupStep.preview => _manual ? SetupStep.manual : SetupStep.profiles,
      SetupStep.failure => _retryStep,
      SetupStep.remove => SetupStep.manual,
      _ => null,
    };
    if (previous != null) {
      _go(previous);
    } else {
      Navigator.of(context).pop(_savedId);
    }
  }

  Future<void> _scan() async {
    final generation = ++_operation;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final allowed = await TvPlatform.requestNetwork();
      if (!mounted || generation != _operation) return;
      if (!allowed) {
        _go(SetupStep.denied);
        return;
      }
      setState(() {
        _step = SetupStep.scanning;
        _busy = false;
      });
      final devices = await _discovery.scan();
      if (!mounted || generation != _operation) return;
      setState(() {
        _devices = devices;
        _step = devices.isEmpty ? SetupStep.none : SetupStep.found;
      });
    } catch (_) {
      if (!mounted || generation != _operation) return;
      setState(() {
        _busy = false;
        _retryStep = SetupStep.permission;
        _step = SetupStep.failure;
        _error = 'Discovery could not use the local network. Check Wi-Fi or Ethernet and try again.';
      });
    }
  }

  Future<void> _lookupProfiles() async {
    if (!_form.currentState!.validate()) return;
    final generation = ++_operation;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final profiles = await _discovery
          .profiles(_device!, _username.text.trim(), _password.text)
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () {
              _discovery.cancel();
              throw TimeoutException('ONVIF timed out.');
            },
          );
      if (!mounted || generation != _operation) return;
      _profiles = profiles;
      _pickMain(profiles.first);
      setState(() {
        _busy = false;
        _step = SetupStep.profiles;
      });
    } catch (_) {
      if (!mounted || generation != _operation) return;
      setState(() {
        _busy = false;
        _error = 'Could not read stream profiles. Check the camera’s ONVIF account and settings, or use a manual RTSP address.';
      });
    }
  }

  void _pickMain(CameraProfile profile) {
    _mainProfile = profile;
    _gridProfile = null;
    if (profile.source.isNotEmpty) {
      final alternatives =
          _profiles
              .where(
                (p) =>
                    p.source == profile.source &&
                    p.pixels > 0 &&
                    p.pixels < profile.pixels,
              )
              .toList()
            ..sort((a, b) => a.pixels.compareTo(b.pixels));
      _gridProfile = alternatives.firstOrNull;
    }
  }

  CameraConfig _draft() => CameraConfig(
    id: _cameraId ??= DateTime.now().microsecondsSinceEpoch.toString(),
    name: _name.text.trim().isEmpty ? 'New camera' : _name.text.trim(),
    room: _room.text.trim(),
    mainUrl: _url.text.trim(),
    gridUrl: _sub.text.trim(),
    username: _username.text.trim(),
    password: _password.text,
    favorite: _favorite,
  );

  Future<void> _testConnection() async {
    if (_manual && !_form.currentState!.validate()) return;
    if (!_manual) {
      _url.text = _mainProfile!.url;
      _sub.text = _gridProfile?.url ?? '';
    }
    final generation = ++_operation;
    try {
      final allowed = await TvPlatform.requestNetwork();
      if (!mounted || generation != _operation) return;
      if (!allowed) {
        _go(SetupStep.denied);
        return;
      }
      setState(() {
        _readyToSave = false;
        _error = '';
        _retryStep = _manual ? SetupStep.manual : SetupStep.profiles;
        _testCamera = _draft();
        _step = SetupStep.testing;
      });
    } catch (_) {
      if (!mounted || generation != _operation) return;
      setState(
        () => _error = 'Local-network access is unavailable. Try again.',
      );
    }
  }

  Future<void> _save({bool editDirect = false}) async {
    if (_busy ||
        !_form.currentState!.validate() ||
        !editDirect && !_readyToSave) {
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final camera = _draft();
      await widget.store.upsert(camera);
      if (!mounted) return;
      setState(() {
        _savedId = camera.id;
        _busy = false;
        _step = SetupStep.success;
        _testCamera = null;
      });
      _password.clear();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save this camera securely. No changes were saved. Check device storage and try again.';
        });
      }
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.remove(widget.camera!.id);
      if (mounted) Navigator.of(context).pop('removed');
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'The camera could not be removed. Try again.';
        });
      }
    }
  }

  Widget _intro(String title, String message, [String? step]) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step != null) ...[
          Text(step, style: const TextStyle(color: sage, fontSize: 12)),
          const SizedBox(height: 12),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(message),
      ],
    ),
  );

  List<TextEditingController> get _activeFields => switch (_step) {
    SetupStep.credentials => [_username, _password],
    SetupStep.manual => [
      if (widget.camera != null) ...[_name, _room],
      _url,
      _sub,
      _username,
      _password,
    ],
    SetupStep.testing || SetupStep.preview => [_name, _room],
    _ => [],
  };

  void _moveField(TextEditingController controller, bool forward) {
    final fields = _activeFields;
    final index = fields.indexOf(controller);
    if (index < 0) return;
    final target = index + (forward ? 1 : -1);
    if (target >= 0 && target < fields.length) {
      _fieldFocus[fields[target]]?.requestFocus();
    } else {
      _fieldFocus[controller]?.focusInDirection(
        forward ? TraversalDirection.down : TraversalDirection.up,
      );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool password = false,
    String? Function(String?)? validator,
    bool autofocus = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveField(controller, true),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveField(controller, false),
      },
      child: TextFormField(
        focusNode: _fieldFocus.putIfAbsent(
          controller,
          () => FocusNode(debugLabel: label),
        ),
        controller: controller,
        validator: validator,
        autofocus: autofocus,
        obscureText: password && !_showPassword,
        autocorrect: false,
        enableSuggestions: !password,
        autofillHints: const [],
        textInputAction: _activeFields.lastOrNull == controller
            ? TextInputAction.done
            : TextInputAction.next,
        onEditingComplete: () {},
        onFieldSubmitted: (_) => _moveField(controller, true),
        maxLength: controller == _name
            ? 60
            : controller == _room
            ? 40
            : 1024,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          suffixIcon: password
              ? IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                )
              : null,
        ),
      ),
    ),
  );

  Widget _wide(
    String label,
    VoidCallback? action, {
    IconData? icon,
    bool primary = false,
    bool danger = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: SizedBox(
      width: double.infinity,
      child: TvButton(
        label,
        onPressed: _busy ? null : action,
        icon: icon,
        primary: primary,
        danger: danger,
      ),
    ),
  );

  Widget _note(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .025),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xff3b443e)),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: fog, height: 1.5),
    ),
  );

  Widget _choice(
    String title,
    String message,
    IconData icon,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: const Color(0xff2b332d),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Icon(icon, color: sage),
        title: Text(title, style: const TextStyle(fontSize: 16, color: chalk)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message, style: const TextStyle(fontSize: 12)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : action,
        focusColor: const Color(0xff4a594d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  void _previewReady() {
    if (mounted && (_step == SetupStep.testing || _step == SetupStep.preview)) {
      setState(() {
        _readyToSave = true;
        _step = SetupStep.preview;
        _error = '';
      });
    }
  }

  void _previewStatus(FeedStatus status) {
    if (!mounted || status != FeedStatus.unavailable) return;
    setState(() {
      _error = _readyToSave
          ? 'The preview was interrupted. This camera was already validated, so you can still save it.'
          : 'Video has not arrived yet. We are still listening; a late preview will unlock the next step automatically.';
    });
  }

  Widget _preview() =>
      widget.previewBuilder?.call(
        _testCamera!,
        _previewReady,
        _previewStatus,
      ) ??
      LiveFeed(
        key: _testFeed,
        camera: _testCamera!,
        grid: false,
        retry: false,
        onReady: _previewReady,
        onStatus: _previewStatus,
      );

  List<Widget> _body() => switch (_step) {
    SetupStep.choose => [
      _intro(
        'Bring your cameras home.',
        'Find cameras nearby, or add one with its stream address.',
      ),
      _choice(
        'Find on my network',
        'Discover ONVIF cameras on the same network as your TV.',
        Icons.wifi,
        () => _go(SetupStep.permission),
      ),
      _choice(
        'Add with an RTSP address',
        'For cameras you know, or ones that don’t appear in discovery.',
        Icons.link,
        () {
          _manual = true;
          _go(SetupStep.manual);
        },
      ),
      _note(
        'Your camera needs to support RTSP. Automatic discovery uses ONVIF. An NVR may expose several cameras through its own address.',
      ),
    ],
    SetupStep.permission || SetupStep.denied => [
      _intro(
        'Find cameras nearby.',
        _step == SetupStep.denied
            ? 'Network access was not granted. Both manual connections and discovery need local-network access.'
            : 'Allow access to your local network to discover and connect to cameras.',
        '1 of 3 · Find your camera',
      ),
      const Padding(
        padding: EdgeInsets.all(30),
        child: Icon(Icons.wifi, color: sage, size: 56),
      ),
      _wide('Allow network access', _scan, primary: true, icon: Icons.wifi),
      _wide(
        'Open TV network settings',
        () => unawaited(
          TvPlatform.openNetworkSettings().catchError((Object _) {
            if (mounted) {
              setState(
                () =>
                    _error = 'Open network settings from your TV home screen.',
              );
            }
          }),
        ),
      ),
      _note(
        'On Android versions that require it, a system permission dialog will appear. Cameras and the TV must be on the same reachable network.',
      ),
    ],
    SetupStep.scanning => [
      _intro(
        'Looking around your home.',
        'Searching for ONVIF cameras on your local network.',
        '1 of 3 · Find your camera',
      ),
      const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator(color: sage)),
      ),
      const Text(
        'Keep your cameras powered on. This search takes about six seconds.',
      ),
      _wide('Enter an address instead', () {
        _manual = true;
        _go(SetupStep.manual);
      }),
    ],
    SetupStep.found => [
      _intro(
        'Found around your home.',
        'Select a device. You can choose its camera stream next.',
        '1 of 3 · Find your camera',
      ),
      Text(
        '${_devices.length} devices found',
        style: const TextStyle(color: sage, fontSize: 12),
      ),
      const SizedBox(height: 16),
      ..._devices.map(
        (device) => _choice(
          device.name,
          device.endpoint.authority,
          Icons.videocam_outlined,
          () {
            _device = device;
            _manual = false;
            _name.text = device.name;
            _go(SetupStep.credentials);
          },
        ),
      ),
      _wide('Search again', _scan, icon: Icons.refresh),
      _wide('Add manually', () {
        _manual = true;
        _go(SetupStep.manual);
      }),
    ],
    SetupStep.none => [
      _intro(
        'No cameras found. Yet.',
        'Make sure cameras are powered on and ONVIF is enabled.',
      ),
      _note(
        'Guest Wi-Fi, client isolation and separate camera networks can block discovery. For cameras behind an NVR, use the NVR’s address.',
      ),
      _wide('Search again', _scan, primary: true, icon: Icons.refresh),
      _wide('Add with an RTSP address', () {
        _manual = true;
        _go(SetupStep.manual);
      }, icon: Icons.link),
    ],
    SetupStep.credentials => [
      _intro(
        'A key to your camera.',
        'Use its local ONVIF account, which may differ from the vendor app login.',
        '2 of 3 · Connect your camera',
      ),
      _note('${_device!.name}\n${_device!.endpoint.authority}'),
      _field(
        _username,
        'Username',
        validator: (v) =>
            v!.trim().isEmpty ? 'Enter the local camera username.' : null,
      ),
      _field(
        _password,
        'Password',
        password: true,
        validator: (v) =>
            v!.isEmpty ? 'Enter the local camera password.' : null,
      ),
      _wide(
        _busy ? 'Reading profiles…' : 'Find camera streams',
        _lookupProfiles,
        primary: true,
        icon: Icons.arrow_forward,
      ),
      _wide('Use a manual RTSP address', () {
        _manual = true;
        _go(SetupStep.manual);
      }),
    ],
    SetupStep.profiles => [
      _intro(
        'Choose this view.',
        'Pick a fullscreen stream and, if available, a smaller stream for the grid.',
        '2 of 3 · Select camera streams',
      ),
      DropdownButtonFormField<String>(
        initialValue: _mainProfile?.token,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Main stream / NVR channel',
        ),
        items: _profiles
            .map(
              (p) => DropdownMenuItem(
                value: p.token,
                child: Text(p.label, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (token) => setState(
          () => _pickMain(_profiles.firstWhere((p) => p.token == token)),
        ),
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
        key: ValueKey(_mainProfile?.token),
        initialValue: _gridProfile?.token ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Grid substream'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Use the main stream')),
          ..._profiles
              .where(
                (p) =>
                    p.token != _mainProfile?.token &&
                    (_mainProfile!.source.isEmpty ||
                        p.source == _mainProfile!.source),
              )
              .map(
                (p) => DropdownMenuItem(
                  value: p.token,
                  child: Text(p.label, overflow: TextOverflow.ellipsis),
                ),
              ),
        ],
        onChanged: (token) => setState(
          () => _gridProfile = token == ''
              ? null
              : _profiles.firstWhere((p) => p.token == token),
        ),
      ),
      _note(
        'For an NVR, choose streams from the same channel. Add other channels as separate cameras. H.264 substreams are a good starting point for multi-camera viewing.',
      ),
      _wide(
        'Test connection',
        _testConnection,
        primary: true,
        icon: Icons.arrow_forward,
      ),
    ],
    SetupStep.manual => [
      _intro(
        widget.camera == null
            ? 'Add a camera you know.'
            : 'A view of your own.',
        'Enter its RTSP address and local camera credentials.',
        '2 of 3 · Connect your camera',
      ),
      if (widget.camera != null) ...[
        _field(
          _name,
          'Camera name',
          validator: (v) =>
              v!.trim().isEmpty ? 'Give this camera a name.' : null,
        ),
        _field(_room, 'Room or area · optional'),
      ],
      _field(
        _url,
        'Main RTSP address',
        hint: 'rtsp://192.168.1.21:554/stream1',
        validator: (v) => validateStreamUrl(v!),
      ),
      _field(
        _sub,
        'Grid substream · optional',
        hint: 'Lower-resolution RTSP address',
        validator: (v) => v!.trim().isEmpty ? null : validateStreamUrl(v),
      ),
      _field(
        _username,
        'Username · optional',
        validator: (v) => v!.isEmpty && _password.text.isNotEmpty
            ? 'Enter the username, or clear both credentials.'
            : null,
      ),
      _field(
        _password,
        'Password · optional',
        password: true,
        validator: (v) => v!.isEmpty && _username.text.isNotEmpty
            ? 'Enter the password, or clear both credentials.'
            : null,
      ),
      if (widget.camera != null) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Favourite camera'),
          value: _favorite,
          onChanged: (v) => setState(() => _favorite = v),
        ),
        _wide(
          'Save changes',
          () => _save(editDirect: true),
          primary: true,
          icon: Icons.check,
        ),
      ],
      _wide(
        'Test connection',
        _testConnection,
        primary: widget.camera == null,
        icon: Icons.arrow_forward,
      ),
      if (widget.camera != null)
        _wide(
          'Remove camera',
          () => _go(SetupStep.remove),
          danger: true,
          icon: Icons.delete_outline,
        ),
      _note(
        'Leave both credential fields empty only if the camera permits anonymous viewing. Prefer a read-only camera account.',
      ),
    ],
    SetupStep.testing || SetupStep.preview => [
      _intro(
        _readyToSave ? 'There you are.' : 'Making the connection.',
        _readyToSave
            ? 'Give this view a name so it feels right at home.'
            : 'Waiting for a decoded video frame from your camera.',
        _readyToSave ? '3 of 3 · Make it yours' : '2 of 3 · Test your camera',
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(aspectRatio: 2.4, child: _preview()),
      ),
      const SizedBox(height: 20),
      if (_readyToSave) ...[
        _field(
          _name,
          'Camera name',
          hint: 'e.g. Front door',
          validator: (v) =>
              v!.trim().isEmpty ? 'Give this camera a name.' : null,
        ),
        _field(_room, 'Room or area · optional'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Add to favourites'),
          value: _favorite,
          onChanged: (value) => setState(() => _favorite = value),
        ),
        _wide(
          widget.camera == null ? 'Add to home' : 'Save changes',
          _save,
          primary: true,
          icon: Icons.add,
        ),
      ] else ...[
        _wide(
          'Try again',
          () => _testFeed.currentState?.retryNow(),
          icon: Icons.refresh,
        ),
        _wide('Edit connection', _back),
      ],
    ],
    SetupStep.success => [
      _intro(
        widget.camera == null ? 'Right where it belongs.' : 'Changes saved.',
        '${_name.text.trim()} is saved on this TV. Your camera grid will open by default next time.',
      ),
      const Padding(
        padding: EdgeInsets.all(40),
        child: Icon(Icons.check_circle_outline, color: sage, size: 72),
      ),
      _wide(
        'View my cameras',
        () => Navigator.of(context).pop(_savedId),
        primary: true,
        icon: Icons.grid_view,
      ),
    ],
    SetupStep.failure => [
      _intro('Couldn’t connect just yet.', _error),
      _wide(
        'Try again',
        () => _go(_retryStep),
        primary: true,
        icon: Icons.refresh,
      ),
    ],
    SetupStep.remove => [
      _intro(
        'Remove this camera?',
        '${_name.text} will be removed from Home Cameras. This does not change the camera itself.',
      ),
      _wide('Keep camera', () => _go(SetupStep.manual), primary: true),
      _wide('Remove camera', _remove, danger: true, icon: Icons.delete_outline),
    ],
  };

  @override
  void dispose() {
    ++_operation;
    _discovery.dispose();
    for (final node in _fieldFocus.values) {
      node.dispose();
    }
    for (final controller in [_name, _room, _url, _sub, _username, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: panel,
          child: SizedBox(
            width: min(500, MediaQuery.sizeOf(context).width),
            height: double.infinity,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 18, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TvButton(
                            'Back',
                            onPressed: _back,
                            icon: Icons.chevron_left,
                          ),
                          TvButton(
                            'Close panel',
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).pop(_savedId),
                            icon: Icons.close,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FocusTraversalGroup(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(30, 16, 30, 24),
                          child: Form(
                            key: _form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ..._body(),
                                if (_busy)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: LinearProgressIndicator(),
                                  ),
                                if (_error.isNotEmpty &&
                                    _step != SetupStep.failure)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: Text(
                                      _error,
                                      style: const TextStyle(color: amber),
                                      semanticsLabel: _error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      child: Text(
                        'Credentials are protected on this TV. Most local RTSP cameras send unencrypted video. Use a trusted network.',
                        style: TextStyle(fontSize: 11, color: fog),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
