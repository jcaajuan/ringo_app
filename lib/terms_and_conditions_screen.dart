import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Fecha publicada en el documento legal vigente.
const String kTermsLastUpdated = '21 de octubre de 2026';

class _TermsClause {
  const _TermsClause(this.text, {this.bullets = const []});

  final String text;
  final List<String> bullets;
}

class _TermsSection {
  const _TermsSection(this.title, this.clauses);

  final String title;
  final List<_TermsClause> clauses;
}

const List<String> _introduccion = [
  'Bienvenido a Ringo App. Por favor, lee atentamente los presentes Términos y Condiciones de Uso (en adelante, los "Términos") antes de utilizar nuestra plataforma y servicios móviles.',
  'Al descargar, registrarte, acceder o utilizar la aplicación móvil Ringo App (en adelante, la "App"), aceptas expresamente quedar vinculado por el presente acuerdo. Si no estás de acuerdo con alguna de las disposiciones aquí establecidas, no deberás utilizar la App.',
];

const List<_TermsSection> _secciones = [
  _TermsSection(
    '1. Naturaleza del Servicio y Rol de Ringo',
    [
      _TermsClause(
        '1.1. Ringo App es una plataforma tecnológica que actúa exclusivamente como un servicio de intermediación digital entre usuarios que solicitan servicios de movilidad/transporte de personas o envío de paquetería/delivery (en adelante, los "Pasajeros" o "Usuarios") y proveedores de transporte independientes (en adelante, los "Conductores").',
      ),
      _TermsClause(
        '1.2. Ringo App NO es una empresa de transporte terrestre, ni presta servicios de taxi, mototaxi o encomiendas directamente, ni actúa como patrono, empleador o representante legal de los Conductores.',
      ),
      _TermsClause(
        '1.3. Los Conductores operan de manera independiente y prestan sus servicios bajo su propia cuenta, riesgo y responsabilidad.',
      ),
    ],
  ),
  _TermsSection(
    '2. Ámbito de Operación Territorial',
    [
      _TermsClause(
        '2.1. En su etapa inicial, la App está destinada a operar en la jurisdicción de las ciudades de El Tigre (Municipio Simón Rodríguez) y Guanipa / El Tigrito (Municipio Pedro María Freites), Estado Anzoátegui, República Bolivariana de Venezuela.',
      ),
      _TermsClause(
        '2.2. Cualquier uso de la App fuera de este ámbito territorial delimitado podrá estar sujeto a limitaciones operativas o restricción del servicio.',
      ),
    ],
  ),
  _TermsSection(
    '3. Registro de Cuenta y Requisitos de Usuario',
    [
      _TermsClause(
        '3.1. Edad Mínima: Para registrarse como Pasajero, el usuario debe ser mayor de 18 años o contar con la debida representación legal. Para registrarse como Conductor, es indispensable ser mayor de edad y contar con la documentación legal y vehicular vigente exigida por las leyes venezolanas.',
      ),
      _TermsClause(
        '3.2. Veracidad de la Información: El usuario se compromete a proporcionar información veraz, exacta y actualizada durante el proceso de registro.',
      ),
      _TermsClause(
        '3.3. Uso Personal y Seguridad: La cuenta es personal e intransferible. El usuario es el único responsable de mantener la confidencialidad de sus credenciales de acceso.',
      ),
    ],
  ),
  _TermsSection(
    '4. Modalidades de Servicio y Clasificación de Vehículos',
    [
      _TermsClause(
        '4.1. La App permite la conexión según el tipo de vehículo registrado por el Conductor:',
        bullets: [
          'Vehículos tipo Carro: Habilitados para la prestación de servicios de Taxi/Traslado de personas y Delivery.',
          'Vehículos tipo Moto: Habilitados para la prestación de servicios de Moto Taxi y Delivery.',
        ],
      ),
      _TermsClause(
        '4.2. Ringo App se reserva el derecho de validar, verificar y evaluar el cumplimiento de los estándares exigidos para cada tipo de vehículo antes de habilitar su estado operativo en la plataforma.',
      ),
    ],
  ),
  _TermsSection(
    '5. Criterios de Disponibilidad y Estado Operativo',
    [
      _TermsClause(
        '5.1. Para que un Conductor pueda recibir solicitudes de viaje o delivery en la plataforma, la App evaluará su estado conforme a los parámetros técnicos del sistema. Se considerará que un Conductor está en línea y disponible cuando cumpla con los criterios operativos establecidos (por ejemplo: disponible == true, estadoOperativo == "conectado", o conectado == true).',
      ),
      _TermsClause(
        '5.2. Ringo App no garantiza un número mínimo de solicitudes, asignaciones ni ingresos a los Conductores en línea.',
      ),
    ],
  ),
  _TermsSection(
    '6. Servicios de Geolocalización y Ubicación',
    [
      _TermsClause(
        '6.1. Uso de la Ubicación en la App: Para el correcto funcionamiento de Ringo App, la aplicación requiere recopilar, rastrear y procesar datos de geolocalización en tiempo real del dispositivo móvil del usuario (tanto Pasajeros como Conductores).',
      ),
      _TermsClause(
        '6.2. Ubicación de Pasajeros: Se recopilará la ubicación del Pasajero al interactuar con la App para calcular puntos de origen, sugerir rutas, estimar tiempos de llegada y calcular tarifas aproximadas.',
      ),
      _TermsClause(
        '6.3. Ubicación de Conductores (Segundo Plano / Background): El Conductor acepta y autoriza expresamente a Ringo App a rastrear su ubicación exacta en tiempo real, incluso cuando la aplicación se encuentre ejecutándose en segundo plano o el dispositivo esté bloqueado, mientras su estado figure como en línea o disponible. Esto es indispensable para asignar carreras/solicitudes según cercanía, optimizar rutas y garantizar la seguridad del trayecto.',
      ),
      _TermsClause(
        '6.4. Privacidad y Permisos: El usuario puede activar o desactivar los permisos de ubicación a través de la configuración de su dispositivo móvil; sin embargo, el usuario reconoce que desactivar la geolocalización impedirá el uso total o parcial de los servicios de Ringo App.',
      ),
      _TermsClause(
        '6.5. Seguridad del Trayecto: Ringo App podrá monitorear el recorrido del vehículo durante un viaje activo por motivos de seguridad, soporte técnico y resolución de disputas sobre rutas o tarifas.',
      ),
    ],
  ),
  _TermsSection(
    '7. Tarifas, Pagos y Métodos de Cobro',
    [
      _TermsClause(
        '7.1. Cálculo de Tarifas: Las tarifas de las carreras o envíos serán calculadas dinámicamente por la App o fijadas según el estimador previo a la confirmación de la solicitud.',
      ),
      _TermsClause(
        '7.2. Métodos de Pago: Se aceptarán los métodos de pago habilitados en la plataforma (pagos en efectivo en moneda local/divisas, o transferencias electrónicas/pago móvil conforme se especifique en la App).',
      ),
      _TermsClause(
        '7.3. Comisión por Intermediación: Ringo App podrá aplicar una comisión por el uso del software sobre las carreras completadas, cuyos montos y condiciones se comunicarán oportunamente a los Conductores.',
      ),
    ],
  ),
  _TermsSection(
    '8. Reglas de Conducta y Uso Aceptable',
    [
      _TermsClause(
        '8.1. Se prohíbe terminantemente el uso de la App para coordinar el traslado de sustancias estupefacientes, bienes ilegales, armas, o para la comisión de cualquier delito previsto en las leyes de la República Bolivariana de Venezuela.',
      ),
      _TermsClause(
        '8.2. Tanto Pasajeros como Conductores se comprometen a mantener un trato respetuoso y libre de acoso, discriminación o agresiones físicas o verbales.',
      ),
      _TermsClause(
        '8.3. Ringo App se reserva el derecho de suspender o inhabilitar permanentemente las cuentas de usuarios que incumplan estas normas de conducta o incurran en fraudes técnicos.',
      ),
    ],
  ),
  _TermsSection(
    '9. Limitación de Responsabilidad',
    [
      _TermsClause(
        '9.1. Ringo App realiza esfuerzos continuos por verificar la idoneidad técnica y legal de la plataforma; sin embargo, no responderá por pérdidas, robos, daños materiales o corporales derivados de los servicios de transporte prestados por los Conductores independientes.',
      ),
      _TermsClause(
        '9.2. Ringo App no garantiza la operatividad ininterrumpida de la App en caso de fallas en redes de telecomunicaciones, electricidad o proveedores de infraestructura de internet externos a nuestro control.',
      ),
    ],
  ),
  _TermsSection(
    '10. Cancelaciones e Inhabilitación de Servicios',
    [
      _TermsClause(
        '10.1. El Pasajero y el Conductor podrán cancelar una solicitud según las condiciones y tiempos de cancelación estipulados dentro de la App.',
      ),
      _TermsClause(
        '10.2. Ringo App se reserva el derecho de cancelar la cuenta o restringir el acceso a la App a cualquier usuario que viole los presentes Términos.',
      ),
    ],
  ),
  _TermsSection(
    '11. Ley Aplicable y Jurisdicción',
    [
      _TermsClause(
        '11.1. Los presentes Términos se regirán e interpretarán de conformidad con las leyes vigentes de la República Bolivariana de Venezuela.',
      ),
      _TermsClause(
        '11.2. Cualquier controversia, reclamo o disputa derivada o relacionada con el uso de Ringo App será sometida a la jurisdicción de los tribunales competentes de la ciudad de El Tigre, Estado Anzoátegui, Venezuela.',
      ),
    ],
  ),
];

/// Documento completo de Términos y Condiciones de Uso de Ringo App.
class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  static const TextStyle _bodyStyle = TextStyle(
    fontSize: 15.5,
    height: 1.55,
    color: AppColors.darkGray,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Términos y Condiciones de Uso',
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.15,
            color: AppColors.blackPure,
            letterSpacing: -0.3,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              'Términos y Condiciones de Uso',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.blackPure,
                letterSpacing: -0.4,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ringo App',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.blackPure,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryYellow.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Última actualización: $kTermsLastUpdated',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blackPure,
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (final parrafo in _introduccion) ...[
              Text(parrafo, style: _bodyStyle),
              const SizedBox(height: 14),
            ],
            for (final seccion in _secciones) ...[
              const SizedBox(height: 10),
              Text(
                seccion.title,
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blackPure,
                  height: 1.3,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              for (final clausula in seccion.clauses) ...[
                Text(clausula.text, style: _bodyStyle),
                if (clausula.bullets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final item in clausula.bullets)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: AppColors.primaryYellow,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item, style: _bodyStyle)),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
