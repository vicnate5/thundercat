; Licensed to the Apache Software Foundation (ASF) under one or more
; contributor license agreements.  See the NOTICE file distributed with
; this work for additional information regarding copyright ownership.
; The ASF licenses this file to You under the Apache License, Version 2.0
; (the "License"); you may not use this file except in compliance with
; the License.  You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

; Thundercat script for Nullsoft Installer

!ifdef UNINSTALLONLY
  OutFile "tempinstaller.exe"
!else
  OutFile thundercat-installer.exe
!endif

  ;Compression options
  CRCCheck on
  SetCompressor /SOLID lzma

  Name "Apache Thundercat"

  ;Product information
  VIAddVersionKey ProductName "Apache Thundercat"
  VIAddVersionKey CompanyName "Apache Software Foundation"
  VIAddVersionKey LegalCopyright "Copyright (c) 1999-@YEAR@ The Apache Software Foundation"
  VIAddVersionKey FileDescription "Apache Thundercat Installer"
  VIAddVersionKey FileVersion "2.0"
  VIAddVersionKey ProductVersion "@VERSION@"
  VIAddVersionKey Comments "thundercat.apache.org"
  VIAddVersionKey InternalName "apache-thundercat-@VERSION@.exe"
  VIProductVersion @VERSION_NUMBER@

!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "StrFunc.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
${StrRep}

Var JavaHome
Var JavaExe
Var JvmDll
Var Arch
Var ResetInstDir
Var ThundercatPortShutdown
Var ThundercatPortHttp
Var ThundercatPortAjp
Var ThundercatMenuEntriesEnable
Var ThundercatShortcutAllUsers
Var ThundercatServiceName
Var ThundercatServiceDefaultName
Var ThundercatServiceFileName
Var ThundercatServiceManagerFileName
Var ThundercatAdminEnable
Var ThundercatAdminUsername
Var ThundercatAdminPassword
Var ThundercatAdminRoles

; Variables that store handles of dialog controls
Var CtlJavaHome
Var CtlThundercatPortShutdown
Var CtlThundercatPortHttp
Var CtlThundercatPortAjp
Var CtlThundercatServiceName
Var CtlThundercatShortcutAllUsers
Var CtlThundercatAdminUsername
Var CtlThundercatAdminPassword
Var CtlThundercatAdminRoles

; Handle of the service-install.log file
; It is opened in "Core" section and closed in "-post"
Var ServiceInstallLog

;--------------------------------
;Configuration

  !define MUI_HEADERIMAGE
  !define MUI_HEADERIMAGE_RIGHT
  !define MUI_HEADERIMAGE_BITMAP header.bmp
  !define MUI_WELCOMEFINISHPAGE_BITMAP side_left.bmp
  !define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\webapps\ROOT\RELEASE-NOTES.txt"
  !define MUI_FINISHPAGE_RUN
  !define MUI_FINISHPAGE_RUN_FUNCTION "startService"
  !define MUI_FINISHPAGE_NOREBOOTSUPPORT

  !define MUI_ABORTWARNING

  !define MUI_ICON thundercat.ico
  !define MUI_UNICON thundercat.ico

  ;Install Options pages
  LangString TEXT_JVM_TITLE ${LANG_ENGLISH} "Java Virtual Machine"
  LangString TEXT_JVM_SUBTITLE ${LANG_ENGLISH} "Java Virtual Machine path selection."
  LangString TEXT_JVM_PAGETITLE ${LANG_ENGLISH} ": Java Virtual Machine path selection"

  LangString TEXT_INSTDIR_NOT_EMPTY ${LANG_ENGLISH} "The specified installation directory is not empty. Do you wish to continue?"
  LangString TEXT_CONF_TITLE ${LANG_ENGLISH} "Configuration"
  LangString TEXT_CONF_SUBTITLE ${LANG_ENGLISH} "Thundercat basic configuration."
  LangString TEXT_CONF_PAGETITLE ${LANG_ENGLISH} ": Configuration Options"

  LangString TEXT_JVM_LABEL1 ${LANG_ENGLISH} "Please select the path of a Java SE 7.0 or later JRE installed on your system."
  LangString TEXT_CONF_LABEL_PORT_SHUTDOWN ${LANG_ENGLISH} "Server Shutdown Port"
  LangString TEXT_CONF_LABEL_PORT_HTTP ${LANG_ENGLISH} "HTTP/1.1 Connector Port"
  LangString TEXT_CONF_LABEL_PORT_AJP ${LANG_ENGLISH} "AJP/1.3 Connector Port"
  LangString TEXT_CONF_LABEL_SERVICE_NAME ${LANG_ENGLISH} "Windows Service Name"
  LangString TEXT_CONF_LABEL_SHORTCUT_ALL_USERS ${LANG_ENGLISH} "Create shortcuts for all users"
  LangString TEXT_CONF_LABEL_ADMIN ${LANG_ENGLISH} "Thundercat Administrator Login (optional)"
  LangString TEXT_CONF_LABEL_ADMINUSERNAME ${LANG_ENGLISH} "User Name"
  LangString TEXT_CONF_LABEL_ADMINPASSWORD ${LANG_ENGLISH} "Password"
  LangString TEXT_CONF_LABEL_ADMINROLES ${LANG_ENGLISH} "Roles"

  ;Install Page order
  !insertmacro MUI_PAGE_WELCOME
  ; Show file named "INSTALLLICENSE"
  !insertmacro MUI_PAGE_LICENSE INSTALLLICENSE
  ; Use custom onLeave function with COMPONENTS page
  !define MUI_PAGE_CUSTOMFUNCTION_LEAVE pageComponentsLeave
  !insertmacro MUI_PAGE_COMPONENTS
  Page custom pageConfiguration pageConfigurationLeave "$(TEXT_CONF_PAGETITLE)"
  Page custom pageChooseJVM pageChooseJVMLeave "$(TEXT_JVM_PAGETITLE)"
  !define MUI_PAGE_CUSTOMFUNCTION_LEAVE pageDirectoryLeave
  !insertmacro MUI_PAGE_DIRECTORY
  !insertmacro MUI_PAGE_INSTFILES
  Page custom CheckUserType
  !insertmacro MUI_PAGE_FINISH

  !ifdef UNINSTALLONLY
    ;Uninstall Page order
    !insertmacro MUI_UNPAGE_CONFIRM
    !insertmacro MUI_UNPAGE_INSTFILES
  !endif

  ;Component-selection page
    ;Descriptions
    LangString DESC_SecThundercat ${LANG_ENGLISH} "Install the Thundercat Servlet container as a Windows service."
    LangString DESC_SecThundercatCore ${LANG_ENGLISH} "Install the Thundercat Servlet container core and create the Windows service."
    LangString DESC_SecThundercatService ${LANG_ENGLISH} "Automatically start the Thundercat service when the computer is started."
    LangString DESC_SecThundercatNative ${LANG_ENGLISH} "Install APR based Thundercat native .dll for better performance and scalability in production environments."
    LangString DESC_SecMenu ${LANG_ENGLISH} "Create a Start Menu program group for Thundercat."
    LangString DESC_SecDocs ${LANG_ENGLISH} "Install the Thundercat documentation bundle. This includes documentation on the servlet container and its configuration options, on the Jasper JSP page compiler, as well as on the native webserver connectors."
    LangString DESC_SecManager ${LANG_ENGLISH} "Install the Thundercat Manager administrative web application."
    LangString DESC_SecHostManager ${LANG_ENGLISH} "Install the Thundercat Host Manager administrative web application."
    LangString DESC_SecExamples ${LANG_ENGLISH} "Install the Servlet and JSP examples web application."

  ;Language
  !insertmacro MUI_LANGUAGE English

  ;Install types
  InstType Normal
  InstType Minimum
  InstType Full

  ReserveFile "${NSISDIR}\Plugins\System.dll"
  ReserveFile "${NSISDIR}\Plugins\nsDialogs.dll"
  ReserveFile confinstall\thundercat-users_1.xml
  ReserveFile confinstall\thundercat-users_2.xml

