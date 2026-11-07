import 'dart:async';
import '../theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

bool usesCupertino(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

class AdaptivePage extends StatelessWidget {
  const AdaptivePage(
      {super.key,
      required this.title,
      required this.body,
      this.trailing,
      this.contentMaxWidth = 760});
  final String title;
  final Widget body;
  final Widget? trailing;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    // Scaffolds consume the navigation bars first; SafeArea handles only the
    // remaining system insets, including loading and error states.
    final content = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: SizedBox.expand(child: body),
        ),
      ),
    );
    if (!usesCupertino(context)) {
      return Scaffold(
          appBar: AppBar(
              title: Text(title), actions: [if (trailing != null) trailing!]),
          body: content);
    }
    final colors = Theme.of(context).colorScheme;
    return CupertinoPageScaffold(
      backgroundColor: colors.surface,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: trailing,
        backgroundColor: colors.surface,
        border: Border(
            bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
        transitionBetweenRoutes: false,
      ),
      child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyLarge!, child: content),
    );
  }
}

class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton(
      {super.key,
      required this.onPressed,
      required this.child,
      this.style,
      this.textOnly = false});
  const AdaptiveButton.text(
      {super.key, required this.onPressed, required this.child, this.style})
      : textOnly = true;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool textOnly;

  @override
  Widget build(BuildContext context) {
    if (!usesCupertino(context)) {
      return textOnly
          ? TextButton(onPressed: onPressed, style: style, child: child)
          : ElevatedButton(onPressed: onPressed, style: style, child: child);
    }
    final colors = Theme.of(context).colorScheme;
    final themeStyle = Theme.of(context).elevatedButtonTheme.style;
    final resolved = style?.merge(themeStyle) ?? themeStyle;
    final states = <WidgetState>{if (onPressed == null) WidgetState.disabled};
    final foreground = onPressed == null
        ? resolved?.foregroundColor?.resolve(states) ?? colors.onSurfaceVariant
        : textOnly
            ? colors.primary
            : resolved?.foregroundColor?.resolve(states) ?? colors.onPrimary;
    final button = CupertinoButton(
      onPressed: onPressed,
      color: textOnly
          ? null
          : resolved?.backgroundColor?.resolve(states) ?? colors.primary,
      disabledColor: resolved?.backgroundColor?.resolve(states) ??
          colors.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: BorderRadius.circular(12),
      child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: DefaultTextStyle.merge(
              style: AppTheme.fontStyle.copyWith(
                  color: foreground, fontSize: 16, fontWeight: FontWeight.w500),
              child: child)),
    );
    final side = textOnly ? null : resolved?.side?.resolve(states);
    if (side == null || side.style == BorderStyle.none) return button;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(side),
        borderRadius: BorderRadius.circular(12),
      ),
      child: button,
    );
  }
}

class AdaptiveIconButton extends StatelessWidget {
  const AdaptiveIconButton(
      {super.key,
      required this.tooltip,
      required this.icon,
      required this.cupertinoIcon,
      this.cupertinoSize,
      required this.onPressed});
  final String tooltip;
  final IconData icon;
  final IconData cupertinoIcon;
  final double? cupertinoSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => usesCupertino(context)
      ? Tooltip(
          message: tooltip,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            child: Icon(cupertinoIcon,
                size: cupertinoSize, semanticLabel: tooltip),
          ))
      : IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onPressed);
}

class AdaptiveTextField extends StatelessWidget {
  const AdaptiveTextField(
      {super.key,
      required this.controller,
      required this.decoration,
      this.focusNode,
      this.textCapitalization = TextCapitalization.none,
      this.keyboardType,
      this.inputFormatters,
      this.onChanged});
  final TextEditingController controller;
  final InputDecoration decoration;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (!usesCupertino(context)) {
      return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: decoration);
    }
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: textCapitalization,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        placeholder: decoration.labelText,
        style: AppTheme.fontStyle.copyWith(color: colors.onSurface),
        placeholderStyle:
            AppTheme.fontStyle.copyWith(color: colors.onSurfaceVariant),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant)),
      ),
      if (decoration.errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(decoration.errorText!,
              style: TextStyle(color: colors.error, fontSize: 13)),
        ),
    ]);
  }
}

class AdaptiveLoading extends StatelessWidget {
  const AdaptiveLoading({super.key});
  @override
  Widget build(BuildContext context) => usesCupertino(context)
      ? const CupertinoActivityIndicator()
      : const CircularProgressIndicator();
}

Future<T?> showAdaptiveSheet<T>(
    {required BuildContext context, required WidgetBuilder builder}) {
  if (!usesCupertino(context)) {
    return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => SafeArea(top: false, child: Builder(builder: builder)));
  }
  final materialTheme = Theme.of(context);
  return showCupertinoModalPopup<T>(
    context: context,
    semanticsDismissible: true,
    builder: (popupContext) => Theme(
        data: materialTheme,
        child: SafeArea(
            bottom: false,
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(popupContext).height * 0.9),
              padding: const EdgeInsets.only(top: 20),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: materialTheme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20))),
              child: DefaultTextStyle(
                  style: materialTheme.textTheme.bodyLarge!,
                  child:
                      SafeArea(top: false, child: Builder(builder: builder))),
            ))),
  );
}

