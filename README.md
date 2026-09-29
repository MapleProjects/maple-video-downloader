# 🍁 Maple Video Downloader

> Descargador de video y audio multiplataforma de alto rendimiento para **Linux**, **Windows** y **Android** con captura automática y transparente de cookies de sesión mediante navegador embebido.

[![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Linux%20|%20Windows%20|%20Android-blueviolet)](#plataformas-soportadas)
[![Backend Engine](https://img.shields.io/badge/Engine-yt--dlp%20%2B%20ffmpeg-red)](https://github.com/yt-dlp/yt-dlp)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 🌟 Características Principales

### 1. 🍪 Captura de Cookies con Navegador Embebido (Zero-Config)
El problema principal de los descargadores tradicionales es la necesidad de instalar extensiones de terceros en Chrome/Firefox, exportar archivos `.txt` manualmente o dar acceso al perfil completo del navegador.
- **Navegador web integrado minimalista**: Permite iniciar sesión directamente en Google / YouTube dentro de la aplicación.
- **Evasión de bloqueo OAuth (`disallowed_useragent`)**: Implementa un User-Agent limpio de navegador de escritorio que elude la restricción de Google en WebViews.
- **Extracción reactiva**: Al completar el inicio de sesión y detectar la redirección a `youtube.com`, el motor captura los tokens esenciales (`LOGIN_INFO`, `SID`, `HSID`, `SSID`, `__Secure-3PSID`, `SAPISID`).
- **Persistencia en formato estándar Netscape**: Las credenciales se formatean y almacenan de forma permanente en `youtube_cookies.txt` en el almacenamiento privado de la app, inyectándose automáticamente en cada descarga para desbloquear:
  - Videos con restricción de edad (+18).
  - Contenido exclusivo para miembros del canal.
  - Evasión de bloqueos por captcha o límites de tasa de peticiones (bot detection).

### 2. ⚡ Descargas Múltiples Concurrentes en Lote
- **Entrada masiva de URLs**: Permite pegar múltiples enlaces en un solo campo de texto separados por saltos de línea o espacios.
- **Detección inteligente de plataforma**: Identifica automáticamente enlaces de:
  - 🔴 **YouTube** (Videos, Shorts, Playlists).
  - 🎵 **TikTok** (Videos en máxima calidad sin marcas de agua).
  - 🐦 **X / Twitter** (Videos y clips).
  - 📸 **Instagram** (Reels, publicaciones de video).
  - 🔵 **Facebook** (Videos y Watch).
  - 🟣 **Twitch** (Clips y VODs).
  - 🟧 **Reddit** (v.redd.it con audio sincronizado).
  - 📺 **Bilibili** y más de 1000 sitios soportados.
- **Planificador de cola con límite de concurrencia**: Control de hilos paralelos activos (configurable de 1 a 8) para optimizar el ancho de banda y evitar saturación de la conexión.

### 3. 🎬 Perfiles de Calidad y Formato
- **Máxima Calidad (Auto)**: Combina el mejor flujo de video y audio disponible (hasta 4K / 8K a 60 FPS) mediante `ffmpeg`.
- **Resoluciones fijas**: 1080p Full HD, 720p HD y 480p SD.
- **Extracción de solo audio**:
  - MP3 en alta fidelidad (320 kbps VBR/CBR).
  - M4A / AAC directo sin recodificación innecesaria.
- **Telemetría en tiempo real**: Porcentaje exacto, velocidad de transferencia (`MiB/s`), tiempo restante estimado (`ETA`) y tamaño final.

---

## 🏗️ Arquitectura del Sistema

```
maple-video-downloader/
├── lib/
│   ├── core/
│   │   ├── auth/
│   │   │   ├── cookie_model.dart        # Modelo y serializador a estándar Netscape cookies.txt
│   │   │   ├── cookie_service.dart      # Persistencia, validación de sesión y ciclo de vida de cookies
│   │   │   └── user_agent_helper.dart   # Perfiles de User-Agent de alta compatibilidad
│   │   ├── downloader/
│   │   │   ├── download_engine.dart     # Gestor de cola concurrente, procesos yt-dlp y parser stdout
│   │   │   ├── format_preset.dart       # Perfiles de descarga y mapeo de parámetros CLI
│   │   │   └── platform_detector.dart   # Detección y extracción de múltiples URLs
│   │   ├── models/
│   │   │   └── download_task.dart       # Entidad de tarea de descarga con estados reactivos
│   │   └── services/
│   │       └── settings_service.dart    # Configuración de rutas, concurrencia y persistencia
│   ├── ui/
│   │   ├── main_screen.dart             # Shell responsivo (NavigationRail / NavigationBar)
│   │   ├── theme/
│   │   │   └── app_theme.dart           # Paleta oscura moderna Material 3 estilo Maple
│   │   ├── views/
│   │   │   ├── home_view.dart           # Entrada masiva de URLs, resumen de plataformas y cola activa
│   │   │   ├── auth_view.dart           # Navegador embebido con captura automática de cookies
│   │   │   ├── history_view.dart        # Historial de descargas finalizadas con acceso al archivo
│   │   │   └── settings_view.dart       # Ajuste de carpeta de descarga, hilos y visor de sesión
│   │   └── widgets/
│   │       ├── download_card.dart       # Tarjeta de progreso, velocidad, ETA y acciones
│   │       └── session_banner.dart      # Badge de estado de sesión de YouTube
│   └── main.dart                        # Punto de entrada e inicialización de servicios
```

---

## 📱 Plataformas Soportadas

| Plataforma | Soporte | Motor de Descarga | Navegador Embebido |
| :--- | :---: | :--- | :--- |
| **Linux** (Wayland / X11) | ✅ Nativo | `yt-dlp` del sistema / binario local | Sesión asistida / gestor de cookies |
| **Windows** (10 / 11) | ✅ Nativo | `yt-dlp.exe` / binario local | Microsoft Edge WebView2 / gestor |
| **Android** (8.0+) | ✅ Nativo | Runtime embebido / CLI | WebView nativo con extracción de `CookieManager` |

---

## 🚀 Requisitos Previos

En sistemas de escritorio (Linux y Windows), se requiere tener instalados `yt-dlp` y `ffmpeg` en el `PATH` del sistema:

### En Arch Linux / CachyOS:
```bash
sudo pacman -S yt-dlp ffmpeg
```

### En Ubuntu / Debian:
```bash
sudo apt update && sudo apt install yt-dlp ffmpeg
```

### En Windows:
```powershell
winget install yt-dlp
winget install Gyan.FFmpeg
```

---

## 🛠️ Compilación y Ejecución

### 1. Clonar el repositorio
```bash
git clone https://github.com/MapleProjects/maple-video-downloader.git
cd maple-video-downloader
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Ejecutar en modo desarrollo
```bash
# En Linux
flutter run -d linux

# En Windows
flutter run -d windows

# En Android (con dispositivo o emulador conectado)
flutter run -d android
```

### 4. Compilar binarios de distribución
```bash
# Linux (Bundle binario)
flutter build linux --release

# Windows (Ejecutable)
flutter build windows --release

# Android (APK universal optimizado)
flutter build apk --release
```

---

## 🔒 Privacidad y Seguridad de Credenciales

- Las cookies capturadas mediante el navegador embebido se almacenan **única y exclusivamente de forma local** en el dispositivo del usuario (`~/.config/maple-video-downloader/youtube_cookies.txt` en Linux o en el directorio privado de datos de la app en Android y Windows).
- No existe ningún servidor intermedio, telemetría de navegación ni envío de tokens hacia servicios externos.
- La aplicación permite limpiar o revocar la sesión en cualquier momento desde la sección de Ajustes con un solo clic.

---

## 📄 Licencia

Distribuido bajo la Licencia **MIT**. Consulta el archivo `LICENSE` para más información.
Desarrollado con dedicación por **[MapleProjects](https://github.com/MapleProjects)**.