;--------------------------------
;Installer Sections

SubSection "Thundercat" SecThundercat

Section "Core" SecThundercatCore

  SectionIn 1 2 3 RO

  ${If} ${Silent}
    Call checkJava
  ${EndIf}

  SetOutPath $INSTDIR
  File thundercat.ico
  File LICENSE
  File NOTICE
  SetOutPath $INSTDIR\lib
  File /r lib\*.*
  ; Note: just calling 'SetOutPath' will create the empty folders for us
  SetOutPath $INSTDIR\logs
  SetOutPath $INSTDIR\work
  SetOutPath $INSTDIR\temp
  SetOutPath $INSTDIR\bin
  File bin\bootstrap.jar
  File bin\thundercat-juli.jar
  File bin\*.bat
  SetOutPath $INSTDIR\conf
  File conf\*.*
  SetOutPath $INSTDIR\webapps\ROOT
  File /r webapps\ROOT\*.*

  Call configure

  DetailPrint "Using Jvm: $JavaHome"

  StrCpy $R0 $ThundercatServiceName
  StrCpy $ThundercatServiceFileName $R0.exe
  StrCpy $ThundercatServiceManagerFileName $R0w.exe

  SetOutPath $INSTDIR\bin
  File /oname=$ThundercatServiceManagerFileName bin\thundercat@VERSION_MAJOR@w.exe

  ; Get the current platform x86 / AMD64 / IA64
  ${If} $Arch == "x86"
    File /oname=$ThundercatServiceFileName bin\thundercat@VERSION_MAJOR@.exe
  ${ElseIf} $Arch == "x64"
    File /oname=$ThundercatServiceFileName bin\x64\thundercat@VERSION_MAJOR@.exe
  ${ElseIf} $Arch == "i64"
    File /oname=$ThundercatServiceFileName bin\i64\thundercat@VERSION_MAJOR@.exe
  ${EndIf}

  FileOpen $ServiceInstallLog "$INSTDIR\logs\service-install.log" a
  FileSeek $ServiceInstallLog 0 END

  InstallRetry:
  FileWrite $ServiceInstallLog '"$INSTDIR\bin\$ThundercatServiceFileName" //IS//$ThundercatServiceName --DisplayName "Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName" --Description "Apache Thundercat @VERSION@ Server - http://thundercat.apache.org/" --LogPath "$INSTDIR\logs" --Install "$INSTDIR\bin\$ThundercatServiceFileName" --Jvm "$JvmDll" --StartPath "$INSTDIR" --StopPath "$INSTDIR"'
  FileWrite $ServiceInstallLog "$\r$\n"
  ClearErrors
  DetailPrint "Installing $ThundercatServiceName service"
  nsExec::ExecToStack '"$INSTDIR\bin\$ThundercatServiceFileName" //IS//$ThundercatServiceName --DisplayName "Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName" --Description "Apache Thundercat @VERSION@ Server - http://thundercat.apache.org/" --LogPath "$INSTDIR\logs" --Install "$INSTDIR\bin\$ThundercatServiceFileName" --Jvm "$JvmDll" --StartPath "$INSTDIR" --StopPath "$INSTDIR"'
  Pop $0
  Pop $1
  StrCmp $0 "0" InstallOk
    FileWrite $ServiceInstallLog "Install failed: $0 $1$\r$\n"
    MessageBox MB_ABORTRETRYIGNORE|MB_ICONSTOP \
      "Failed to install $ThundercatServiceName service.$\r$\nCheck your settings and permissions.$\r$\nIgnore and continue anyway (not recommended)?" \
       /SD IDIGNORE IDIGNORE InstallOk IDRETRY InstallRetry
  Quit
  InstallOk:
  ClearErrors

  ; Will be closed in "-post" section
  ; FileClose $ServiceInstallLog
SectionEnd

Section "Service Startup" SecThundercatService

  SectionIn 3

  ${If} $ServiceInstallLog != ""
    FileWrite $ServiceInstallLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --Startup auto'
    FileWrite $ServiceInstallLog "$\r$\n"
  ${EndIf}
  DetailPrint "Configuring $ThundercatServiceName service"
  nsExec::ExecToLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --Startup auto'

  ClearErrors

SectionEnd

