import 'package:flutter/material.dart';

import '../services/exchange_rate_service.dart';
import '../tarifas.dart';
import '../theme/app_theme.dart';

/// Muestra dólares y bolívares.
///
/// Si [bolivaresFijos] viene del viaje, se usa ese monto y no la tasa del día.
/// [tasaViva] solo aplica a cotizaciones que todavía no se han guardado.
class MontoDual extends StatelessWidget {
  const MontoDual({
    super.key,
    required this.usd,
    this.bolivaresFijos,
    this.tasaViva = true,
    this.style,
    this.alineacion = CrossAxisAlignment.end,
    this.sufijo = '',
  });

  final double usd;
  final double? bolivaresFijos;
  final bool tasaViva;
  final TextStyle? style;
  final CrossAxisAlignment alineacion;
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    if (bolivaresFijos != null || !tasaViva) {
      return _Montos(
        usd: usd,
        bolivares: bolivaresFijos,
        style: style,
        alineacion: alineacion,
        sufijo: sufijo,
      );
    }
    return StreamBuilder<TasaCambio?>(
      stream: ExchangeRateService.instance.observar(),
      builder: (context, snapshot) {
        final tasa = snapshot.hasError ? null : snapshot.data?.vesRate;
        final bolivares = tasa == null ? null : Tarifas.bolivares(usd, tasa);
        return _Montos(
          usd: usd,
          bolivares: bolivares,
          style: style,
          alineacion: alineacion,
          sufijo: sufijo,
        );
      },
    );
  }
}

class _Montos extends StatelessWidget {
  const _Montos({
    required this.usd,
    required this.bolivares,
    required this.style,
    required this.alineacion,
    required this.sufijo,
  });

  final double usd;
  final double? bolivares;
  final TextStyle? style;
  final CrossAxisAlignment alineacion;
  final String sufijo;

  @override
  Widget build(BuildContext context) {
    final principal = style ?? const TextStyle(fontWeight: FontWeight.w800);
    return Column(
      crossAxisAlignment: alineacion,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${Tarifas.formatearUsd(usd)}$sufijo', style: principal),
        if (bolivares != null)
          Text(
            '${Tarifas.formatearVes(bolivares!)}$sufijo',
            style: TextStyle(
              fontSize: (principal.fontSize ?? 14) > 18 ? 13 : 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mediumGray,
            ),
          ),
      ],
    );
  }
}
