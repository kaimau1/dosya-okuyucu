# DEVIR — B10 Excel 2.0, dilim 1 (bulut)
- Dal: faz-oto-B10-excel2 (origin/main 777b5a00'dan).
- Yapılan: m.2 formül kapsamı — `lib/services/formula/arrays.dart` (TEXTSPLIT, VSTACK/HSTACK, TAKE/DROP,
  CHOOSECOLS/CHOOSEROWS, XMATCH, LAMBDA/MAP/REDUCE/SCAN/BYROW/BYCOL/MAKEARRAY, NETWORKDAYS.INTL/WORKDAY.INTL);
  dizi sabiti `{1,2;3,4}` gerçek dizi (parser.dart `_parseArrayLiteral`); `_xlpm.` öneki okunur (locale.dart).
- Sıradaki: `test/formula_array_text_test.dart` (MS belge örnekleri + kapsam bekçisi), sonra m.6 sadakat bekçisi.
- Doğrulama: CI (yerel Flutter yok).