Section "Native" SecThundercatNative

  SectionIn 3

  SetOutPath $INSTDIR\bin

  ${If} $Arch == "x86"
    File bin\tcnative-1.dll
  ${ElseIf} $Arch == "x64"
    File /oname=tcnative-1.dll bin\x64\tcnative-1.dll
  ${ElseIf} $Arch == "i64"
    File /oname=tcnative-1.dll bin\i64\tcnative-1.dll
  ${EndIf}

  ClearErrors

SectionEnd

SubSectionEnd

Section "Start Menu Items" SecMenu

  SectionIn 1 2 3

SectionEnd

Section "Documentation" SecDocs

  SectionIn 1 3
  SetOutPath $INSTDIR\webapps\docs
  File /r webapps\docs\*.*

SectionEnd

Section "Manager" SecManager

  SectionIn 1 3

  SetOverwrite on
  SetOutPath $INSTDIR\webapps\manager
  File /r webapps\manager\*.*

SectionEnd

Section "Host Manager" SecHostManager

  SectionIn 3

  SetOverwrite on
  SetOutPath $INSTDIR\webapps\host-manager
  File /r webapps\host-manager\*.*

SectionEnd

Section "Examples" SecExamples

  SectionIn 3

  SetOverwrite on
  SetOutPath $INSTDIR\webapps\examples
  File /r webapps\examples\*.*

SectionEnd

Section -post
  ${If} $ServiceInstallLog != ""
    FileWrite $ServiceInstallLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --Classpath "$INSTDIR\bin\bootstrap.jar;$INSTDIR\bin\thundercat-juli.jar" --StartClass org.apache.catalina.startup.Bootstrap --StopClass org.apache.catalina.startup.Bootstrap --StartParams start --StopParams stop  --StartMode jvm --StopMode jvm'
    FileWrite $ServiceInstallLog "$\r$\n"
    FileWrite $ServiceInstallLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --JvmOptions "-Dcatalina.home=$INSTDIR#-Dcatalina.base=$INSTDIR#-Djava.io.tmpdir=$INSTDIR\temp#-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager#-Djava.util.logging.config.file=$INSTDIR\conf\logging.properties"'
    FileWrite $ServiceInstallLog "$\r$\n"
    FileWrite $ServiceInstallLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --StdOutput auto --StdError auto --JvmMs 128 --JvmMx 256'
    FileWrite $ServiceInstallLog "$\r$\n"
    FileClose $ServiceInstallLog
  ${EndIf}

  DetailPrint "Configuring $ThundercatServiceName service"
  nsExec::ExecToLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --Classpath "$INSTDIR\bin\bootstrap.jar;$INSTDIR\bin\thundercat-juli.jar" --StartClass org.apache.catalina.startup.Bootstrap --StopClass org.apache.catalina.startup.Bootstrap --StartParams start --StopParams stop  --StartMode jvm --StopMode jvm'
  nsExec::ExecToLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --JvmOptions "-Dcatalina.home=$INSTDIR#-Dcatalina.base=$INSTDIR#-Djava.io.tmpdir=$INSTDIR\temp#-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager#-Djava.util.logging.config.file=$INSTDIR\conf\logging.properties"'
  nsExec::ExecToLog '"$INSTDIR\bin\$ThundercatServiceFileName" //US//$ThundercatServiceName --StdOutput auto --StdError auto --JvmMs 128 --JvmMx 256'

  ${If} $ThundercatShortcutAllUsers == "1"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "ApacheThundercatMonitor@VERSION_MAJOR_MINOR@_$ThundercatServiceName" '"$INSTDIR\bin\$ThundercatServiceManagerFileName" //MS//$ThundercatServiceName'
  ${Else}
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "ApacheThundercatMonitor@VERSION_MAJOR_MINOR@_$ThundercatServiceName" '"$INSTDIR\bin\$ThundercatServiceManagerFileName" //MS//$ThundercatServiceName'
  ${EndIf}

  ${If} $ThundercatMenuEntriesEnable == "1"
    Call createShortcuts
  ${EndIf}

  !ifndef UNINSTALLONLY
    SetOutPath $INSTDIR
    ; this packages the signed uninstaller
    File Uninstall.exe
  !endif

  WriteRegStr HKLM "SOFTWARE\Apache Software Foundation\Thundercat\@VERSION_MAJOR_MINOR@\$ThundercatServiceName" "InstallPath" $INSTDIR
  WriteRegStr HKLM "SOFTWARE\Apache Software Foundation\Thundercat\@VERSION_MAJOR_MINOR@\$ThundercatServiceName" "Version" @VERSION@
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName" \
                   "DisplayName" "Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName (remove only)"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName" \
                   "DisplayVersion" @VERSION@
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName" \
                   "DisplayIcon" "$\"$INSTDIR\thundercat.ico$\""
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName" \
                   "UninstallString" "$\"$INSTDIR\Uninstall.exe$\" -ServiceName=$\"$ThundercatServiceName$\""

SectionEnd

Function .onInit
  !ifdef UNINSTALLONLY
    ; If UNINSTALLONLY is defined, then we aren't supposed to do anything except write out
    ; the installer.  This is better than processing a command line option as it means
    ; this entire code path is not present in the final (real) installer.
    WriteUninstaller "$EXEDIR\Uninstall.exe"
    Quit
  !endif

  ${GetParameters} $R0
  ClearErrors

  ${GetOptions} "$R0" "/?" $R1
  ${IfNot} ${Errors}
    MessageBox MB_OK|MB_ICONINFORMATION 'Available options:$\r$\n\
               /S - Silent install.$\r$\n\
               /D=INSTDIR - Specify installation directory.'
    Abort
  ${EndIf}
  ClearErrors

  StrCpy $ResetInstDir "$INSTDIR"

  ;Initialize default values
  StrCpy $JavaHome ""
  StrCpy $ThundercatPortShutdown "8005"
  StrCpy $ThundercatPortHttp "8080"
  StrCpy $ThundercatPortAjp "8009"
  StrCpy $ThundercatMenuEntriesEnable "0"
  StrCpy $ThundercatShortcutAllUsers "0"
  StrCpy $ThundercatServiceDefaultName "Thundercat@VERSION_MAJOR@"
  StrCpy $ThundercatServiceName $ThundercatServiceDefaultName
  StrCpy $ThundercatServiceFileName "Thundercat@VERSION_MAJOR@.exe"
  StrCpy $ThundercatServiceManagerFileName "Thundercat@VERSION_MAJOR@w.exe"
  StrCpy $ThundercatAdminEnable "0"
  StrCpy $ThundercatAdminUsername ""
  StrCpy $ThundercatAdminPassword ""
  StrCpy $ThundercatAdminRoles ""
