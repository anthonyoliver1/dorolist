import 'package:flutter/services.dart';

class TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.isEmpty) {
      return TextEditingValue(
        text: "00:00",
        selection: TextSelection.collapsed(offset: 5),
      );
    }

    text =
        text.padLeft(4, '0').substring(text.length > 4 ? text.length - 4 : 0);

    String formattedText = '${text.substring(0, 2)}:${text.substring(2, 4)}';

    int newOffset = formattedText.length;

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}
