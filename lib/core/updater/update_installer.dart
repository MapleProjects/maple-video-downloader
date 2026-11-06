import 'dart:io';

/// Aplica una actualización ya descargada y descomprimida.
///
/// El binario en ejecución no puede sobrescribirse a sí mismo en Windows, así
/// que se delega en un script auxiliar que espera el cierre del proceso,
/// copia los archivos y relanza la aplicación.
class UpdateInstaller {
  /// Directorio donde vive el ejecutable actual.
  static Directory installDirectory() {
    return File(Platform.resolvedExecutable).parent;
  }

  /// Comprueba si el directorio de instalación admite escritura sin elevar
  /// privilegios. Un paquete del sistema (pacman) o una instalación en
  /// /usr/bin no lo permite.
  static Future<bool> isInstallDirectoryWritable() async {
    final dir = installDirectory();
    final probe = File('${dir.path}${Platform.pathSeparator}.maple_write_probe');
    try {
      await probe.writeAsString('probe', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Detecta instalaciones gestionadas por el gestor de paquetes de Arch.
  static Future<bool> isManagedByPackageManager() async {
    if (!Platform.isLinux) return false;
    try {
      final result = await Process.run(
        'pacman',
        ['-Qo', Platform.resolvedExecutable],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Lanza el script de aplicación y deja que el llamador cierre la app.
  static Future<void> applyAndRestart({
    required Directory stage,
    required Directory target,
    required String executablePath,
  }) async {
    final appPid = pid;
    if (Platform.isWindows) {
      final script = File('${stage.parent.path}${Platform.pathSeparator}apply_update.ps1');
      await script.writeAsString(
        _windowsScript(
          appPid: appPid,
          stage: stage.path,
          target: target.path,
          exe: executablePath,
        ),
        flush: true,
      );
      await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path,
        ],
        mode: ProcessStartMode.detached,
      );
    } else {
      final script = File('${stage.parent.path}${Platform.pathSeparator}apply_update.sh');
      await script.writeAsString(
        _unixScript(),
        flush: true,
      );
      await Process.run('chmod', ['+x', script.path]);
      await Process.start(
        '/bin/bash',
        [script.path, '$appPid', stage.path, target.path, executablePath],
        mode: ProcessStartMode.detached,
      );
    }
  }

  static String _psQuote(String value) => value.replaceAll("'", "''");

  static String _windowsScript({
    required int appPid,
    required String stage,
    required String target,
    required String exe,
  }) {
    final s = _psQuote(stage);
    final t = _psQuote(target);
    final e = _psQuote(exe);
    return '''
\$ErrorActionPreference = 'Stop'
\$AppPid = $appPid
\$Stage = '$s'
\$Target = '$t'
\$Exe = '$e'
\$LogDir = Join-Path \$env:LOCALAPPDATA 'MapleVideoDownloader'
New-Item -ItemType Directory -Force -Path \$LogDir | Out-Null
\$Log = Join-Path \$LogDir 'update.log'
function Write-Log([string]\$Message) {
  \$line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), \$Message
  Add-Content -Path \$Log -Value \$line -Encoding UTF8
}
try {
  Write-Log "Waiting for process \$AppPid to exit"
  \$deadline = (Get-Date).AddSeconds(120)
  while ((Get-Date) -lt \$deadline) {
    \$proc = Get-Process -Id \$AppPid -ErrorAction SilentlyContinue
    if (-not \$proc) { break }
    Start-Sleep -Milliseconds 400
  }
  Start-Sleep -Milliseconds 800
  Write-Log "Copying \$Stage to \$Target"
  \$rcArgs = @("`"\$Stage`"", "`"\$Target`"", '/E', '/R:3', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
  & robocopy.exe @rcArgs | Out-Null
  \$rc = \$LASTEXITCODE
  Write-Log "robocopy exit code \$rc"
  if (\$rc -ge 8) { throw "robocopy failed with code \$rc" }
  Write-Log "Relaunching \$Exe"
  Start-Process -FilePath \$Exe -WorkingDirectory \$Target
  Write-Log 'Update finished'
} catch {
  Write-Log "ERROR: \$(\$_.Exception.Message)"
  if (Test-Path \$Exe) {
    Start-Process -FilePath \$Exe -WorkingDirectory \$Target
  }
}
''';
  }

  static String _unixScript() {
    return r'''#!/usr/bin/env bash
set -u
APP_PID="$1"
STAGE="$2"
TARGET="$3"
EXE="$4"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/maple-video-downloader"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/update.log"
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG"; }
log "waiting for pid $APP_PID"
for _ in $(seq 1 240); do
  kill -0 "$APP_PID" 2>/dev/null || break
  sleep 0.5
done
sleep 0.5
log "copying $STAGE -> $TARGET"
if ! cp -a "$STAGE"/. "$TARGET"/ >>"$LOG" 2>&1; then
  log "copy failed"
fi
chmod +x "$EXE" 2>/dev/null || true
log "relaunching $EXE"
nohup "$EXE" >/dev/null 2>&1 &
rm -rf "$STAGE"
log "done"
''';
  }
}