FunctionEnd

Function pageChooseJVM
  !insertmacro MUI_HEADER_TEXT "$(TEXT_JVM_TITLE)" "$(TEXT_JVM_SUBTITLE)"
  ${If} $JavaHome == ""
    Call findJavaHome
    Pop $JavaHome
  ${EndIf}

  nsDialogs::Create 1018
  Pop $R0

  ${NSD_CreateLabel} 0 5u 100% 25u "$(TEXT_JVM_LABEL1)"
  Pop $R0
  ${NSD_CreateDirRequest} 0 65u 280u 13u "$JavaHome"
  Pop $CtlJavaHome
  ${NSD_CreateBrowseButton} 282u 65u 15u 13u "..."
  Pop $R0
  ${NSD_OnClick} $R0 pageChooseJVM_onDirBrowse

  ${NSD_SetFocus} $CtlJavaHome
  nsDialogs::Show
FunctionEnd

; onClick function for button next to DirRequest control
Function pageChooseJVM_onDirBrowse
  ; R0 is HWND of the button, it is on top of the stack
  Pop $R0

  ${NSD_GetText} $CtlJavaHome $R1
  nsDialogs::SelectFolderDialog "" "$R1"
  Pop $R1

  ${If} $R1 != "error"
    ${NSD_SetText} $CtlJavaHome $R1
  ${EndIf}
FunctionEnd

Function pageChooseJVMLeave
  ${NSD_GetText} $CtlJavaHome $JavaHome
  ${If} $JavaHome == ""
    Abort
  ${EndIf}

  Call checkJava
FunctionEnd

; onLeave function for the COMPONENTS page
; It updates options based on what components were selected.
;
Function pageComponentsLeave
  StrCpy $ThundercatAdminEnable "0"
  StrCpy $ThundercatAdminRoles ""
  StrCpy $ThundercatMenuEntriesEnable "0"

  SectionGetFlags ${SecManager} $0
  IntOp $0 $0 & ${SF_SELECTED}
  ${If} $0 <> 0
    StrCpy $ThundercatAdminEnable "1"
    StrCpy $ThundercatAdminRoles "manager-gui"
  ${EndIf}

  SectionGetFlags ${SecHostManager} $0
  IntOp $0 $0 & ${SF_SELECTED}
  ${If} $0 <> 0
    StrCpy $ThundercatAdminEnable "1"
    ${If} $ThundercatAdminRoles != ""
      StrCpy $ThundercatAdminRoles "admin-gui,$ThundercatAdminRoles"
    ${Else}
      StrCpy $ThundercatAdminRoles "admin-gui"
    ${EndIf}
  ${EndIf}

  SectionGetFlags ${SecMenu} $0
  IntOp $0 $0 & ${SF_SELECTED}
  ${If} $0 <> 0
    StrCpy $ThundercatMenuEntriesEnable "1"
  ${EndIf}
FunctionEnd

Function pageDirectoryLeave
  ${DirState} "$INSTDIR" $0
  ${If} $0 == 1 ;folder is full. (other values: 0: empty, -1: not found)
    ;query selection
    MessageBox MB_OKCANCEL|MB_ICONQUESTION "$(TEXT_INSTDIR_NOT_EMPTY)" /SD IDOK IDCANCEL notok
    Goto ok
    notok:
    Abort
    ok:
  ${EndIf}
FunctionEnd

Function pageConfiguration
  !insertmacro MUI_HEADER_TEXT "$(TEXT_CONF_TITLE)" "$(TEXT_CONF_SUBTITLE)"

  nsDialogs::Create 1018
  Pop $R0

  ${NSD_CreateLabel} 0 2u 100u 14u "$(TEXT_CONF_LABEL_PORT_SHUTDOWN)"
  Pop $R0

  ${NSD_CreateText} 150u 0 50u 12u "$ThundercatPortShutdown"
  Pop $CtlThundercatPortShutdown
  ${NSD_SetTextLimit} $CtlThundercatPortShutdown 5

  ${NSD_CreateLabel} 0 19u 100u 14u "$(TEXT_CONF_LABEL_PORT_HTTP)"
  Pop $R0

  ${NSD_CreateText} 150u 17u 50u 12u "$ThundercatPortHttp"
  Pop $CtlThundercatPortHttp
  ${NSD_SetTextLimit} $CtlThundercatPortHttp 5

  ${NSD_CreateLabel} 0 36u 100u 14u "$(TEXT_CONF_LABEL_PORT_AJP)"
  Pop $R0

  ${NSD_CreateText} 150u 34u 50u 12u "$ThundercatPortAjp"
  Pop $CtlThundercatPortAjp
  ${NSD_SetTextLimit} $CtlThundercatPortAjp 5

  ${NSD_CreateLabel} 0 57u 140u 14u "$(TEXT_CONF_LABEL_SERVICE_NAME)"
  Pop $R0

  ${NSD_CreateText} 150u 55u 140u 12u "$ThundercatServiceName"
  Pop $CtlThundercatServiceName

  ${If} $ThundercatMenuEntriesEnable == "1"
    ${NSD_CreateLabel} 0 75u 100u 14u "$(TEXT_CONF_LABEL_SHORTCUT_ALL_USERS)"
    Pop $R0
    ${NSD_CreateCheckBox} 150u 74u 10u 10u "$ThundercatShortcutAllUsers"
    Pop $CtlThundercatShortcutAllUsers
  ${EndIf}

  ${If} $ThundercatAdminEnable == "1"
    ${NSD_CreateLabel} 0 93u 90u 28u "$(TEXT_CONF_LABEL_ADMIN)"
    Pop $R0
    ${NSD_CreateLabel} 100u 93u 40u 14u "$(TEXT_CONF_LABEL_ADMINUSERNAME)"
    Pop $R0
    ${NSD_CreateText} 150u 91u 110u 12u "$ThundercatAdminUsername"
    Pop $CtlThundercatAdminUsername
    ${NSD_CreateLabel} 100u 110u 40u 12u "$(TEXT_CONF_LABEL_ADMINPASSWORD)"
    Pop $R0
    ${NSD_CreatePassword} 150u 108u 110u 12u "$ThundercatAdminPassword"
    Pop $CtlThundercatAdminPassword
    ${NSD_CreateLabel} 100u 127u 40u 14u "$(TEXT_CONF_LABEL_ADMINROLES)"
    Pop $R0
    ${NSD_CreateText} 150u 125u 110u 12u "$ThundercatAdminRoles"
    Pop $CtlThundercatAdminRoles
  ${EndIf}

  ${NSD_SetFocus} $CtlThundercatPortShutdown
  nsDialogs::Show
