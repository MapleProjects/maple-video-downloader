# Maple Video Downloader — Registro de cambios

## v1.1.4

### Novedades y mejoras
• Corregido un error que interrumpía la actualización al reemplazar el ejecutable del actualizador.
• La instalación queda completa aunque el actualizador esté en uso durante el proceso.
• La aplicación se vuelve a abrir al terminar, incluso si la actualización no se completa.

## v1.1.3

### Novedades y mejoras
• Actualizador independiente con ventana flotante y barra de progreso durante el reemplazo de archivos.
• El actualizador espera el cierre de la aplicación, reemplaza los archivos y la vuelve a abrir por su cuenta.
• Corregido el cierre inesperado que impedía aplicar la actualización en Windows.
• La ventana de actualización se cierra automáticamente al completar el proceso.
• Los fallos del actualizador quedan registrados en el archivo de registro local.

## v1.1.1

### Novedades y mejoras
• Actualizaciones automáticas desde GitHub con verificación de integridad del paquete antes de instalar.
• Instalador para Windows que no requiere permisos de administrador y permite actualizar sin interrupciones.
• Paquete portable con yt-dlp y ffmpeg incluidos, sin dependencias externas.
• Detección de calidades corregida en Windows cuando las herramientas viajan junto a la aplicación.
• Los errores de análisis muestran el detalle técnico completo con un botón para copiarlo.

## v1.1.0

### Novedades y mejoras
• Comprobación de nuevas versiones al iniciar y desde la pantalla de ajustes.
• Descarga del paquete de actualización con progreso visible y verificación SHA-256.
• Aplicación de la actualización mediante un proceso auxiliar que reemplaza los archivos y relanza la aplicación.
• Aviso de versión disponible con acceso directo a las notas y opción de omitirla.
• Detección de instalaciones gestionadas por el gestor de paquetes para no interferir con sus actualizaciones.

## v1.0.0

### Novedades y mejoras
• Captura automática de cookies de YouTube mediante navegador embebido, sin exportaciones manuales.
• Descargas simultáneas con control de hilos y progreso en tiempo real.
• Selección dinámica de resolución según los formatos reales de cada video.
• Compatibilidad con YouTube, TikTok, X, Instagram, Facebook, Twitch, Reddit y más de mil sitios.
• Extracción de audio en MP3 y M4A.
