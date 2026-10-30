/// Dirección de ringo-backend.
/// Sin `--dart-define`, la app usa el servidor publicado en Render.
/// Para un backend local: `--dart-define=API_BASE_URL=http://10.0.2.2:3000`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://ringo-backend-y88c.onrender.com',
);
