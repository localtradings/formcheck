import 'package:material_ui/material_ui.dart';

const ink = Color(0xFF14191A);
const canvas = Color(0xFF101414);
const surface = Color(0xFF1C2322);
const line = Color(0xFF3B4742);
const lime = Color(0xFFC8FA7A);
const soft = Color(0xFFB9C9BF);
const amber = Color(0xFFFFCB86);

ThemeData formTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: lime,
    brightness: Brightness.dark,
    surface: surface,
    primary: lime,
    onPrimary: ink,
    onSurface: const Color(0xFFF4F7F1),
    onSurfaceVariant: soft,
    outline: line,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    visualDensity: VisualDensity.standard,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 35,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        height: 1.04,
      ),
      headlineSmall: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 640});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: surface,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class RaisedAction extends StatefulWidget {
  const RaisedAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<RaisedAction> createState() => _RaisedActionState();
}

class _RaisedActionState extends State<RaisedAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: Container(
        decoration: ShapeDecoration(
          color: enabled ? const Color(0xFF658C38) : surface,
          shape: const StadiumBorder(),
        ),
        child: AnimatedPadding(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: _pressed && enabled
              ? const EdgeInsets.only(top: 4)
              : const EdgeInsets.only(bottom: 4),
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 21),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(widget.label, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
  );
}
