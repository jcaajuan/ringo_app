import 'package:flutter/material.dart';

import 'terms_and_conditions_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/acceso_biometrico.dart';

/// Ajustes de la cuenta en este teléfono.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Seguridad',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.blackPure,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            const AccesoBiometrico(),
            const SizedBox(height: 28),
            const Text(
              'Soporte y legal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.blackPure,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const Icon(Icons.gavel_outlined, color: AppColors.blackPure),
                title: const Text(
                  'Términos y Condiciones',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Última actualización: $kTermsLastUpdated'),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.blackPure),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsAndConditionsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
