part of '../formula_engine.dart';

extension _ParserFunctionsPart on _Parser {
  Object _callFunc(String name, List<Object> args) {
    switch (name) {
      // ── toplama / sayma ────────────────────────────────────────────────
      case 'SUM':
        return _numbers(args).fold<double>(0, (a, b) => a + b);
      case 'SUMSQ':
        return _numbers(args).fold<double>(0, (a, b) => a + b * b);
      case 'AVERAGE':
        final n = _numbers(args);
        if (n.isEmpty) return const FormulaError('#SAYI/0!');
        return n.reduce((a, b) => a + b) / n.length;
      case 'MIN':
        final n = _numbers(args);
        return n.isEmpty ? 0 : n.reduce(math.min);
      case 'MAX':
        final n = _numbers(args);
        return n.isEmpty ? 0 : n.reduce(math.max);
      case 'COUNT':
        return _numbers(args).length.toDouble();
      case 'COUNTA':
        return _flatten(args)
            .where((v) => !(v is String && v.trim().isEmpty))
            .length
            .toDouble();
      case 'COUNTBLANK':
        return _flatten(args)
            .where((v) => v is String && v.trim().isEmpty)
            .length
            .toDouble();
      case 'PRODUCT':
        final n = _numbers(args);
        return n.isEmpty ? 0 : n.reduce((a, b) => a * b);
      case 'MEDIAN':
        final n = _numbers(args)..sort();
        if (n.isEmpty) return const FormulaError('#SAYI!');
        final mid = n.length ~/ 2;
        return n.length.isOdd ? n[mid] : (n[mid - 1] + n[mid]) / 2;
      case 'MODE':
        final n = _numbers(args);
        if (n.isEmpty) return const FormulaError('#YOK');
        final counts = <double, int>{};
        for (final v in n) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
        var best = n.first, bestCount = 0;
        counts.forEach((k, v) {
          if (v > bestCount) {
            best = k;
            bestCount = v;
          }
        });
        return bestCount < 2 ? const FormulaError('#YOK') : best;
      case 'STDEV':
      case 'STDEVP':
      case 'VAR':
      case 'VARP':
        final n = _numbers(args);
        final population = name.endsWith('P');
        if (n.length < (population ? 1 : 2)) {
          return const FormulaError('#SAYI/0!');
        }
        final mean = n.reduce((a, b) => a + b) / n.length;
        final ss = n.fold<double>(0, (a, b) => a + (b - mean) * (b - mean));
        final divisor = population ? n.length : n.length - 1;
        final variance = ss / divisor;
        return name.startsWith('VAR') ? variance : math.sqrt(variance);
      case 'LARGE':
      case 'SMALL':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final n = _numbers([args.first])..sort();
        final k = _numArg(args, 1, 1).round();
        if (k < 1 || k > n.length) return const FormulaError('#SAYI!');
        return name == 'LARGE' ? n[n.length - k] : n[k - 1];
      case 'RANK':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final v = _numArg(args, 0);
        final n = _numbers([args[1]]);
        final asc = args.length > 2 && FormulaEngine.toNum(_arg(args, 2)) != 0;
        n.sort();
        final idx = asc ? n.indexOf(v) : n.lastIndexOf(v);
        if (idx < 0) return const FormulaError('#YOK');
        return (asc ? idx + 1 : n.length - idx).toDouble();
      case 'SUMPRODUCT':
        if (args.isEmpty) return const FormulaError('#DEĞER!');
        return _sumProduct(args);
      case 'SUBTOTAL':
        if (args.isEmpty) return const FormulaError('#DEĞER!');
        final code = _numArg(args, 0).round() % 100;
        final rest = args.sublist(1);
        return switch (code) {
          1 => _callFunc('AVERAGE', rest),
          2 => _callFunc('COUNT', rest),
          3 => _callFunc('COUNTA', rest),
          4 => _callFunc('MAX', rest),
          5 => _callFunc('MIN', rest),
          6 => _callFunc('PRODUCT', rest),
          _ => _callFunc('SUM', rest),
        };

      // ── koşullu toplama ────────────────────────────────────────────────
      case 'SUMIF':
        return _sumIf(args);
      case 'COUNTIF':
        return _countIf(args);
      case 'AVERAGEIF':
        return _averageIf(args);
      case 'SUMIFS':
      case 'COUNTIFS':
      case 'AVERAGEIFS':
      case 'MAXIFS':
      case 'MINIFS':
        return _multiIf(name, args);

      // ── mantık ─────────────────────────────────────────────────────────
      case 'IF':
        if (args.isEmpty) return const FormulaError('#DEĞER!');
        final cond = _arg(args, 0);
        if (cond is FormulaError) return cond;
        if (FormulaEngine.toBool(cond)) return _arg(args, 1);
        return args.length >= 3 ? _arg(args, 2) : false;
      case 'IFS':
        for (var i = 0; i + 1 < args.length; i += 2) {
          final c = _arg(args, i);
          if (c is FormulaError) return c;
          if (FormulaEngine.toBool(c)) return _arg(args, i + 1);
        }
        return const FormulaError('#YOK');
      case 'SWITCH':
        final subject = _arg(args, 0);
        for (var i = 1; i + 1 < args.length; i += 2) {
          if (_compare('=', subject, _arg(args, i))) return _arg(args, i + 1);
        }
        return args.length.isEven ? _arg(args, args.length - 1) : const FormulaError('#YOK');
      case 'CHOOSE':
        final idx = _numArg(args, 0).round();
        if (idx < 1 || idx >= args.length) return const FormulaError('#DEĞER!');
        return _arg(args, idx);
      case 'AND':
        return _flatten(args)
            .where((v) => !(v is String && v.trim().isEmpty))
            .every(FormulaEngine.toBool);
      case 'OR':
        return _flatten(args)
            .where((v) => !(v is String && v.trim().isEmpty))
            .any(FormulaEngine.toBool);
      case 'XOR':
        return _flatten(args).where(FormulaEngine.toBool).length.isOdd;
      case 'NOT':
        return !FormulaEngine.toBool(_arg(args, 0));
      case 'IFERROR':
        final v = _safe(() => _arg(args, 0));
        if (v is FormulaError) return _arg(args, 1);
        return v;
      case 'IFNA':
        final v = _safe(() => _arg(args, 0));
        if (v is FormulaError && v.code == '#YOK') return _arg(args, 1);
        return v;
      case 'NA':
        return const FormulaError('#YOK');

      // ── bilgi ──────────────────────────────────────────────────────────
      case 'ISBLANK':
        final v = args.isEmpty ? '' : _arg(args, 0);
        return v is String && v.isEmpty;
      case 'ISNUMBER':
        final v = _safe(() => _arg(args, 0));
        return v is num;
      case 'ISTEXT':
        final v = _safe(() => _arg(args, 0));
        return v is String && v.isNotEmpty && double.tryParse(v) == null;
      case 'ISLOGICAL':
        return _safe(() => _arg(args, 0)) is bool;
      case 'ISERROR':
        return _safe(() => _arg(args, 0)) is FormulaError;
      case 'ISERR':
        final v = _safe(() => _arg(args, 0));
        return v is FormulaError && v.code != '#YOK';
      case 'ISNA':
        final v = _safe(() => _arg(args, 0));
        return v is FormulaError && v.code == '#YOK';
      case 'N':
        final v = _arg(args, 0);
        if (v is num) return v;
        if (v is bool) return v ? 1.0 : 0.0;
        return 0.0;
      case 'T':
        final v = _arg(args, 0);
        return v is String ? v : '';
      case 'TYPE':
        final v = _safe(() => _arg(args, 0));
        if (v is num) return 1.0;
        if (v is String) return 2.0;
        if (v is bool) return 4.0;
        return 16.0;

      // ── matematik ──────────────────────────────────────────────────────
      case 'ROUND':
        return _Parser._round(_numArg(args, 0), _numArg(args, 1).round());
      case 'ROUNDUP':
        return _Parser._roundDir(_numArg(args, 0), _numArg(args, 1).round(), true);
      case 'ROUNDDOWN':
        return _Parser._roundDir(_numArg(args, 0), _numArg(args, 1).round(), false);
      case 'TRUNC':
        return _Parser._roundDir(_numArg(args, 0), _numArg(args, 1).round(), false);
      case 'CEILING':
        final sig = _numArg(args, 1, 1);
        if (sig == 0) return 0.0;
        return (_numArg(args, 0) / sig).ceilToDouble() * sig;
      case 'FLOOR':
        final sig = _numArg(args, 1, 1);
        if (sig == 0) return const FormulaError('#SAYI/0!');
        return (_numArg(args, 0) / sig).floorToDouble() * sig;
      case 'ABS':
        return _numArg(args, 0).abs();
      case 'SIGN':
        final v = _numArg(args, 0);
        return v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0);
      case 'SQRT':
        final v = _numArg(args, 0);
        if (v < 0) return const FormulaError('#SAYI!');
        return math.sqrt(v);
      case 'POWER':
        return math.pow(_numArg(args, 0), _numArg(args, 1));
      case 'EXP':
        return math.exp(_numArg(args, 0));
      case 'LN':
        final v = _numArg(args, 0);
        if (v <= 0) return const FormulaError('#SAYI!');
        return math.log(v);
      case 'LOG10':
        final v = _numArg(args, 0);
        if (v <= 0) return const FormulaError('#SAYI!');
        return math.log(v) / math.ln10;
      case 'LOG':
        final v = _numArg(args, 0);
        final base = _numArg(args, 1, 10);
        if (v <= 0 || base <= 0 || base == 1) {
          return const FormulaError('#SAYI!');
        }
        return math.log(v) / math.log(base);
      case 'MOD':
        final a = _numArg(args, 0);
        final b = _numArg(args, 1);
        if (b == 0) return const FormulaError('#SAYI/0!');
        // Excel'de sonuç bölenin işaretini alır.
        return a - b * (a / b).floorToDouble();
      case 'QUOTIENT':
        final b = _numArg(args, 1);
        if (b == 0) return const FormulaError('#SAYI/0!');
        return (_numArg(args, 0) / b).truncateToDouble();
      case 'INT':
        return _numArg(args, 0).floorToDouble();
      case 'EVEN':
        final v = _numArg(args, 0);
        final r = (v.abs() / 2).ceilToDouble() * 2;
        return v < 0 ? -r : r;
      case 'ODD':
        final v = _numArg(args, 0);
        var r = (v.abs() / 2).ceilToDouble() * 2 - 1;
        if (r < 1) r = 1;
        return v < 0 ? -r : r;
      case 'FACT':
        final n = _numArg(args, 0).floor();
        if (n < 0 || n > 170) return const FormulaError('#SAYI!');
        var f = 1.0;
        for (var i = 2; i <= n; i++) {
          f *= i;
        }
        return f;
      case 'GCD':
        final n = _numbers(args).map((e) => e.abs().round()).toList();
        return n.isEmpty ? 0.0 : n.reduce(_Parser._gcd).toDouble();
      case 'LCM':
        final n = _numbers(args).map((e) => e.abs().round()).toList();
        if (n.isEmpty) return 0.0;
        return n.reduce((a, b) => a ~/ _Parser._gcd(a, b) * b).toDouble();
      case 'PI':
        return math.pi;
      case 'DEGREES':
        return _numArg(args, 0) * 180 / math.pi;
      case 'RADIANS':
        return _numArg(args, 0) * math.pi / 180;
      case 'SIN':
        return math.sin(_numArg(args, 0));
      case 'COS':
        return math.cos(_numArg(args, 0));
      case 'TAN':
        return math.tan(_numArg(args, 0));
      case 'ASIN':
        return math.asin(_numArg(args, 0));
      case 'ACOS':
        return math.acos(_numArg(args, 0));
      case 'ATAN':
        return math.atan(_numArg(args, 0));
      case 'ATAN2':
        return math.atan2(_numArg(args, 1), _numArg(args, 0));

      // ── metin ──────────────────────────────────────────────────────────
      case 'LEN':
        return _strArg(args, 0).length.toDouble();
      case 'UPPER':
        return _Parser._trUpper(_strArg(args, 0));
      case 'LOWER':
        return _Parser._trLower(_strArg(args, 0));
      case 'PROPER':
        return _strArg(args, 0)
            .split(' ')
            .map((w) => w.isEmpty
                ? w
                : _Parser._trUpper(w.substring(0, 1)) + _Parser._trLower(w.substring(1)))
            .join(' ');
      case 'TRIM':
        return _strArg(args, 0).trim().replaceAll(RegExp(r'\s+'), ' ');
      case 'CLEAN':
        return _strArg(args, 0)
            .replaceAll(RegExp(r'[\x00-\x1F]'), '');
      case 'LEFT':
        final t = _strArg(args, 0);
        final n = args.length >= 2 ? _numArg(args, 1).round() : 1;
        return t.substring(0, n.clamp(0, t.length));
      case 'RIGHT':
        final t = _strArg(args, 0);
        final n = args.length >= 2 ? _numArg(args, 1).round() : 1;
        return t.substring((t.length - n).clamp(0, t.length));
      case 'MID':
        final t = _strArg(args, 0);
        final start = _numArg(args, 1).round() - 1;
        final len = _numArg(args, 2).round();
        if (start < 0 || len < 0) return const FormulaError('#DEĞER!');
        if (start >= t.length) return '';
        return t.substring(start, (start + len).clamp(0, t.length));
      case 'FIND':
        final needle = _strArg(args, 0);
        final hay = _strArg(args, 1);
        final from = (args.length > 2 ? _numArg(args, 2).round() : 1) - 1;
        final idx = hay.indexOf(needle, from.clamp(0, hay.length));
        return idx < 0 ? const FormulaError('#DEĞER!') : (idx + 1).toDouble();
      case 'SEARCH':
        final needle = _Parser._trLower(_strArg(args, 0));
        final hay = _Parser._trLower(_strArg(args, 1));
        final from = (args.length > 2 ? _numArg(args, 2).round() : 1) - 1;
        final idx = hay.indexOf(needle, from.clamp(0, hay.length));
        return idx < 0 ? const FormulaError('#DEĞER!') : (idx + 1).toDouble();
      case 'SUBSTITUTE':
        final t = _strArg(args, 0);
        final from = _strArg(args, 1);
        final to = _strArg(args, 2);
        if (from.isEmpty) return t;
        if (args.length > 3) {
          final nth = _numArg(args, 3).round();
          var count = 0;
          var idx = 0;
          while (true) {
            final at = t.indexOf(from, idx);
            if (at < 0) return t;
            count++;
            if (count == nth) {
              return t.substring(0, at) + to + t.substring(at + from.length);
            }
            idx = at + from.length;
          }
        }
        return t.replaceAll(from, to);
      case 'REPLACE':
        final t = _strArg(args, 0);
        final start = _numArg(args, 1).round() - 1;
        final len = _numArg(args, 2).round();
        final rep = _strArg(args, 3);
        if (start < 0) return const FormulaError('#DEĞER!');
        final head = t.substring(0, start.clamp(0, t.length));
        final tail = t.substring((start + len).clamp(0, t.length));
        return '$head$rep$tail';
      case 'REPT':
        final t = _strArg(args, 0);
        final n = _numArg(args, 1).round();
        if (n < 0 || n * t.length > 32767) {
          return const FormulaError('#DEĞER!');
        }
        return t * n;
      case 'CONCAT':
      case 'CONCATENATE':
        return _flatten(args).map(FormulaEngine.toStr).join();
      case 'TEXTJOIN':
        final sep = _strArg(args, 0);
        final skipEmpty = args.length > 1 &&
            FormulaEngine.toBool(_arg(args, 1));
        final items = _flatten(args.sublist(math.min(2, args.length)))
            .map(FormulaEngine.toStr)
            .where((s) => !skipEmpty || s.isNotEmpty);
        return items.join(sep);
      case 'EXACT':
        return _strArg(args, 0) == _strArg(args, 1);
      case 'CHAR':
        return String.fromCharCode(_numArg(args, 0).round().clamp(0, 0x10FFFF));
      case 'CODE':
        final t = _strArg(args, 0);
        return t.isEmpty
            ? const FormulaError('#DEĞER!')
            : t.codeUnitAt(0).toDouble();
      case 'VALUE':
        var t = _strArg(args, 0).trim().replaceAll('%', '');
        if (t.contains(',') && t.contains('.')) {
          // "1.234,56" → binlik nokta, ondalık virgül
          t = t.replaceAll('.', '').replaceAll(',', '.');
        } else if (t.contains(',')) {
          t = t.replaceAll(',', '.');
        }
        final d = double.tryParse(t);
        return d ?? const FormulaError('#DEĞER!');
      case 'TEXT':
        final v = _arg(args, 0);
        final code = _strArg(args, 1);
        final numValue =
            v is num ? v.toDouble() : double.tryParse(v.toString());
        if (numValue == null) return FormulaEngine.toStr(v);
        return ExcelNumberFormat.parse(code).format(numValue).text;

      // ── tarih / saat ───────────────────────────────────────────────────
      case 'TODAY':
        final now = DateTime.now();
        return dateToExcelSerial(DateTime(now.year, now.month, now.day));
      case 'NOW':
        return dateToExcelSerial(DateTime.now());
      case 'DATE':
        return dateToExcelSerial(DateTime(_numArg(args, 0).round(),
            _numArg(args, 1).round(), _numArg(args, 2).round()));
      case 'TIME':
        return (_numArg(args, 0) * 3600 +
                _numArg(args, 1) * 60 +
                _numArg(args, 2)) /
            86400.0;
      case 'YEAR':
        return excelSerialToDate(_numArg(args, 0)).year.toDouble();
      case 'MONTH':
        return excelSerialToDate(_numArg(args, 0)).month.toDouble();
      case 'DAY':
        return excelSerialToDate(_numArg(args, 0)).day.toDouble();
      case 'HOUR':
        return excelSerialToDate(_numArg(args, 0)).hour.toDouble();
      case 'MINUTE':
        return excelSerialToDate(_numArg(args, 0)).minute.toDouble();
      case 'SECOND':
        return excelSerialToDate(_numArg(args, 0)).second.toDouble();
      case 'WEEKDAY':
        final dt = excelSerialToDate(_numArg(args, 0));
        final type = args.length > 1 ? _numArg(args, 1).round() : 1;
        final sunday0 = dt.weekday % 7; // 0=Pazar
        return switch (type) {
          2 => (dt.weekday).toDouble(), // 1=Pazartesi
          3 => (dt.weekday - 1).toDouble(),
          _ => (sunday0 + 1).toDouble(), // 1=Pazar
        };
      case 'DAYS':
        return (_numArg(args, 0) - _numArg(args, 1)).floorToDouble();
      case 'EDATE':
      case 'EOMONTH':
        final dt = excelSerialToDate(_numArg(args, 0));
        final months = _numArg(args, 1).round();
        final target = DateTime.utc(dt.year, dt.month + months, 1);
        if (name == 'EOMONTH') {
          final last = DateTime.utc(target.year, target.month + 1, 0);
          return dateToExcelSerial(last);
        }
        final lastDay = DateTime.utc(target.year, target.month + 1, 0).day;
        return dateToExcelSerial(DateTime.utc(
            target.year, target.month, math.min(dt.day, lastDay)));
      case 'DATEDIF':
        final a = excelSerialToDate(_numArg(args, 0));
        final b = excelSerialToDate(_numArg(args, 1));
        final unit = _strArg(args, 2).toUpperCase();
        var years = b.year - a.year;
        var months = b.month - a.month;
        var days = b.day - a.day;
        if (days < 0) months--;
        if (months < 0) {
          years--;
          months += 12;
        }
        return switch (unit) {
          'Y' => years.toDouble(),
          'M' => (years * 12 + months).toDouble(),
          _ => b.difference(a).inDays.toDouble(),
        };

      // ── arama ──────────────────────────────────────────────────────────
      case 'VLOOKUP':
      case 'HLOOKUP':
        return _lookup(name, args);
      case 'INDEX':
        return _index(args);
      case 'MATCH':
        return _matchFn(args);
      case 'ROW':
        // Argümansız: formülün kendi satırı (Excel davranışı).
        if (_Parser._isEmptyArgs(args)) return (selfR + 1).toDouble();
        if (args.first is! _RangeValue) return const FormulaError('#DEĞER!');
        return ((args.first as _RangeValue).r1 + 1).toDouble();
      case 'COLUMN':
        if (_Parser._isEmptyArgs(args)) return (selfC + 1).toDouble();
        if (args.first is! _RangeValue) return const FormulaError('#DEĞER!');
        return ((args.first as _RangeValue).c1 + 1).toDouble();
      case 'ROWS':
        if (args.isEmpty || args.first is! _RangeValue) return 1.0;
        final r = args.first as _RangeValue;
        return (r.r2 - r.r1 + 1).toDouble();
      case 'COLUMNS':
        if (args.isEmpty || args.first is! _RangeValue) return 1.0;
        final r = args.first as _RangeValue;
        return (r.c2 - r.c1 + 1).toDouble();

      // ── başvuru (referans) fonksiyonları ───────────────────────────────
      case 'OFFSET':
        return _offset(args);
      case 'INDIRECT':
        return _indirect(args);
      case 'ADDRESS':
        final row = _numArg(args, 0).round();
        final col = _numArg(args, 1).round();
        if (row < 1 || col < 1) return const FormulaError('#DEĞER!');
        final abs = args.length > 2 ? _numArg(args, 2, 1).round() : 1;
        final letters = _Parser._colName(col - 1);
        final colPart = (abs == 1 || abs == 3) ? '\$$letters' : letters;
        final rowPart = (abs == 1 || abs == 2) ? '\$$row' : '$row';
        final sheetPart = args.length > 4 ? _strArg(args, 4) : '';
        final prefix = sheetPart.isEmpty ? '' : "'$sheetPart'!";
        return '$prefix$colPart$rowPart';
      case 'LOOKUP':
        return _lookupVector(args);
      case 'XLOOKUP':
        return _xlookup(args);
      case 'FORMULATEXT':
        if (args.isEmpty || args.first is! _RangeValue) {
          return const FormulaError('#DEĞER!');
        }
        final ref = args.first as _RangeValue;
        final raw = eng.rawTextOf(ref.r1, ref.c1, ref.sheet);
        return raw.startsWith('=') ? raw : const FormulaError('#YOK');
      case 'ISFORMULA':
        if (args.isEmpty || args.first is! _RangeValue) return false;
        final ref = args.first as _RangeValue;
        return eng.rawTextOf(ref.r1, ref.c1, ref.sheet).startsWith('=');
      case 'ISREF':
        return args.isNotEmpty && args.first is _RangeValue;
      case 'ISEVEN':
      case 'ISODD':
        final v = FormulaEngine.toNum(_arg(args, 0)).truncate();
        return name == 'ISEVEN' ? v.isEven : v.isOdd;
      case 'ERROR.TYPE':
        final v = _safe(() => _arg(args, 0));
        if (v is! FormulaError) return const FormulaError('#YOK');
        return switch (v.code) {
          '#BOŞ!' || '#NULL!' => 1.0,
          '#SAYI/0!' || '#DIV/0!' => 2.0,
          '#DEĞER!' || '#VALUE!' => 3.0,
          '#BAŞV!' || '#REF!' => 4.0,
          '#AD?' || '#NAME?' => 5.0,
          '#SAYI!' || '#NUM!' => 6.0,
          _ => 7.0,
        };

      // ── matematik (ek) ─────────────────────────────────────────────────
      case 'MROUND':
        final x = _numArg(args, 0);
        final m = _numArg(args, 1);
        if (m == 0) return 0.0;
        if (x != 0 && (x < 0) != (m < 0)) return const FormulaError('#SAYI!');
        final q = x / m;
        // Excel yarımı SIFIRDAN UZAĞA yuvarlar (Dart round() da öyle).
        return q.round() * m;
      case 'CEILING.MATH':
      case 'FLOOR.MATH':
        final x = _numArg(args, 0);
        var sig = args.length > 1 ? _numArg(args, 1, 1) : 1.0;
        if (sig == 0) return 0.0;
        sig = sig.abs();
        final awayFromZero = args.length > 2 && _numArg(args, 2) != 0;
        final up = name == 'CEILING.MATH';
        final q = x / sig;
        double r;
        if (x < 0 && awayFromZero) {
          r = up ? q.truncateToDouble() : q.floorToDouble();
          if (up && r != q) r = q.truncateToDouble();
        } else {
          r = up ? q.ceilToDouble() : q.floorToDouble();
        }
        return r * sig;
      case 'COMBIN':
      case 'PERMUT':
        final n = _numArg(args, 0).truncate();
        final k = _numArg(args, 1).truncate();
        if (n < 0 || k < 0 || k > n) return const FormulaError('#SAYI!');
        var p = 1.0;
        for (var i = 0; i < k; i++) {
          p *= n - i;
        }
        if (name == 'PERMUT') return p;
        var f = 1.0;
        for (var i = 2; i <= k; i++) {
          f *= i;
        }
        return (p / f).roundToDouble();
      case 'SINH':
        final x = _numArg(args, 0);
        return (math.exp(x) - math.exp(-x)) / 2;
      case 'COSH':
        final x = _numArg(args, 0);
        return (math.exp(x) + math.exp(-x)) / 2;
      case 'TANH':
        final x = _numArg(args, 0);
        final e2 = math.exp(2 * x);
        return (e2 - 1) / (e2 + 1);

      // ── istatistik (ek) ────────────────────────────────────────────────
      case 'AVERAGEA':
      case 'MAXA':
      case 'MINA':
        final n = _numbersA(args);
        if (n.isEmpty) {
          return name == 'AVERAGEA'
              ? const FormulaError('#SAYI/0!')
              : 0.0;
        }
        return switch (name) {
          'AVERAGEA' => n.reduce((a, b) => a + b) / n.length,
          'MAXA' => n.reduce(math.max),
          _ => n.reduce(math.min),
        };
      case 'GEOMEAN':
        final n = _numbers(args);
        if (n.isEmpty || n.any((v) => v <= 0)) {
          return const FormulaError('#SAYI!');
        }
        var logSum = 0.0;
        for (final v in n) {
          logSum += math.log(v);
        }
        return math.exp(logSum / n.length);
      case 'HARMEAN':
        final n = _numbers(args);
        if (n.isEmpty || n.any((v) => v <= 0)) {
          return const FormulaError('#SAYI!');
        }
        var inv = 0.0;
        for (final v in n) {
          inv += 1 / v;
        }
        return n.length / inv;
      case 'AVEDEV':
      case 'DEVSQ':
        final n = _numbers(args);
        if (n.isEmpty) return const FormulaError('#SAYI/0!');
        final mean = n.reduce((a, b) => a + b) / n.length;
        if (name == 'DEVSQ') {
          return n.fold<double>(0, (a, b) => a + (b - mean) * (b - mean));
        }
        return n.fold<double>(0, (a, b) => a + (b - mean).abs()) / n.length;
      case 'PERCENTILE':
      case 'QUARTILE':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final n = _numbers([args.first])..sort();
        if (n.isEmpty) return const FormulaError('#SAYI!');
        final k = name == 'QUARTILE'
            ? _numArg(args, 1).round() / 4.0
            : _numArg(args, 1);
        if (k < 0 || k > 1) return const FormulaError('#SAYI!');
        return _Parser._percentile(n, k);
      case 'PERCENTRANK':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final n = _numbers([args.first])..sort();
        if (n.isEmpty) return const FormulaError('#SAYI!');
        final x = _numArg(args, 1);
        if (x < n.first || x > n.last) return const FormulaError('#SAYI!');
        var below = 0;
        for (final v in n) {
          if (v < x) below++;
        }
        var equal = 0;
        for (final v in n) {
          if (v == x) equal++;
        }
        final rank = equal > 0
            ? below / (n.length - 1)
            : _Parser._interpolatedRank(n, x);
        final digits = args.length > 2 ? _numArg(args, 2, 3).round() : 3;
        return _Parser._round(rank, digits);

      // ── metin (ek) ─────────────────────────────────────────────────────
      case 'TEXTBEFORE':
      case 'TEXTAFTER':
        final text = _strArg(args, 0);
        final delim = _strArg(args, 1);
        if (delim.isEmpty) return text;
        final instance = args.length > 2 ? _numArg(args, 2, 1).round() : 1;
        final idx = _Parser._nthIndex(text, delim, instance);
        if (idx < 0) return const FormulaError('#YOK');
        return name == 'TEXTBEFORE'
            ? text.substring(0, idx)
            : text.substring(idx + delim.length);
      case 'NUMBERVALUE':
        final text = _strArg(args, 0);
        final dec = args.length > 1 ? _strArg(args, 1) : ',';
        final group = args.length > 2 ? _strArg(args, 2) : '.';
        var t = text.trim();
        if (group.isNotEmpty) t = t.replaceAll(group, '');
        if (dec.isNotEmpty) t = t.replaceAll(dec, '.');
        // Yüzde işareti sonda (Excel) ya da başta (Türkçe yazım: %15).
        var percents = 0;
        final trailing = RegExp(r'%+$').firstMatch(t);
        if (trailing != null) {
          percents += trailing.group(0)!.length;
          t = t.substring(0, trailing.start);
        }
        final leading = RegExp(r'^%+').firstMatch(t);
        if (leading != null) {
          percents += leading.group(0)!.length;
          t = t.substring(leading.end);
        }
        final d = double.tryParse(t.trim());
        if (d == null) return const FormulaError('#DEĞER!');
        return percents == 0 ? d : d / math.pow(100, percents);
      case 'FIXED':
        final v = _numArg(args, 0);
        final digits = args.length > 1 ? _numArg(args, 1, 2).round() : 2;
        final noCommas = args.length > 2 && _numArg(args, 2) != 0;
        final code = noCommas
            ? (digits > 0 ? '0.${'0' * digits}' : '0')
            : (digits > 0 ? '#,##0.${'0' * digits}' : '#,##0');
        return ExcelNumberFormat.parse(code).format(v).text;
      case 'UNICHAR':
        final code = _numArg(args, 0).round();
        if (code < 1) return const FormulaError('#DEĞER!');
        return String.fromCharCode(code);
      case 'UNICODE':
        final t = _strArg(args, 0);
        if (t.isEmpty) return const FormulaError('#DEĞER!');
        return t.runes.first.toDouble();

      // ── tarih (ek) ─────────────────────────────────────────────────────
      case 'WEEKNUM':
        final dt = excelSerialToDate(_numArg(args, 0));
        final type = args.length > 1 ? _numArg(args, 1, 1).round() : 1;
        final startsMonday = type == 2 || type == 11 || type == 21;
        final jan1 = DateTime.utc(dt.year, 1, 1);
        // Yılın ilk gününün hafta içindeki sırası (0 = haftanın ilk günü).
        final offset = startsMonday
            ? (jan1.weekday - 1)
            : (jan1.weekday % 7);
        final dayOfYear = dt.difference(jan1).inDays;
        return ((dayOfYear + offset) / 7).floor() + 1.0;
      case 'ISOWEEKNUM':
        final dt = excelSerialToDate(_numArg(args, 0));
        final thursday = dt.add(Duration(days: 4 - dt.weekday));
        final jan1 = DateTime.utc(thursday.year, 1, 1);
        return (thursday.difference(jan1).inDays / 7).floor() + 1.0;
      case 'NETWORKDAYS':
        final a = excelSerialToDate(_numArg(args, 0));
        final b = excelSerialToDate(_numArg(args, 1));
        final holidays = _holidaySet(args, 2);
        final forward = !b.isBefore(a);
        final from = forward ? a : b;
        final to = forward ? b : a;
        var count = 0;
        for (var d = from;
            !d.isAfter(to);
            d = d.add(const Duration(days: 1))) {
          if (d.weekday == DateTime.saturday ||
              d.weekday == DateTime.sunday) {
            continue;
          }
          if (holidays.contains(_Parser._dayKey(d))) continue;
          count++;
        }
        return (forward ? count : -count).toDouble();
      case 'WORKDAY':
        var d = excelSerialToDate(_numArg(args, 0));
        var left = _numArg(args, 1).round();
        final holidays = _holidaySet(args, 2);
        final step = left >= 0 ? 1 : -1;
        left = left.abs();
        while (left > 0) {
          d = d.add(Duration(days: step));
          if (d.weekday == DateTime.saturday ||
              d.weekday == DateTime.sunday) {
            continue;
          }
          if (holidays.contains(_Parser._dayKey(d))) continue;
          left--;
        }
        return dateToExcelSerial(d);
      case 'DATEVALUE':
        final serial = _Parser._parseDateText(_strArg(args, 0));
        return serial ?? const FormulaError('#DEĞER!');
      case 'TIMEVALUE':
        final frac = _Parser._parseTimeText(_strArg(args, 0));
        return frac ?? const FormulaError('#DEĞER!');
      case 'YEARFRAC':
        return _Parser._yearFrac(
          excelSerialToDate(_numArg(args, 0)),
          excelSerialToDate(_numArg(args, 1)),
          args.length > 2 ? _numArg(args, 2).round() : 0,
        );

      // ── finans (kredi/taksit tabloları) ────────────────────────────────
      case 'PMT':
      case 'PV':
      case 'FV':
      case 'NPER':
      case 'RATE':
      case 'IPMT':
      case 'PPMT':
        return _financial(name, args);
      case 'NPV':
        final rate = _numArg(args, 0);
        final flows = _numbers(args.sublist(1));
        var npv = 0.0;
        for (var i = 0; i < flows.length; i++) {
          npv += flows[i] / math.pow(1 + rate, i + 1);
        }
        return npv;
      case 'IRR':
        final flows = _numbers([args.first]);
        if (flows.length < 2) return const FormulaError('#SAYI!');
        return _Parser._irr(flows, args.length > 1 ? _numArg(args, 1, 0.1) : 0.1);
      case 'SLN':
        final life = _numArg(args, 2);
        if (life == 0) return const FormulaError('#SAYI/0!');
        return (_numArg(args, 0) - _numArg(args, 1)) / life;

      default:
        return const FormulaError('#AD?'); // bilinmeyen fonksiyon
    }
  }

  Object _safe(Object Function() body) {
    try {
      return body();
    } on _CycleError {
      return const FormulaError('#DÖNGÜ');
    } on FormulaError catch (e) {
      return e;
    } catch (_) {
      return const FormulaError('#DEĞER!');
    }
  }
}
