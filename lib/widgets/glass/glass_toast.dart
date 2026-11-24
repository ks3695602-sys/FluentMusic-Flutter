import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:musify/main.dart';
import 'package:musify/widgets/mini_player.dart';

/// Shows a queued, swipe-dismissible glass toast above the app dock.
///
/// The overlay is scoped to the nearest root overlay, so independent app
/// windows/routes do not share toast queues.
void showGlassToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || message.trim().isEmpty) return;

  final queues = _GlassToastQueue.queues;
  final queue = queues[overlay] ??= _GlassToastQueue(overlay);
  queue.enqueue(
    _GlassToastMessage(message: message, icon: icon),
    duration: duration,
    reducedMotion: MediaQuery.of(context).disableAnimations,
    bottomInset: MediaQuery.viewPaddingOf(context).bottom,
  );
}

class _GlassToastMessage {
  const _GlassToastMessage({required this.message, this.icon});

  final String message;
  final IconData? icon;
}

class _QueuedGlassToast {
  const _QueuedGlassToast({
    required this.message,
    required this.duration,
    required this.reducedMotion,
    required this.bottomInset,
  });

  final _GlassToastMessage message;
  final Duration duration;
  final bool reducedMotion;
  final double bottomInset;
}

class _GlassToastQueue {
  _GlassToastQueue(this.overlay);

  static final Expando<_GlassToastQueue> queues =
      Expando<_GlassToastQueue>('glass toast queues');

  final OverlayState overlay;
  final List<_QueuedGlassToast> _pending = [];
  OverlayEntry? _entry;
  GlobalKey<_GlassToastEntryState>? _entryKey;
  Timer? _timer;
  bool _dismissing = false;

  void enqueue(
    _GlassToastMessage message, {
    required Duration duration,
    required bool reducedMotion,
    required double bottomInset,
  }) {
    _pending.add(
      _QueuedGlassToast(
        message: message,
        duration: duration,
        reducedMotion: reducedMotion,
        bottomInset: bottomInset,
      ),
    );
    _showNext();
  }

  void _showNext() {
    if (_entry != null || _pending.isEmpty || !overlay.mounted) return;

    final toast = _pending.removeAt(0);
    final key = GlobalKey<_GlassToastEntryState>();
    _entryKey = key;
    _entry = OverlayEntry(
      builder: (_) => _GlassToastEntry(
        key: key,
        toast: toast,
        onDismiss: _dismissActive,
        onDismissed: _finishActive,
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(toast.duration, _dismissActive);
  }

  void _dismissActive() {
    if (_dismissing || _entry == null) return;
    _dismissing = true;
    _entryKey?.currentState?.dismiss();
  }

  void _finishActive() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _entryKey = null;
    _dismissing = false;
    _showNext();
  }
}

class _GlassToastEntry extends StatefulWidget {
  const _GlassToastEntry({
    super.key,
    required this.toast,
    required this.onDismiss,
    required this.onDismissed,
  });

  final _QueuedGlassToast toast;
  final VoidCallback onDismiss;
  final VoidCallback onDismissed;

  @override
  State<_GlassToastEntry> createState() => _GlassToastEntryState();
}

class _GlassToastEntryState extends State<_GlassToastEntry> {
  bool _visible = false;
  bool _dismissStarted = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    if (widget.toast.reducedMotion) {
      _visible = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  void dismiss() {
    if (_dismissStarted) return;
    _dismissStarted = true;
    if (widget.toast.reducedMotion) {
      widget.onDismissed();
      return;
    }
    if (mounted) setState(() => _visible = false);
    Timer(const Duration(milliseconds: 180), () {
      if (mounted) widget.onDismissed();
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 52 ||
        (details.primaryVelocity?.abs() ?? 0) > 500) {
      widget.onDismiss();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toast = widget.toast;
    final transitionDuration = toast.reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final dockOffset = 108.0 +
        (audioHandler.mediaItem.value == null ? 0 : MiniPlayer.playerHeight);

    return Positioned(
      left: 16,
      right: 16,
      bottom: dockOffset + toast.bottomInset,
      child: SafeArea(
        top: false,
        child: IgnorePointer(
          ignoring: !_visible,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              setState(() => _dragOffset += details.delta.dx);
            },
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: AnimatedSlide(
              offset: _visible ? Offset.zero : const Offset(0, 0.35),
              duration: transitionDuration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: transitionDuration,
                child: Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xD91B1B20),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: CupertinoColors.white.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withValues(alpha: 0.2),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                toast.message.icon ?? CupertinoIcons.heart_fill,
                                color: const Color(0xFFFF5A78),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  toast.message.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}
