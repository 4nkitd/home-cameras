import 'package:flutter/material.dart';

const background = Color(0xff191d1c);
const panel = Color(0xff282e2b);
const chalk = Color(0xfff5f6f2);
const fog = Color(0xffb4bdb7);
const sage = Color(0xffa7c4ae);
const amber = Color(0xffe9bc7a);
const focusAccent = Color(0xff2f6bff);

ThemeData homeTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: background,
  colorScheme: const ColorScheme.dark(
    primary: sage,
    surface: panel,
    onSurface: chalk,
    onPrimary: background,
    error: Color(0xffffc2b8),
  ),
  fontFamily: 'Roboto',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w500,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w500,
      letterSpacing: -.6,
    ),
    titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 16, color: chalk),
    bodyMedium: TextStyle(fontSize: 14, color: fog, height: 1.4),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withValues(alpha: .035),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff49504b)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff49504b)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: chalk, width: 2),
    ),
  ),
  dialogTheme: const DialogThemeData(backgroundColor: panel),
  dividerColor: const Color(0xff39413b),
);

class TvButton extends StatelessWidget {
  const TvButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.selected = false,
    this.autofocus = false,
    this.focusNode,
    this.compact = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool selected;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool compact;
  final bool danger;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: compact ? label : '',
    child: TextButton(
      onPressed: onPressed,
      autofocus: autofocus,
      focusNode: focusNode,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? fog.withValues(alpha: .35)
              : primary
              ? background
              : danger
              ? const Color(0xffffc2b8)
              : chalk,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => primary
              ? chalk
              : states.contains(WidgetState.focused) || selected
              ? const Color(0xff414c44)
              : const Color(0xff252b28),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? primary
                      ? focusAccent
                      : chalk
                : Colors.transparent,
            width: 3,
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 19, semanticLabel: compact ? label : null),
          if (!compact) ...[
            if (icon != null) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.home_outlined,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: sage.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 40, color: sage),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(message, textAlign: TextAlign.center),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    ),
  );
}