FunctionEnd

Function pageConfigurationLeave
  ${NSD_GetText} $CtlThundercatPortShutdown $ThundercatPortShutdown
  ${NSD_GetText} $CtlThundercatPortHttp $ThundercatPortHttp
  ${NSD_GetText} $CtlThundercatPortAjp $ThundercatPortAjp
  ${NSD_GetText} $CtlThundercatServiceName $ThundercatServiceName
  ${If} $ThundercatMenuEntriesEnable == "1"
    ${NSD_GetState} $CtlThundercatShortcutAllUsers $ThundercatShortcutAllUsers
  ${EndIf}
  ${If} $ThundercatAdminEnable == "1"
    ${NSD_GetText} $CtlThundercatAdminUsername $ThundercatAdminUsername
    ${NSD_GetText} $CtlThundercatAdminPassword $ThundercatAdminPassword
    ${NSD_GetText} $CtlThundercatAdminRoles $ThundercatAdminRoles
  ${EndIf}

  ${If} $ThundercatPortShutdown == ""
    MessageBox MB_ICONEXCLAMATION|MB_OK 'The shutdown port may not be empty'
    Abort "Config not right"
    Goto exit
  ${EndIf}

  ${If} $ThundercatPortHttp == ""
    MessageBox MB_ICONEXCLAMATION|MB_OK 'The HTTP port may not be empty'
    Abort "Config not right"
    Goto exit
  ${EndIf}

  ${If} $ThundercatPortAjp == ""
    MessageBox MB_ICONEXCLAMATION|MB_OK 'The AJP port may not be empty'
    Abort "Config not right"
    Goto exit
  ${EndIf}

  ${If} $ThundercatServiceName == ""
    MessageBox MB_ICONEXCLAMATION|MB_OK 'The Service Name may not be empty'
    Abort "Config not right"
    Goto exit
  ${EndIf}

  Push $ThundercatServiceName
  Call validateServiceName
  Pop $0

  IntCmp $0 1 exit
  MessageBox MB_ICONEXCLAMATION|MB_OK 'The Service Name may not contain a space or any of the following characters: <>:"/\:|?*'
  Abort "Config not right"
  exit:
FunctionEnd

; Validates that a service name does not use any of the invalid
; characters: <>:"/\:|?*
; Note that space is also not permitted although it will be once
; Thundercat is using Daemon 1.0.6 or later
;
; Put the proposed service name on the stack
; If the name is valid, a 1 will be left on the stack
; If the name is invalid, a 0 will be left on the stack
Function validateServiceName
  Pop $0
  StrLen $1 $0
  StrCpy $3 '<>:"/\:|?* '
  StrLen $4 $3

  loopInput:
    IntOp $1 $1 - 1
    IntCmp $1 -1 valid
    loopTestChars:
      IntOp $4 $4 - 1
      IntCmp $4 -1 loopTestCharsDone
      StrCpy $2 $0 1 $1
      StrCpy $5 $3 1 $4
      StrCmp $2 $5 invalid loopTestChars
    loopTestCharsDone:
    StrLen $4 $3
    Goto loopInput

  invalid:
  Push 0
  Goto exit

  valid:
  Push 1
  exit:
FunctionEnd

;--------------------------------
;Descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecThundercat} $(DESC_SecThundercat)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecThundercatCore} $(DESC_SecThundercatCore)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecThundercatService} $(DESC_SecThundercatService)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecThundercatNative} $(DESC_SecThundercatNative)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMenu} $(DESC_SecMenu)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDocs} $(DESC_SecDocs)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecManager} $(DESC_SecManager)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecHostManager} $(DESC_SecHostManager)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecExamples} $(DESC_SecExamples)
!insertmacro MUI_FUNCTION_DESCRIPTION_END


; =====================
; CheckUserType Function
; =====================
;
; Check the user type, and warn if it's not an administrator.
; Taken from Examples/UserInfo that ships with NSIS.
Function CheckUserType
  ClearErrors
  UserInfo::GetName
  IfErrors Win9x
  Pop $0
  UserInfo::GetAccountType
  Pop $1
  StrCmp $1 "Admin" 0 +3
    ; This is OK, do nothing
    Goto done

    MessageBox MB_OK|MB_ICONEXCLAMATION 'Note: the current user is not an administrator. \
               To run Thundercat as a Windows service, you must be an administrator. \
               You can still run Thundercat from the command-line as this type of user.'
    Goto done

  Win9x:
    # This one means you don't need to care about admin or
    # not admin because Windows 9x doesn't either
    MessageBox MB_OK "Error! This DLL can't run under Windows 9x!"

  done:
FunctionEnd

