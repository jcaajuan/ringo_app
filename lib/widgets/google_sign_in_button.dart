import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';
import '../theme/app_theme.dart';

/// Botón de Google Sign-In con el texto y los colores de la guía de marca.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _cargando = false;

  Future<void> _pulsar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final perfil = await GoogleAuthService.instance.entrar();
      if (!mounted || perfil == null) return;
      if (perfil.avisoServidor != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(perfil.avisoServidor!)),
        );
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on GoogleAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.redAccent),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo continuar con Google. $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = oscuro ? const Color(0xFF131314) : Colors.white;
    final borde = oscuro ? const Color(0xFF8E918F) : const Color(0xFF747775);
    final texto = oscuro ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _cargando ? null : _pulsar,
        style: OutlinedButton.styleFrom(
          backgroundColor: fondo,
          foregroundColor: texto,
          disabledBackgroundColor: fondo,
          side: BorderSide(color: borde),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: _cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF4285F4)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _LogoGoogle(),
                  const SizedBox(width: 12),
                  Text(
                    'Continuar con Google',
                    style: TextStyle(
                      color: texto,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SeparadorAuth extends StatelessWidget {
  const SeparadorAuth({super.key, this.texto = 'o'});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.borderGray)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            texto,
            style: const TextStyle(color: AppColors.mediumGray, fontWeight: FontWeight.w700),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.borderGray)),
      ],
    );
  }
}

class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(18, 18),
      painter: _LogoGooglePainter(),
    );
  }
}

/// Letra G de cuatro colores, dibujada para no depender de un asset.
class _LogoGooglePainter extends CustomPainter {
  const _LogoGooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width * 0.2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.butt;
    final rect = Rect.fromLTWH(
      grosor / 2,
      grosor / 2,
      size.width - grosor,
      size.height - grosor,
    );

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.95, math.pi * 0.7, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.55, math.pi * 0.4, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.15, math.pi * 0.4, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.25, math.pi * 0.4, false, paint);

    paint.style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.48, size.height * 0.4, size.width * 0.46, grosor),
        const Radius.circular(1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
