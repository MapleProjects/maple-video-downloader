; Instalador NSIS de Maple Video Downloader.
; Compilar con:
;   makensis /DVERSION=1.1.0 /DBUILD_DIR=<ruta Release> /DINSTALLER_DIR=<salida> maple-video-downloader.nsi
;
; Instala por usuario en %LOCALAPPDATA%\Programs para que el actualizador
; pueda reemplazar archivos sin pedir elevacion (RequestExecutionLevel user).

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

!ifndef VERSION
  !define VERSION "1.1.0"
!endif
!ifndef BUILD_DIR
  !error "Falta /DBUILD_DIR con la ruta a build\\windows\\x64\\runner\\Release"
!endif
!ifndef INSTALLER_DIR
  !define INSTALLER_DIR "."
!endif
!ifndef PROJECT_DIR
  !define PROJECT_DIR "..\.."
!endif

!define APP_NAME "Maple Video Downloader"
!define APP_EXE "maple_video_downloader.exe"
!define APP_PUBLISHER "MapleProjects"
!define APP_URL "https://github.com/MapleProjects/maple-video-downloader"
!define REG_KEY "Software\MapleVideoDownloader"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MapleVideoDownloader"

Name "${APP_NAME}"
OutFile "${INSTALLER_DIR}\MapleVideoDownloader-Setup-${VERSION}.exe"

InstallDir "$LOCALAPPDATA\Programs\Maple Video Downloader"
InstallDirRegKey HKCU "${REG_KEY}" "InstallPath"

RequestExecutionLevel user
SetCompressor /SOLID lzma

Icon "${PROJECT_DIR}\windows\runner\resources\app_icon.ico"
UninstallIcon "${PROJECT_DIR}\windows\runner\resources\app_icon.ico"

;--------------------------------
; Interfaz

!define MUI_ABORTWARNING
!define MUI_ICON "${PROJECT_DIR}\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "${PROJECT_DIR}\windows\runner\resources\app_icon.ico"

!define MUI_WELCOMEPAGE_TITLE "Bienvenido al instalador de ${APP_NAME}"
!define MUI_WELCOMEPAGE_TEXT "Este asistente le guiara en la instalacion de ${APP_NAME} v${VERSION}.$\r$\n$\r$\nEl programa se instalara en su carpeta de usuario, sin permisos de administrador.$\r$\n$\r$\nHaga clic en Siguiente para continuar."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "Instalacion completada"
!define MUI_FINISHPAGE_TEXT "${APP_NAME} se ha instalado correctamente."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Ejecutar ${APP_NAME}"

!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Spanish"

;--------------------------------
; Variables

Var isUpdate

;--------------------------------
; Funciones

Function CloseApp
    DetailPrint "Cerrando instancias previas de ${APP_NAME}..."
    nsExec::Exec '"$SYSDIR\taskkill.exe" /F /T /IM ${APP_EXE}'
    Sleep 300

    IfFileExists "$INSTDIR\${APP_EXE}" 0 DoneCheck
    StrCpy $R0 0
CheckLoop:
    ClearErrors
    Delete "$INSTDIR\${APP_EXE}"
    IfFileExists "$INSTDIR\${APP_EXE}" 0 FileUnlocked
    nsExec::Exec '"$SYSDIR\taskkill.exe" /F /T /IM ${APP_EXE}'
    Sleep 300
    IntOp $R0 $R0 + 1
    ${If} $R0 < 4
        Goto CheckLoop
    ${EndIf}
    Rename "$INSTDIR\${APP_EXE}" "$INSTDIR\${APP_EXE}.old.$R0"
    Delete /REBOOTOK "$INSTDIR\${APP_EXE}.old.$R0"
    Goto DoneCheck
FileUnlocked:
DoneCheck:
FunctionEnd

Function .onInit
    ReadRegStr $0 HKCU "${REG_KEY}" "InstallPath"
    ${If} $0 != ""
        StrCpy $INSTDIR $0
        StrCpy $isUpdate "1"
    ${Else}
        StrCpy $INSTDIR "$LOCALAPPDATA\Programs\Maple Video Downloader"
        StrCpy $isUpdate "0"
    ${EndIf}
    Call CloseApp
FunctionEnd

;--------------------------------
; Instalacion

Section "${APP_NAME}" SecMain

    DetailPrint "Asegurando que ${APP_NAME} este cerrado..."
    Call CloseApp

    CreateDirectory "$INSTDIR"
    SetOutPath "$INSTDIR"

    DetailPrint "Copiando archivos..."
    File /r "${BUILD_DIR}\*.*"

    WriteUninstaller "$INSTDIR\Uninstall.exe"

    DetailPrint "Creando accesos directos..."
    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
    CreateShortcut "$SMPROGRAMS\${APP_NAME}\Desinstalar.lnk" "$INSTDIR\Uninstall.exe"
    CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

    WriteRegStr HKCU "${REG_KEY}" "InstallPath" "$INSTDIR"
    WriteRegStr HKCU "${REG_KEY}" "Version" "${VERSION}"

    WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
    WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "${APP_PUBLISHER}"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
    WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout" "${APP_URL}"
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1

    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"

    System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'

    IfSilent 0 NotSilent
    Exec '"$INSTDIR\${APP_EXE}"'
NotSilent:

SectionEnd

;--------------------------------
; Desinstalacion

Function un.CloseApp
    DetailPrint "Cerrando instancias previas de ${APP_NAME}..."
    nsExec::Exec '"$SYSDIR\taskkill.exe" /F /T /IM ${APP_EXE}'
    Sleep 300

    IfFileExists "$INSTDIR\${APP_EXE}" 0 DoneUnCheck
    StrCpy $R0 0
UnCheckLoop:
    ClearErrors
    Delete "$INSTDIR\${APP_EXE}"
    IfFileExists "$INSTDIR\${APP_EXE}" 0 FileUnUnlocked
    nsExec::Exec '"$SYSDIR\taskkill.exe" /F /T /IM ${APP_EXE}'
    Sleep 300
    IntOp $R0 $R0 + 1
    ${If} $R0 < 4
        Goto UnCheckLoop
    ${EndIf}
    Rename "$INSTDIR\${APP_EXE}" "$INSTDIR\${APP_EXE}.old"
    Delete /REBOOTOK "$INSTDIR\${APP_EXE}.old"
    Goto DoneUnCheck
FileUnUnlocked:
DoneUnCheck:
FunctionEnd

Function un.onInit
    Call un.CloseApp
FunctionEnd

Section "Uninstall"
    Call un.CloseApp
    Sleep 1000

    RMDir /r "$INSTDIR"

    Delete "$DESKTOP\${APP_NAME}.lnk"
    RMDir /r "$SMPROGRAMS\${APP_NAME}"

    DeleteRegKey HKCU "${UNINST_KEY}"
    DeleteRegKey HKCU "${REG_KEY}"

    MessageBox MB_OK "${APP_NAME} ha sido desinstalado correctamente."
SectionEnd
