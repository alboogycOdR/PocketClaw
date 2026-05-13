/// Pre-processes text before passing to Supertonic encoder.
/// Handles financial expressions, dates, times, units, abbreviations.
/// Verified patterns from `supertone-inc/supertonic` (web/src/helper.js
/// and py/helper.py).
library;

class SupertonicTextPreprocessor {
  String process(String text) {
    var t = text;
    t = _removeEmoji(t);
    t = _normalizeFinancial(t);
    t = _normalizeDates(t);
    t = _normalizeTimes(t);
    t = _normalizeUnits(t);
    t = _normalizeNumbers(t);
    t = _normalizeAbbreviations(t);
    t = _cleanPunctuation(t);
    return t.trim();
  }

  String _removeEmoji(String text) {
    return text.replaceAll(
      RegExp(r'[\u{1F000}-\u{1FFFF}]|\u{200D}|\u{FE0F}', unicode: true),
      '',
    );
  }

  String _normalizeFinancial(String text) {
    text = text.replaceAllMapped(
      RegExp(r'\$(\d+(?:\.\d+)?)(M|K|B)\b', caseSensitive: false),
      (m) {
        final num = double.tryParse(m[1]!) ?? 0;
        final suffix = m[2]!.toUpperCase();
        final word = switch (suffix) {
          'M' => 'million',
          'K' => 'thousand',
          'B' => 'billion',
          _ => '',
        };
        return '${_numToWords(num)} $word dollars';
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'\$(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)'),
      (m) {
        final clean = m[1]!.replaceAll(',', '');
        final parts = clean.split('.');
        final dollars = _intToWords(int.tryParse(parts[0]) ?? 0);
        if (parts.length > 1 && parts[1] != '00') {
          final cents = _intToWords(int.tryParse(parts[1]) ?? 0);
          return '$dollars dollars and $cents cents';
        }
        return '$dollars dollars';
      },
    );
    return text;
  }

  String _normalizeTimes(String text) {
    return text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)\b'),
      (m) {
        final hour = int.tryParse(m[1]!) ?? 0;
        final min = int.tryParse(m[2]!) ?? 0;
        final ampm = m[3]!.toUpperCase();
        final hourW = _intToWords(hour);
        final minW = min == 0
            ? ''
            : min < 10
                ? 'oh ${_intToWords(min)}'
                : _intToWords(min);
        return minW.isEmpty ? '$hourW $ampm' : '$hourW $minW $ampm';
      },
    );
  }

  String _normalizeDates(String text) {
    const days = {
      'Mon': 'Monday', 'Tue': 'Tuesday', 'Wed': 'Wednesday',
      'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday', 'Sun': 'Sunday',
    };
    const months = {
      'Jan': 'January', 'Feb': 'February', 'Mar': 'March', 'Apr': 'April',
      'May': 'May', 'Jun': 'June', 'Jul': 'July', 'Aug': 'August',
      'Sep': 'September', 'Oct': 'October', 'Nov': 'November', 'Dec': 'December',
    };
    var t = text;
    for (final e in days.entries) {
      t = t.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }
    for (final e in months.entries) {
      t = t.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
    }
    return t;
  }

  String _normalizeUnits(String text) {
    final units = <String, String>{
      'kph': 'kilometers per hour', 'mph': 'miles per hour',
      'km': 'kilometers', 'mi': 'miles',
      'kg': 'kilograms', 'lb': 'pounds',
      'ms': 'milliseconds', 'kHz': 'kilohertz',
      'MHz': 'megahertz', 'GHz': 'gigahertz',
      'GB': 'gigabytes', 'MB': 'megabytes',
      'KB': 'kilobytes', 'TB': 'terabytes',
      'px': 'pixels', 'fps': 'frames per second',
    };
    var t = text;
    for (final e in units.entries) {
      t = t.replaceAllMapped(
        RegExp(r'(\d+(?:\.\d+)?)' + e.key + r'\b'),
        (m) => '${m[1]} ${e.value}',
      );
    }
    t = t.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)h\b'),
      (m) => '${m[1]} hours',
    );
    return t;
  }

  String _normalizeNumbers(String text) {
    return text.replaceAllMapped(
      RegExp(r'\b\d{1,3}(?:,\d{3})+\b'),
      (m) => m[0]!.replaceAll(',', ''),
    );
  }

  String _normalizeAbbreviations(String text) {
    const abbrevs = {
      'ext.': 'extension', 'dept.': 'department', 'approx.': 'approximately',
      'Dr.': 'Doctor', 'Mr.': 'Mister', 'Mrs.': 'Missus', 'Prof.': 'Professor',
      'vs.': 'versus', 'etc.': 'et cetera', 'i.e.': 'that is',
      'e.g.': 'for example',
      'XAUUSD': 'X-A-U-U-S-D', 'EURUSD': 'E-U-R-U-S-D',
    };
    var t = text;
    for (final e in abbrevs.entries) {
      t = t.replaceAll(e.key, e.value);
    }
    return t;
  }

  String _cleanPunctuation(String text) {
    return text
        .replaceAll(RegExp(r'[*_`~]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _intToWords(int n) {
    if (n == 0) return 'zero';
    if (n < 0) return 'negative ${_intToWords(-n)}';
    const ones = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven',
      'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen',
      'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'
    ];
    const tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty',
      'sixty', 'seventy', 'eighty', 'ninety'
    ];
    if (n < 20) return ones[n];
    if (n < 100) {
      return tens[n ~/ 10] + (n % 10 != 0 ? '-${ones[n % 10]}' : '');
    }
    if (n < 1000) {
      return '${ones[n ~/ 100]} hundred'
          '${n % 100 != 0 ? ' ${_intToWords(n % 100)}' : ''}';
    }
    if (n < 1000000) {
      return '${_intToWords(n ~/ 1000)} thousand'
          '${n % 1000 != 0 ? ' ${_intToWords(n % 1000)}' : ''}';
    }
    return '$n';
  }

  String _numToWords(double n) {
    final intPart = n.truncate();
    final fracStr = (n - intPart).toStringAsFixed(1);
    final fracDigit = int.tryParse(fracStr.split('.').last) ?? 0;
    if (fracDigit == 0) return _intToWords(intPart);
    return '${_intToWords(intPart)} point $fracDigit';
  }
}