Route<void> adaptiveRoute(BuildContext context, WidgetBuilder builder) =>
    usesCupertino(context)
        ? CupertinoPageRoute<void>(builder: builder)
        : MaterialPageRoute<void>(builder: builder);

Future<int?> showCupertinoValuePicker(
        {required BuildContext context,
        required String title,
        required List<int> values,
        required int value,
        required String Function(int) label}) =>
    showAdaptiveSheet<int>(
        context: context,
        builder: (_) => _ValuePicker(
            title: title, values: values, value: value, label: label));

class _ValuePicker extends StatefulWidget {
  const _ValuePicker(
      {required this.title,
      required this.values,
      required this.value,
      required this.label});
  final String title;
  final List<int> values;
  final int value;
  final String Function(int) label;
  @override
  State<_ValuePicker> createState() => _ValuePickerState();
}

class _ValuePickerState extends State<_ValuePicker> {
  late final FixedExtentScrollController _controller;
  late int _selected;
  @override
  void initState() {
    super.initState();
    _selected = widget.value;
    _controller = FixedExtentScrollController(
        initialItem: widget.values.indexOf(_selected));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          CupertinoButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          Expanded(child: Text(widget.title, textAlign: TextAlign.center)),
          CupertinoButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: const Text('Concluir')),
        ]),
        SizedBox(
            height: 216,
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: 40,
              onSelectedItemChanged: (index) {
                _selected = widget.values[index];
              },
              children: widget.values
                  .map((value) => Center(child: Text(widget.label(value))))
                  .toList(),
            )),
      ]));
}

final _notices = Expando<VoidCallback>();

void showAppMessage(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction}) {
  if (!usesCupertino(context)) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          persist: false,
          action: onAction == null
              ? null
              : SnackBarAction(label: actionLabel!, onPressed: onAction)));
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  _notices[overlay]?.call();
  late OverlayEntry entry;
  var dismissed = false;
  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    entry.remove();
    entry.dispose();
    if (_notices[overlay] == dismiss) _notices[overlay] = null;
  }

  entry = OverlayEntry(
      builder: (_) => _CupertinoNotice(
          message: message,
          onDismiss: dismiss,
          actionLabel: actionLabel,
          onAction: onAction));
  _notices[overlay] = dismiss;
  overlay.insert(entry);
}

class _CupertinoNotice extends StatefulWidget {
  const _CupertinoNotice(
      {required this.message,
      required this.onDismiss,
      this.actionLabel,
      this.onAction});
  final String message;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  State<_CupertinoNotice> createState() => _CupertinoNoticeState();
}

class _CupertinoNoticeState extends State<_CupertinoNotice> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        left: MediaQuery.paddingOf(context).left + 16,
        right: MediaQuery.paddingOf(context).right + 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom > 0
            ? MediaQuery.viewInsetsOf(context).bottom + 12
            : MediaQuery.paddingOf(context).bottom + 62,
        child: Semantics(
            liveRegion: true,
            child: CupertinoPopupSurface(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(
                    child: Text(widget.message,
                        style: CupertinoTheme.of(context).textTheme.textStyle)),
                if (widget.onAction != null)
                  CupertinoButton(
                      onPressed: () {
                        widget.onDismiss();
                        widget.onAction!();
                      },
                      child: Text(widget.actionLabel!)),
                CupertinoButton(
                    onPressed: widget.onDismiss,
                    child: const Icon(CupertinoIcons.xmark,
                        size: 16, semanticLabel: 'Fechar mensagem')),
              ]),
            ))),
      );
}

class AdaptiveSlideAction extends StatelessWidget {
  const AdaptiveSlideAction(
      {super.key,
      required this.onPressed,
      required this.backgroundColor,
      required this.foregroundColor,
      required this.icon,
      required this.label});
  final void Function(BuildContext) onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!usesCupertino(context)) {
      return SlidableAction(
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          icon: icon,
          label: label);
    }
    return Expanded(
        child: ColoredBox(
            color: backgroundColor,
            child: CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: () {
                Slidable.of(context)?.close();
                onPressed(context);
              },
              child: Text(label,
                  style: TextStyle(color: foregroundColor, fontSize: 15)),
            )));
  }
}

Future<bool> showAdaptiveConfirmation(BuildContext context,
    {required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false}) async {
  if (usesCupertino(context)) {
    return await showCupertinoDialog<bool>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
                  title: Text(title, style: AppTheme.fontStyle),
                  content: Text(message, style: AppTheme.fontStyle),
                  actions: [
                    CupertinoDialogAction(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child:
                            const Text('Cancelar', style: AppTheme.fontStyle)),
                    CupertinoDialogAction(
                        isDestructiveAction: destructive,
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(confirmLabel, style: AppTheme.fontStyle)),
                  ],
                )) ??
        false;
  }
  return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(confirmLabel)),
                ],
              )) ??
      false;
}
