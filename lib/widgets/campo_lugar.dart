import 'dart:async';

import 'package:flutter/material.dart';

import '../services/places_service.dart';
import '../theme/app_theme.dart';

const puntoSeleccionadoEnMapa = 'Punto seleccionado en el mapa';
const tuUbicacionActual = 'Tu ubicación actual';

class CampoLugar extends StatefulWidget {
  const CampoLugar({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.activo,
    required this.onEnfocado,
    required this.onElegido,
    required this.onVacio,
    this.onUbicacionActual,
    this.cargandoUbicacion = false,
  });

  final String etiqueta;
  final Widget icono;
  final bool activo;
  final VoidCallback onEnfocado;
  final ValueChanged<LugarElegido> onElegido;
  final VoidCallback onVacio;

  /// Mira GPS del campo de origen. Si es null, el campo no muestra el ícono.
  final VoidCallback? onUbicacionActual;
  final bool cargandoUbicacion;

  @override
  State<CampoLugar> createState() => CampoLugarState();
}

class CampoLugarState extends State<CampoLugar> {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  Timer? _espera;
  int _busqueda = 0;
  List<SugerenciaLugar> _sugerencias = const [];
  String? _error;
  bool _buscando = false;
  bool _desdeCodigo = false;
  bool _puntoEnMapa = false;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (_foco.hasFocus) {
        if (_texto.text.trim() == puntoSeleccionadoEnMapa) {
          _desdeCodigo = true;
          _texto.clear();
          _desdeCodigo = false;
          _puntoEnMapa = true;
          if (mounted) setState(() {});
        }
        widget.onEnfocado();
      }
      if (!_foco.hasFocus && mounted) {
        setState(() {
          _sugerencias = const [];
          _error = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void mostrar(String direccion) {
    _espera?.cancel();
    final esPunto = direccion.trim() == puntoSeleccionadoEnMapa;
    _desdeCodigo = true;
    _texto.value = TextEditingValue(
      text: esPunto ? '' : direccion,
      selection: TextSelection.collapsed(offset: esPunto ? 0 : direccion.length),
    );
    _desdeCodigo = false;
    _puntoEnMapa = esPunto;
    if (!mounted) return;
    setState(() {
      _sugerencias = const [];
      _error = null;
      _buscando = false;
    });
  }

  void _alEscribir(String valor) {
    if (_desdeCodigo) return;
    if (_puntoEnMapa && valor.trim().isNotEmpty) _puntoEnMapa = false;
    _espera?.cancel();
    final consulta = valor.trim();
    if (consulta.isEmpty) {
      setState(() {
        _sugerencias = const [];
        _error = null;
        _buscando = false;
      });
      widget.onVacio();
      return;
    }
    if (consulta.length < 2) {
      setState(() {
        _sugerencias = const [];
        _error = null;
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _espera = Timer(const Duration(milliseconds: 1000), () => _buscar(consulta));
  }

  Future<void> _buscar(String consulta) async {
    final id = ++_busqueda;
    final resultado = await PlacesService.instance.autocompletar(consulta);
    if (!mounted || id != _busqueda || _texto.text.trim() != consulta) return;
    setState(() {
      _buscando = false;
      _sugerencias = resultado.lugares;
      _error = resultado.error;
    });
  }

  Widget? _sufijo() {
    final gps = widget.onUbicacionActual != null;
    if (!_buscando && !gps) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_buscando)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (gps)
          IconButton(
            tooltip: tuUbicacionActual,
            onPressed: widget.cargandoUbicacion ? null : widget.onUbicacionActual,
            icon: widget.cargandoUbicacion
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: AppColors.blackPure),
          ),
      ],
    );
  }

  void _elegir(SugerenciaLugar sugerencia) {
    _espera?.cancel();
    _busqueda++;
    mostrar(sugerencia.direccion);
    _foco.unfocus();
    widget.onElegido(sugerencia.elegido);
  }

  @override
  Widget build(BuildContext context) {
    final abierto = _foco.hasFocus && (_sugerencias.isNotEmpty || _error != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _texto,
          focusNode: _foco,
          onTap: widget.onEnfocado,
          onChanged: _alEscribir,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          decoration: InputDecoration(
            hintText: _puntoEnMapa ? puntoSeleccionadoEnMapa : widget.etiqueta,
            hintStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _puntoEnMapa ? AppColors.mediumGray : null,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: widget.icono,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 36),
            suffixIcon: _sufijo(),
            suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            filled: true,
            fillColor: widget.activo ? const Color(0xFFFFF8DC) : AppColors.lightBackground,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: widget.activo ? AppColors.primaryYellow : Colors.transparent,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primaryYellow, width: 1.5),
            ),
          ),
        ),
        if (abierto)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderGray),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_error!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _sugerencias.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: AppColors.borderGray.withValues(alpha: 0.7)),
                    itemBuilder: (context, index) {
                      final sugerencia = _sugerencias[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, color: AppColors.blackPure),
                        title: Text(
                          sugerencia.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: sugerencia.detalle.isEmpty
                            ? null
                            : Text(
                                sugerencia.detalle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onTap: () => _elegir(sugerencia),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