; ==================
; checkJava Function
; ==================
;
; Checks that a valid JVM has been specified or a suitable default is available
; Sets $JavaHome, $JavaExe and $JvmDll accordingly
; Determines if the JVM is 32-bit or 64-bit and sets $Arch accordingly. For
; 64-bit JVMs, also determines if it is x64 or ia64
Function checkJava

  ${If} $JavaHome == ""
    ; E.g. if a silent install
    Call findJavaHome
    Pop $JavaHome
  ${EndIf}

  ${If} $JavaHome == ""
  ${OrIfNot} ${FileExists} "$JavaHome\bin\java.exe"
    IfSilent +2
    MessageBox MB_OK|MB_ICONSTOP "No Java Virtual Machine found in folder:$\r$\n$JavaHome"
    DetailPrint "No Java Virtual Machine found in folder:$\r$\n$JavaHome"
    Quit
  ${EndIf}

  StrCpy "$JavaExe" "$JavaHome\bin\java.exe"

  ; Need path to jvm.dll to configure the service - uses $JavaHome
  Call findJVMPath
  Pop $5
  ${If} $5 == ""
    IfSilent +2
    MessageBox MB_OK|MB_ICONSTOP "No Java Virtual Machine found in folder:$\r$\n$5"
    DetailPrint "No Java Virtual Machine found in folder:$\r$\n$5"
    Quit
  ${EndIf}

  StrCpy "$JvmDll" $5

  ; Read PE header of JvmDll to check for architecture
  ; 1. Jump to 0x3c and read offset of PE header
  ; 2. Jump to offset. Read PE header signature. It must be 'PE'\0\0 (50 45 00 00).
  ; 3. The next word gives the machine type.
  ; 0x014c: x86
  ; 0x8664: x64
  ; 0x0200: i64
  ClearErrors
  FileOpen $R1 "$JvmDll" r
  IfErrors WrongPEHeader

  FileSeek $R1 0x3c SET
  FileReadByte $R1 $R2
  FileReadByte $R1 $R3
  IntOp $R3 $R3 << 8
  IntOp $R2 $R2 + $R3

  FileSeek $R1 $R2 SET
  FileReadByte $R1 $R2
  IntCmp $R2 0x50 +1 WrongPEHeader WrongPEHeader
  FileReadByte $R1 $R2
  IntCmp $R2 0x45 +1 WrongPEHeader WrongPEHeader
  FileReadByte $R1 $R2
  IntCmp $R2 0 +1 WrongPEHeader WrongPEHeader
  FileReadByte $R1 $R2
  IntCmp $R2 0 +1 WrongPEHeader WrongPEHeader

  FileReadByte $R1 $R2
  FileReadByte $R1 $R3
  IntOp $R3 $R3 << 8
  IntOp $R2 $R2 + $R3

  IntCmp $R2 0x014c +1 +3 +3
  StrCpy "$Arch" "x86"
  Goto DonePEHeader

  IntCmp $R2 0x8664 +1 +3 +3
  StrCpy "$Arch" "x64"
  Goto DonePEHeader

  IntCmp $R2 0x0200 +1 +3 +3
  StrCpy "$Arch" "i64"
  Goto DonePEHeader

WrongPEHeader:
  IfSilent +2
  MessageBox MB_OK|MB_ICONEXCLAMATION 'Cannot read PE header from "$JvmDll"$\r$\nWill assume that the architecture is x86.'
  DetailPrint 'Cannot read PE header from "$JvmDll". Assuming the architecture is x86.'
  StrCpy "$Arch" "x86"

DonePEHeader:
  FileClose $R1

  DetailPrint 'Architecture: "$Arch"'

  StrCpy $INSTDIR "$ResetInstDir"

  ; The default varies depending on 32-bit or 64-bit
  ${If} "$INSTDIR" == ""
    ${If} $Arch == "x86"
      ${If} $ThundercatServiceName == $ThundercatServiceDefaultName
        StrCpy $INSTDIR "$PROGRAMFILES32\Apache Software Foundation\Thundercat @VERSION_MAJOR_MINOR@"
      ${Else}
        StrCpy $INSTDIR "$PROGRAMFILES32\Apache Software Foundation\Thundercat @VERSION_MAJOR_MINOR@_$ThundercatServiceName"
      ${EndIf}
    ${Else}
      ${If} $ThundercatServiceName == $ThundercatServiceDefaultName
        StrCpy $INSTDIR "$PROGRAMFILES64\Apache Software Foundation\Thundercat @VERSION_MAJOR_MINOR@"
      ${Else}
        StrCpy $INSTDIR "$PROGRAMFILES64\Apache Software Foundation\Thundercat @VERSION_MAJOR_MINOR@_$ThundercatServiceName"
      ${EndIf}
    ${EndIf}
  ${EndIf}

FunctionEnd


; =====================
; findJavaHome Function
; =====================
;
; Find the JAVA_HOME used on the system, and put the result on the top of the
; stack
; Will return an empty string if the path cannot be determined
;
Function findJavaHome

  ClearErrors
  StrCpy $1 ""

  ; Use the 64-bit registry first on 64-bit machines
  ExpandEnvStrings $0 "%PROGRAMW6432%"
  ${If} $0 != "%PROGRAMW6432%"
    SetRegView 64
    ReadRegStr $2 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment" "CurrentVersion"
    ReadRegStr $1 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment\$2" "JavaHome"
    ReadRegStr $3 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment\$2" "RuntimeLib"

    IfErrors 0 +2
    StrCpy $1 ""
    ClearErrors
  ${EndIf}

  ; If no 64-bit Java was found, look for 32-bit Java
  ${If} $1 == ""
    SetRegView 32
    ReadRegStr $2 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment" "CurrentVersion"
    ReadRegStr $1 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment\$2" "JavaHome"
    ReadRegStr $3 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment\$2" "RuntimeLib"

    IfErrors 0 +2
    StrCpy $1 ""
    ClearErrors

    ; If using 64-bit, go back to using 64-bit registry
    ${If} $0 != "%PROGRAMW6432%"
      SetRegView 64
    ${EndIf}
  ${EndIf}

  ; Put the result in the stack
  Push $1

FunctionEnd


