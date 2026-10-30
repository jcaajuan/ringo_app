import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/local_notification_service.dart';
import '../theme/app_theme.dart';

/// Chat del viaje, mostrado como bottom sheet flotante.
///
/// Se abre con [ChatSheet.mostrar]. El campo sube con el teclado y queda
/// por encima de los botones de navegación de Android.
class ChatSheet extends StatefulWidget {
  const ChatSheet({super.key, required this.viajeId, required this.titulo});

  final String viajeId;
  final String titulo;

  static Future<void> mostrar(
    BuildContext context, {
    required String viajeId,
    required String titulo,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChatSheet(viajeId: viajeId, titulo: titulo),
    );
  }

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final _mensaje = TextEditingController();
  final _foco = FocusNode();
  final _enviando = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Con el chat abierto no se notifica ni suena por mensajes de este viaje.
    ChatActivo.abrir(widget.viajeId);
  }

  @override
  void dispose() {
    ChatActivo.cerrar(widget.viajeId);
    _mensaje.dispose();
    _foco.dispose();
    _enviando.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensaje.text.trim();
    if (texto.isEmpty || _enviando.value) return;
    _mensaje.clear();
    _enviando.value = true;
    try {
      await ChatService.instance.enviar(widget.viajeId, texto);
    } catch (_) {
      if (!mounted) return;
      _mensaje.text = texto;
      _mensaje.selection = TextSelection.collapsed(offset: texto.length);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el mensaje.')),
      );
    } finally {
      _enviando.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vista = View.of(context);
    final ratio = vista.devicePixelRatio;
    final teclado = vista.viewInsets.bottom / ratio;
    final sistema = vista.viewPadding.bottom / ratio;
    final altoPantalla = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAlto = constraints.maxHeight;
        final padreYaSubio = maxAlto.isFinite && teclado > 0 && maxAlto <= altoPantalla - teclado + 24;
        final yaReservado = MediaQuery.paddingOf(context).bottom;
        final huecoSistema = teclado > 0 ? 0.0 : math.max(0.0, sistema - yaReservado);
        final inferior = padreYaSubio
            ? huecoSistema
            : (teclado > 0 ? teclado + 8 : huecoSistema + 16);
        final disponible = (maxAlto.isFinite ? maxAlto : altoPantalla) - inferior;
        final alto = math.min(altoPantalla * 0.72, math.max(0.0, disponible));

        return Padding(
          padding: EdgeInsets.only(bottom: inferior),
          child: SizedBox(
            height: alto,
            child: Column(
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(child: _ListaMensajes(viajeId: widget.viajeId)),
          _Composer(
            controller: _mensaje,
            focusNode: _foco,
            enviando: _enviando,
            onEnviar: _enviar,
          ),
        ],
            ),
          ),
        );
      },
    );
  }
}

class _ListaMensajes extends StatelessWidget {
  const _ListaMensajes({required this.viajeId});

  final String viajeId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MensajeViaje>>(
      stream: ChatService.instance.observar(viajeId),
      builder: (context, snapshot) {
        final mensajes = snapshot.data ?? const <MensajeViaje>[];
        if (mensajes.isEmpty) {
          return const Center(
            child: Text(
              'Chat con el conductor',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          );
        }
        return ListView.builder(
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: mensajes.length,
          itemBuilder: (context, index) {
            final item = mensajes[mensajes.length - 1 - index];
            final propio = item.esMio;
            return Align(
              key: ValueKey(item.id),
              alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: propio ? AppColors.primaryYellow : const Color(0xFFECECEC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.texto,
                  style: const TextStyle(
                    color: AppColors.blackPure,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enviando,
    required this.onEnviar,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<bool> enviando;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.send,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onEnviar(),
              decoration: const InputDecoration(hintText: 'Mensaje'),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: enviando,
            builder: (context, ocupado, _) => IconButton(
              onPressed: ocupado ? null : onEnviar,
              icon: const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
