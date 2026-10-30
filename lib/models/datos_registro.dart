/// Datos personales que se piden al crear la cuenta y se guardan en `usuarios`.
class DatosRegistro {
  const DatosRegistro({
    required this.fechaNacimiento,
    required this.direccion,
    required this.cedulaIdentidad,
    required this.esMayorDeEdad,
  });

  final DateTime fechaNacimiento;
  final String direccion;
  final String cedulaIdentidad;
  final bool esMayorDeEdad;

  static final _cedula = RegExp(r'^\d{6,9}$');

  static const meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const mesesCortos = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static String normalizarCedula(String valor) =>
      valor.replaceAll(RegExp(r'\D'), '');

  /// Devuelve la fecha solo si día, mes y año forman un día real del calendario.
  static DateTime? interpretarFecha({int? dia, int? mes, int? anio}) {
    if (dia == null || mes == null || anio == null) return null;
    final fecha = DateTime(anio, mes, dia);
    if (fecha.year != anio || fecha.month != mes || fecha.day != dia) {
      return null;
    }
    return fecha;
  }

  static bool tieneMayoriaDeEdad(DateTime nacimiento, [DateTime? hoy]) {
    final referencia = hoy ?? DateTime.now();
    final mayorDesde = DateTime(
      referencia.year - 18,
      referencia.month,
      referencia.day,
    );
    final fecha = DateTime(nacimiento.year, nacimiento.month, nacimiento.day);
    return !fecha.isAfter(mayorDesde);
  }

  static String? validarFecha({int? dia, int? mes, int? anio, DateTime? hoy}) {
    if (dia == null || mes == null || anio == null) {
      return 'Selecciona el día, el mes y el año de nacimiento';
    }
    final fecha = interpretarFecha(dia: dia, mes: mes, anio: anio);
    if (fecha == null) {
      return 'La fecha de nacimiento no es válida';
    }
    final referencia = hoy ?? DateTime.now();
    final hoySinHora = DateTime(referencia.year, referencia.month, referencia.day);
    if (fecha.isAfter(hoySinHora)) {
      return 'La fecha de nacimiento no puede ser futura';
    }
    if (!tieneMayoriaDeEdad(fecha, referencia)) {
      return 'Debes tener al menos 18 años para registrarte';
    }
    return null;
  }

  static String? validarDireccion(String? valor) {
    final direccion = valor?.trim() ?? '';
    if (direccion.isEmpty) return 'Por favor ingresa tu dirección';
    if (direccion.length < 5) return 'La dirección es demasiado corta';
    if (direccion.length > 120) {
      return 'La dirección no puede superar 120 caracteres';
    }
    return null;
  }

  static String? validarCedula(String? valor) {
    final cedula = normalizarCedula(valor ?? '');
    if (cedula.isEmpty) return 'Por favor ingresa tu cédula de identidad';
    if (!_cedula.hasMatch(cedula)) {
      return 'Ingresa una cédula de 6 a 9 dígitos';
    }
    return null;
  }
}
