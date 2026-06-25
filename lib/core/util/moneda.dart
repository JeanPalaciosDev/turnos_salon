/// Formateo de montos para mostrar en la UI.
///
/// Salida estilo `$ 1.234,50` (separador de miles `.`, decimales con `,`),
/// omitiendo los decimales cuando el monto es entero. Es solo presentación:
/// internamente los montos se guardan como `num` sin formato.
String fmtMoneda(num monto) {
  final negativo = monto < 0;
  final abs = monto.abs();
  final entero = abs.truncate();
  final decimales = abs - entero;

  final digitos = entero.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buf.write('.');
    buf.write(digitos[i]);
  }

  var texto = buf.toString();
  if (decimales > 0) {
    final cent = (decimales * 100).round().toString().padLeft(2, '0');
    texto = '$texto,$cent';
  }
  return '${negativo ? '-' : ''}\$ $texto';
}

/// Representación plana de un monto para precargar un campo editable: sin
/// símbolo ni separador de miles, con coma decimal solo si hace falta
/// (`1234` o `1234,5`). Compatible con [parseMonto].
String fmtMontoEditable(num monto) {
  if (monto == monto.truncate()) return monto.truncate().toString();
  return monto.toString().replaceAll('.', ',');
}

/// Parsea un texto del usuario (admite `.`/`,` como separadores) a `num`.
/// Devuelve `0` si no hay un número válido.
num parseMonto(String texto) {
  final limpio = texto.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (limpio.isEmpty) return 0;
  // Normaliza: si hay coma, se asume decimal; los puntos son miles.
  final normal = limpio.contains(',')
      ? limpio.replaceAll('.', '').replaceAll(',', '.')
      : limpio;
  return num.tryParse(normal) ?? 0;
}