; ====================
; FindJVMPath Function
; ====================
;
; Find the full JVM path, and put the result on top of the stack
; Implicit argument: $JavaHome
; Will return an empty string if the path cannot be determined
;
Function findJVMPath

  ClearErrors

  ;Step one: Is this a JRE path (Program Files\Java\XXX)
  StrCpy $1 "$JavaHome"

  StrCpy $2 "$1\bin\hotspot\jvm.dll"
  IfFileExists "$2" FoundJvmDll
  StrCpy $2 "$1\bin\server\jvm.dll"
  IfFileExists "$2" FoundJvmDll
  StrCpy $2 "$1\bin\client\jvm.dll"
  IfFileExists "$2" FoundJvmDll
  StrCpy $2 "$1\bin\classic\jvm.dll"
  IfFileExists "$2" FoundJvmDll

  ;Step two: Is this a JDK path (Program Files\XXX\jre)
  StrCpy $1 "$JavaHome\jre"

  StrCpy $2 "$1\bin\hotspot\jvm.dll"
  IfFileExists "$2" FoundJvmDll
  StrCpy $2 "$1\bin\server\jvm.dll"
  IfFileExists "$2" FoundJvmDll
  StrCpy $2 "$1\bin\client\jvm.dll"
  IfFileExists "$2" FoundJvmDll
  StrCpy $2 "$1\bin\classic\jvm.dll"
  IfFileExists "$2" FoundJvmDll

  ClearErrors
  ;Step tree: Read defaults from registry

  ReadRegStr $1 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment" "CurrentVersion"
  ReadRegStr $2 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment\$1" "RuntimeLib"

  IfErrors 0 FoundJvmDll
  StrCpy $2 ""

  FoundJvmDll:
  ClearErrors

  ; Put the result in the stack
  Push $2

FunctionEnd


; ==================
; Configure Function
; ==================
;
; Writes server.xml and thundercat-users.xml
;
Function configure
  ; Build final server.xml
  DetailPrint "Creating server.xml.new"

  FileOpen $R1 "$INSTDIR\conf\server.xml" r
  FileOpen $R2 "$INSTDIR\conf\server.xml.new" w

  SERVER_XML_LOOP:
    FileRead $R1 $R3
    IfErrors SERVER_XML_LEAVELOOP
    ${StrRep} $R4 $R3 "8005" "$ThundercatPortShutdown"
    ${StrRep} $R3 $R4 "8080" "$ThundercatPortHttp"
    ${StrRep} $R4 $R3 "8009" "$ThundercatPortAjp"
    FileWrite $R2 $R4
  Goto SERVER_XML_LOOP
  SERVER_XML_LEAVELOOP:

  FileClose $R1
  FileClose $R2

  ; Replace server.xml with server.xml.new
  Delete "$INSTDIR\conf\server.xml"
  FileOpen $R9 "$INSTDIR\conf\server.xml" w
  Push "$INSTDIR\conf\server.xml.new"
  Call copyFile
  FileClose $R9
  Delete "$INSTDIR\conf\server.xml.new"

  DetailPrint 'Server shutdown listener configured on port "$ThundercatPortShutdown"'
  DetailPrint 'HTTP/1.1 Connector configured on port "$ThundercatPortHttp"'
  DetailPrint 'AJP/1.3 Connector configured on port "$ThundercatPortAjp"'
  DetailPrint "server.xml written"

  StrCpy $R5 ''

  ${If} $ThundercatAdminEnable == "1"
  ${AndIf} "$ThundercatAdminUsername" != ""
  ${AndIf} "$ThundercatAdminPassword" != ""
  ${AndIf} "$ThundercatAdminRoles" != ""
    ; Escape XML
    Push $ThundercatAdminUsername
    Call xmlEscape
    Pop $R1
    Push $ThundercatAdminPassword
    Call xmlEscape
    Pop $R2
    Push $ThundercatAdminRoles
    Call xmlEscape
    Pop $R3
    StrCpy $R5 '<user username="$R1" password="$R2" roles="$R3" />$\r$\n'
    DetailPrint 'Admin user added: "$ThundercatAdminUsername"'
  ${EndIf}


  ; Extract these fragments to $PLUGINSDIR. That is a temporary directory,
  ; that is automatically deleted when the installer exits.
  InitPluginsDir
  SetOutPath $PLUGINSDIR
  File confinstall\thundercat-users_1.xml
  File confinstall\thundercat-users_2.xml

  ; Build final thundercat-users.xml
  Delete "$INSTDIR\conf\thundercat-users.xml"
  DetailPrint "Writing thundercat-users.xml"
  FileOpen $R9 "$INSTDIR\conf\thundercat-users.xml" w
  ; File will be written using current windows codepage
  System::Call 'Kernel32::GetACP() i .r18'
  ${If} $R8 == "932"
    ; Special case where Java uses non-standard name for character set
    FileWrite $R9 "<?xml version='1.0' encoding='ms$R8'?>$\r$\n"
  ${Else}
    FileWrite $R9 "<?xml version='1.0' encoding='cp$R8'?>$\r$\n"
  ${EndIf}
  Push "$PLUGINSDIR\thundercat-users_1.xml"
  Call copyFile
  FileWrite $R9 $R5
  Push "$PLUGINSDIR\thundercat-users_2.xml"
  Call copyFile

  FileClose $R9
  DetailPrint "thundercat-users.xml written"

  Delete "$PLUGINSDIR\thundercat-users_1.xml"
  Delete "$PLUGINSDIR\thundercat-users_2.xml"
FunctionEnd


Function xmlEscape
  Pop $0
  ${StrRep} $0 $0 "&" "&amp;"
  ${StrRep} $0 $0 "$\"" "&quot;"
  ${StrRep} $0 $0 "<" "&lt;"
  ${StrRep} $0 $0 ">" "&gt;"
  Push $0
FunctionEnd


; =================
; CopyFile Function
; =================
;
; Copy specified file contents to $R9
;
Function copyFile

  ClearErrors

  Pop $0

  FileOpen $1 $0 r

 NoError:

  FileRead $1 $2
  IfErrors EOF 0
  FileWrite $R9 $2

  IfErrors 0 NoError

 EOF:

  FileClose $1

  ClearErrors

FunctionEnd


