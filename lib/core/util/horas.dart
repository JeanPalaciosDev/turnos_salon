/// Convierte 'HH:mm' a minutos desde medianoche.
int minutosDeHora(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// Convierte minutos desde medianoche a 'HH:mm' (acotado a [0, 24h)).
String horaDeMinutos(int m) {
  final mm = ((m % 1440) + 1440) % 1440;
  return '${(mm ~/ 60).toString().padLeft(2, '0')}:'
      '${(mm % 60).toString().padLeft(2, '0')}';
}

/// 'yyyy-MM-dd' a partir de un [DateTime] (en hora local).
String fmtFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
];

/// Etiqueta legible, ej. 'Jue 19 jun'.
String fmtFechaLegible(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';

/// Parsea 'yyyy-MM-dd' a [DateTime] (medianoche local).
DateTime parseFecha(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Lunes (00:00 local) de la semana que contiene [d].
DateTime lunesDeSemana(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

/// Los 7 días (lunes→domingo) de la semana que contiene [d].
List<DateTime> semanaDe(DateTime d) {
  final l = lunesDeSemana(d);
  return List.generate(7, (i) => l.add(Duration(days: i)));
}

/// Rango legible de la semana que contiene [d], ej. '16–22 jun' o
/// '30 jun – 6 jul' cuando cruza de mes.
String fmtRangoSemana(DateTime d) {
  final semana = semanaDe(d);
  final l = semana.first;
  final dom = semana.last;
  if (l.month == dom.month) {
    return '${l.day}–${dom.day} ${_meses[dom.month - 1]}';
  }
  return '${l.day} ${_meses[l.month - 1]} – ${dom.day} ${_meses[dom.month - 1]}';
}

/// Etiqueta corta de un día para encabezados de columna/fila, ej. 'Lun 16'.
String fmtDiaCorto(DateTime d) => '${_dias[d.weekday - 1]} ${d.day}';
