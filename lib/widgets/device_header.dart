import 'package:flutter/material.dart';

import '../../core/byte_color.dart';

class DeviceHeader extends StatefulWidget {
  final String deviceName;
  final bool isConnected;
  final String port;
  final String idfVersion;
  final String firmwareVersion;

  /// Async so the refresh button can spin for the actual duration of
  /// the operation instead of guessing.
  final Future<void> Function()? onRefresh;

  const DeviceHeader({
    super.key,
    this.deviceName = 'ESP32-S3 Controller',
    this.isConnected = true,
    this.port = '/dev/ttyUSB0',
    this.idfVersion = 'ESP-IDF 5.2',
    this.firmwareVersion = 'FW v1.0.3',
    this.onRefresh,
  });

  @override
  State<DeviceHeader> createState() => _DeviceHeaderState();
}

class _DeviceHeaderState extends State<DeviceHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isConnected
        ? ByteColor.cyan
        : ByteColor.mutedText;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = widget.isConnected ? _pulseController.value : 0.0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ByteColor.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Color.lerp(ByteColor.border, ByteColor.cyan, t * 0.5)!,
            ),
            boxShadow: widget.isConnected
                ? [
                    BoxShadow(
                      color: ByteColor.cyan.withValues(alpha: 0.08 + 0.10 * t),
                      blurRadius: 16 + 10 * t,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ByteColor.surfaceHover,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.memory, color: ByteColor.cyan, size: 22),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deviceName,
                  style: const TextStyle(
                    color: ByteColor.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    _PulsingDot(
                      color: statusColor,
                      animate: widget.isConnected,
                      controller: _pulseController,
                    ),
                    const SizedBox(width: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(color: statusColor, fontSize: 12),
                      child: Text(
                        widget.isConnected ? 'Connected' : 'Disconnected',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  '${widget.port}  •  ${widget.idfVersion}  •  ${widget.firmwareVersion}',
                  style: const TextStyle(
                    color: ByteColor.mutedText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (widget.onRefresh != null)
            _RefreshButton(onTap: widget.onRefresh!),
        ],
      ),
    );
  }
}

/// Status dot that gently pulses (scale + glow) while [animate] is true,
/// and settles to a flat dot when disconnected.
class _PulsingDot extends StatelessWidget {
  final Color color;
  final bool animate;
  final AnimationController controller;

  const _PulsingDot({
    required this.color,
    required this.animate,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = animate ? controller.value : 0.0;
        final scale = 1.0 + (t * 0.35);
        final glowOpacity = animate ? (0.35 * (1 - t)) : 0.0;

        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (animate)
                Opacity(
                  opacity: glowOpacity,
                  child: Container(
                    width: 14 * scale,
                    height: 14 * scale,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Refresh icon button with hover highlight, press-down scale, and a
/// continuous spin for the actual duration of [onTap]'s future.
class _RefreshButton extends StatefulWidget {
  final Future<void> Function() onTap;

  const _RefreshButton({required this.onTap});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  bool _hovering = false;
  bool _pressed = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_refreshing) return; // ignore double-taps mid-refresh

    setState(() => _refreshing = true);
    _spinController.repeat();

    try {
      await widget.onTap();
    } finally {
      if (mounted) {
        // Let the current rotation finish instead of snapping to a stop.
        final remaining = 1.0 - (_spinController.value % 1.0);
        await _spinController.animateTo(
          _spinController.value + remaining,
          curve: Curves.easeOut,
        );
        _spinController.stop();
        _spinController.value = 0;
        if (mounted) if (mounted) setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Refresh',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _handleTap,
          child: AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _hovering ? ByteColor.surfaceHover : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: RotationTransition(
                turns: _spinController,
                child: Icon(
                  Icons.refresh,
                  size: 16,
                  color: (_hovering || _refreshing)
                      ? ByteColor.cyan
                      : ByteColor.mutedText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