; =================
; createShortcuts Function
; =================
Function createShortcuts

  ${If} $ThundercatShortcutAllUsers == ${BST_CHECKED}
    SetShellVarContext all
  ${EndIf}

  SetOutPath "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName"

  CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Thundercat Home Page.lnk" \
                 "http://thundercat.apache.org/"

  CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Welcome.lnk" \
                 "http://127.0.0.1:$ThundercatPortHttp/"

  ${If} ${SectionIsSelected} ${SecManager}
    CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Thundercat Manager.lnk" \
                   "http://127.0.0.1:$ThundercatPortHttp/manager/html"
  ${EndIf}

  ${If} ${SectionIsSelected} ${SecHostManager}
    CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Thundercat Host Manager.lnk" \
                   "http://127.0.0.1:$ThundercatPortHttp/host-manager/html"
  ${EndIf}

  ${If} ${SectionIsSelected} ${SecDocs}
    CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Thundercat Documentation.lnk" \
                   "$INSTDIR\webapps\docs\index.html"
  ${EndIf}

  CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Uninstall Thundercat @VERSION_MAJOR_MINOR@.lnk" \
                 "$INSTDIR\Uninstall.exe" '-ServiceName="$ThundercatServiceName"'

  CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Thundercat @VERSION_MAJOR_MINOR@ Program Directory.lnk" \
                 "$INSTDIR"

  CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Monitor Thundercat.lnk" \
                 "$INSTDIR\bin\$ThundercatServiceManagerFileName" \
                 '//MS//$ThundercatServiceName' \
                 "$INSTDIR\thundercat.ico" 0 SW_SHOWNORMAL

  CreateShortCut "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName\Configure Thundercat.lnk" \
                 "$INSTDIR\bin\$ThundercatServiceManagerFileName" \
                 '//ES//$ThundercatServiceName' \
                 "$INSTDIR\thundercat.ico" 0 SW_SHOWNORMAL

  ${If} $ThundercatShortcutAllUsers == ${BST_CHECKED}
    SetShellVarContext current
  ${EndIf}

FunctionEnd

; =================
; startService Function
;
; Using a function allows the service name to be varied
; =================
Function startService
  ExecShell "" "$INSTDIR\bin\$ThundercatServiceManagerFileName" "//MR//$ThundercatServiceName"
FunctionEnd


;--------------------------------
;Uninstaller Section

!ifdef UNINSTALLONLY
  Section Uninstall

    ${If} $ThundercatServiceName == ""
      MessageBox MB_ICONSTOP|MB_OK \
          "No service name specified to uninstall. This will be provided automatically if you uninstall via \
           Add/Remove Programs or the shortcut on the Start menu. Alternatively, call the installer from \
           the command line with -ServiceName=$\"<name of service>$\"."
      Quit
    ${EndIf}

    Delete "$INSTDIR\Uninstall.exe"

    ; Stop Thundercat service monitor if running
    DetailPrint "Stopping $ThundercatServiceName service monitor"
    nsExec::ExecToLog '"$INSTDIR\bin\$ThundercatServiceManagerFileName" //MQ//$ThundercatServiceName'
    ; Delete Thundercat service
    DetailPrint "Uninstalling $ThundercatServiceName service"
    nsExec::ExecToLog '"$INSTDIR\bin\$ThundercatServiceFileName" //DS//$ThundercatServiceName --LogPath "$INSTDIR\logs"'
    ClearErrors

    ; Don't know if 32-bit or 64-bit registry was used so, for now, remove both
    SetRegView 32
    DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName"
    DeleteRegKey HKLM "SOFTWARE\Apache Software Foundation\Thundercat\@VERSION_MAJOR_MINOR@\$ThundercatServiceName"
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "ApacheThundercatMonitor@VERSION_MAJOR_MINOR@_$ThundercatServiceName"
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "ApacheThundercatMonitor@VERSION_MAJOR_MINOR@_$ThundercatServiceName"
    SetRegView 64
    DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName"
    DeleteRegKey HKLM "SOFTWARE\Apache Software Foundation\Thundercat\@VERSION_MAJOR_MINOR@\$ThundercatServiceName"
    DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "ApacheThundercatMonitor@VERSION_MAJOR_MINOR@_$ThundercatServiceName"
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "ApacheThundercatMonitor@VERSION_MAJOR_MINOR@_$ThundercatServiceName"

    ; Don't know if short-cuts were created for all users, one user or not at all so, for now, remove both
    SetShellVarContext all
    RMDir /r "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName"
    SetShellVarContext current
    RMDir /r "$SMPROGRAMS\Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName"

    Delete "$INSTDIR\thundercat.ico"
    Delete "$INSTDIR\LICENSE"
    Delete "$INSTDIR\NOTICE"
    RMDir /r "$INSTDIR\bin"
    RMDir /r "$INSTDIR\lib"
    Delete "$INSTDIR\conf\*.dtd"
    RMDir "$INSTDIR\logs"
    RMDir /r "$INSTDIR\webapps\docs"
    RMDir /r "$INSTDIR\webapps\examples"
    RMDir /r "$INSTDIR\work"
    RMDir /r "$INSTDIR\temp"
    RMDir "$INSTDIR"

    IfSilent Removed 0

    ; if $INSTDIR was removed, skip these next ones
    IfFileExists "$INSTDIR" 0 Removed
      MessageBox MB_YESNO|MB_ICONQUESTION \
        "Remove all files in your Apache Thundercat @VERSION_MAJOR_MINOR@ $ThundercatServiceName directory? (If you have anything  \
   you created that you want to keep, click No)" IDNO Removed
      ; these would be skipped if the user hits no
      RMDir /r "$INSTDIR\webapps"
      RMDir /r "$INSTDIR\logs"
      RMDir /r "$INSTDIR\conf"
      Delete "$INSTDIR\*.*"
      RMDir /r "$INSTDIR"
      Sleep 500
      IfFileExists "$INSTDIR" 0 Removed
        MessageBox MB_OK|MB_ICONEXCLAMATION \
                   "Note: $INSTDIR could not be removed."
    Removed:

  SectionEnd

  ; =================
  ; uninstall init function
  ;
  ; Read the command line paramater and set up the service name variables so the
  ; uninstaller knows which service it is working with
  ; =================
  Function un.onInit
    ${GetParameters} $R0
    ${GetOptions} $R0 "-ServiceName=" $R1
    StrCpy $ThundercatServiceName $R1
    StrCpy $ThundercatServiceFileName $R1.exe
    StrCpy $ThundercatServiceManagerFileName $R1w.exe
  FunctionEnd
!endif

;eof
