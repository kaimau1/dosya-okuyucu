part of '../formula_engine.dart';

extension _ParserDateFinancePart on _Parser {
  Set<int> _holidaySet(List<Object> args, int index) {
    if (!_given(args, index)) return const {};
    final out = <int>{};
    for (final v in _rangeValues(args[index])) {
      final d = v is num ? v.toDouble() : double.tryParse(v.toString());
      if (d == null) continue;
      out.add(_Parser._dayKey(excelSerialToDate(d)));
    }
    return out;
  }

  /// PMT/PV/FV/NPER/RATE/IPMT/PPMT — Excel'in para akışı işaret kuralıyla
  /// (ödeme negatif, alınan tutar pozitif).
  Object _financial(String name, List<Object> args) {
    switch (name) {
      case 'PMT':
        return _Parser._pmtRaw(_numArg(args, 0), _numArg(args, 1), _numArg(args, 2),
            _given(args, 3) ? _numArg(args, 3) : 0,
            _given(args, 4) ? _numArg(args, 4) : 0);
      case 'FV':
        return _Parser._fvRaw(_numArg(args, 0), _numArg(args, 1), _numArg(args, 2),
            _given(args, 3) ? _numArg(args, 3) : 0,
            _given(args, 4) ? _numArg(args, 4) : 0);
      case 'PV':
        final rate = _numArg(args, 0);
        final n = _numArg(args, 1);
        final pmt = _numArg(args, 2);
        final fv = _given(args, 3) ? _numArg(args, 3) : 0.0;
        final type = _given(args, 4) ? _numArg(args, 4) : 0.0;
        if (rate == 0) return -(fv + pmt * n);
        final p = math.pow(1 + rate, n).toDouble();
        return -(fv + pmt * (1 + rate * type) * (p - 1) / rate) / p;
      case 'NPER':
        final rate = _numArg(args, 0);
        final pmt = _numArg(args, 1);
        final pv = _numArg(args, 2);
        final fv = _given(args, 3) ? _numArg(args, 3) : 0.0;
        final type = _given(args, 4) ? _numArg(args, 4) : 0.0;
        if (rate == 0) {
          if (pmt == 0) return const FormulaError('#SAYI!');
          return -(pv + fv) / pmt;
        }
        final adj = pmt * (1 + rate * type);
        final num = adj - fv * rate;
        final den = pv * rate + adj;
        if (den == 0 || num / den <= 0) return const FormulaError('#SAYI!');
        return math.log(num / den) / math.log(1 + rate);
      case 'RATE':
        return _Parser._rateSolve(
          _numArg(args, 0),
          _numArg(args, 1),
          _numArg(args, 2),
          _given(args, 3) ? _numArg(args, 3) : 0,
          _given(args, 4) ? _numArg(args, 4) : 0,
          _given(args, 5) ? _numArg(args, 5) : 0.1,
        );
      default: // IPMT / PPMT
        final rate = _numArg(args, 0);
        final per = _numArg(args, 1);
        final nper = _numArg(args, 2);
        final pv = _numArg(args, 3);
        final fv = _given(args, 4) ? _numArg(args, 4) : 0.0;
        final type = _given(args, 5) ? _numArg(args, 5) : 0.0;
        if (per < 1 || per > nper) return const FormulaError('#SAYI!');
        final pmt = _Parser._pmtRaw(rate, nper, pv, fv, type);
        double ipmt;
        if (per == 1) {
          ipmt = type == 1 ? 0 : -pv * rate;
        } else if (type == 1) {
          ipmt = (_Parser._fvRaw(rate, per - 2, pmt, pv, 1) - pmt) * rate;
        } else {
          ipmt = _Parser._fvRaw(rate, per - 1, pmt, pv, 0) * rate;
        }
        return name == 'IPMT' ? ipmt : pmt - ipmt;
    }
  }
}
