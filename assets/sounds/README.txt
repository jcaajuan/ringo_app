Sonidos de ringo_app (formato .mp3, nombres exactos, en minuscula)

Copia ESTOS archivos en DOS carpetas con el mismo nombre:
  1) ringo_app\assets\sounds\                         (audioplayers, app en primer plano)
  2) ringo_app\android\app\src\main\res\raw\          (canales de notificacion, app en segundo plano)

  ringo_conductor_asignado.mp3   Conductor asignado / solicitud aceptada
  ringo_conductor_llego.mp3      El conductor llego
  ringo_mensaje.mp3              Mensaje nuevo en el chat
  ringo_viaje_finalizado.mp3     Viaje finalizado
  ringo_viaje_cancelado.mp3      Viaje cancelado

Si falta algun archivo la app no falla: simplemente no suena ese evento.
Importante: el sonido de un canal de Android se fija al crearlo. Si cambias un
audio de res\raw despues de instalar la app, desinstalala (o borra sus datos)
para que Android vuelva a crear los canales con el sonido nuevo.
