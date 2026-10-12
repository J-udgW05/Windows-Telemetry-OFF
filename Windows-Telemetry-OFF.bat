@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

set "APP_NAME=Windows Telemetry OFF"
set "APP_VERSION=1.0.0"
title %APP_NAME% v%APP_VERSION%

:: 256-color ANSI palette
for /f %%A in ('echo prompt $E^| cmd') do set "ESC=%%A"
set "C_RESET=%ESC%[0m"
set "C_BOLD=%ESC%[1m"
set "C_ACC=%ESC%[38;5;45m"
set "C_SEC=%ESC%[38;5;141m"
set "C_OK=%ESC%[38;5;78m"
set "C_INFO=%ESC%[38;5;75m"
set "C_WARN=%ESC%[38;5;214m"
set "C_ERR=%ESC%[38;5;203m"
set "C_DIM=%ESC%[38;5;244m"
set "C_TXT=%ESC%[38;5;252m"
set "C_HI=%ESC%[38;5;231m"
set "C_SAFE=%ESC%[38;5;114m"
set "C_BAL=%ESC%[38;5;39m"
set "C_PRO=%ESC%[38;5;177m"
set "C_CUS=%ESC%[38;5;222m"

set "UI_LANG=EN"
if /i "%~1"=="/?" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/help" goto :show_help

if /i "%~1"=="ELEV" (
    shift /1
    goto :elevated
)

reg query "HKU\S-1-5-19" >nul 2>&1
if not errorlevel 1 goto :elevated

:: Relaunch elevated; path and args go through env vars to survive quotes
set "WTO_SELF=%~f0"
set "WTO_ARGS=%*"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath $env:WTO_SELF -ArgumentList ('ELEV ' + $env:WTO_ARGS) -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo.
    echo    %C_ERR%× Administrator rights are required / Требуются права администратора%C_RESET%
    echo    %C_DIM%Press any key to exit / Нажмите любую клавишу для выхода...%C_RESET%
    pause >nul
)
exit /b

:elevated
cd /d "%~dp0"
:: Absolute path: Git for Windows may put a Unix find.exe first in PATH
set "FIND=%SystemRoot%\System32\find.exe"

set "LOGFILE=%~dp0Windows_Telemetry_OFF_Log.txt"
(>>"%LOGFILE%" echo.) 2>nul || set "LOGFILE=%TEMP%\Windows_Telemetry_OFF_Log.txt"

:: Prior values are captured here before any change, so Restore can put them back exactly
for %%F in ("%LOGFILE%") do set "STATEFILE=%%~dpFWindows_Telemetry_OFF_State.txt"
set "SNAP_ON=0"

set "GROUP_COUNT=22"
set "PROFILE_GROUPS=19"
:: Newest generally available release; a newer version already installed wins over this value
:: 26H2 was still in Release Preview when this was written, so 25H2 is the safe default
set "WU_TARGET_WIN11=25H2"
set "WU_TARGET_WIN10=22H2"
set "MODE_ID="
set "MODE_NAME="
set "SILENT_MODE=0"
set "CLI_ACTION="
set "LANG_SET="
set "WIN_BUILD="
set "CUSTOM_INIT="
set "TLVL=1"
:: 1 = also write group policies (Pro): stronger, but Settings toggles turn grey
set "POLICY_MODE=0"
call :reset_counters

:parse_args
if "%~1"=="" goto :done_parse_args
set "ARG=%~1"
if "!ARG:~0,1!"=="-" set "ARG=/!ARG:~1!"
if /i "!ARG!"=="/-help" goto :show_help
if /i "!ARG!"=="/h" goto :show_help
if /i "!ARG!"=="/help" goto :show_help
if "!ARG!"=="/?" goto :show_help
if defined CFG_NEXT (
    set "CFGFILE=%~1"
    set "CFG_NEXT="
    shift /1
    goto :parse_args
)
if /i "!ARG!"=="/config" set "CFG_NEXT=1"
if /i "!ARG!"=="/silent" set "SILENT_MODE=1"
if /i "!ARG!"=="/ru" (set "UI_LANG=RU" & set "LANG_SET=1")
if /i "!ARG!"=="/en" (set "UI_LANG=EN" & set "LANG_SET=1")
for %%M in (safe balanced pro check restore flush updates) do if /i "!ARG!"=="/%%M" set "CLI_ACTION=%%M"
shift /1
goto :parse_args

:done_parse_args
if defined CFGFILE (
    call :load_config
    if not defined CFG_OK goto :config_failed
    set "MODE_ID=CUSTOM"
    set "MODE_NAME=Custom"
    set "CLI_ACTION=config"
    goto :run_selected
)
if /i "%CLI_ACTION%"=="safe" (set "MODE_ID=SAFE" & set "MODE_NAME=Safe" & goto :run_mode)
if /i "%CLI_ACTION%"=="balanced" (set "MODE_ID=BALANCED" & set "MODE_NAME=Balanced" & goto :run_mode)
if /i "%CLI_ACTION%"=="pro" (set "MODE_ID=PRO" & set "MODE_NAME=Pro" & goto :run_mode)
if /i "%CLI_ACTION%"=="check" goto :quick_check
if /i "%CLI_ACTION%"=="restore" goto :run_restore
if /i "%CLI_ACTION%"=="flush" goto :run_flush_standalone
if /i "%CLI_ACTION%"=="updates" goto :run_updates
if defined LANG_SET goto :main_menu
goto :lang_selection

:config_failed
call :pause_here
exit /b 2

:show_help
echo.
echo    %C_ACC%%C_BOLD%%APP_NAME%%C_RESET% %C_DIM%v%APP_VERSION%%C_RESET%
echo.
echo    %C_HI%Command-line arguments:%C_RESET%
echo    %C_SAFE%/safe%C_RESET%       %C_DIM%Run the Safe profile%C_RESET%
echo    %C_BAL%/balanced%C_RESET%   %C_DIM%Run the Balanced profile%C_RESET%
echo    %C_PRO%/pro%C_RESET%        %C_DIM%Run the Pro profile%C_RESET%
echo    %C_WARN%/restore%C_RESET%    %C_DIM%Restore default settings%C_RESET%
echo    %C_ACC%/check%C_RESET%      %C_DIM%Audit the current privacy state%C_RESET%
echo    %C_ACC%/flush%C_RESET%      %C_DIM%Flush telemetry and error report cache%C_RESET%
echo    %C_CUS%/updates%C_RESET%    %C_DIM%Windows Update: security updates only%C_RESET%
echo    %C_CUS%/config F%C_RESET%   %C_DIM%Apply a selection saved from the Custom menu%C_RESET%
echo    %C_TXT%/silent%C_RESET%     %C_DIM%No prompts or pauses%C_RESET%
echo    %C_TXT%/en, /ru%C_RESET%    %C_DIM%Interface language%C_RESET%
echo.
echo    %C_HI%Example:%C_RESET% %C_WARN%Windows-Telemetry-OFF.bat /pro /silent /en%C_RESET%
echo.
echo    %C_HI%Exit codes:%C_RESET% %C_DIM%0 - clean, 1 - warnings, 2 - errors%C_RESET%
echo.
exit /b

:lang_selection
call :header
echo    %C_HI%Select language / Выберите язык:%C_RESET%
echo.
echo    %C_ACC%[1]%C_RESET%  %C_TXT%English%C_RESET%
echo    %C_SEC%[2]%C_RESET%  %C_TXT%Русский%C_RESET%
echo.
<nul set /p "=%C_RESET%   %C_ACC%›%C_RESET% Choice / Выбор [1, 2]: "
choice /c 12 /n
if errorlevel 2 (set "UI_LANG=RU") else (set "UI_LANG=EN")
goto :main_menu

:: ==============================================================
::  UI AND LOGGING
:: ==============================================================

:reset_counters
set /a OK_COUNT=0, INFO_COUNT=0, WARN_COUNT=0, ERR_COUNT=0, STAGE_NO=0
exit /b

:header
cls
echo.
echo    %C_ACC%╔══════════════════════════════════════════════════════════╗%C_RESET%
echo    %C_ACC%║%C_RESET%  %C_BOLD%%C_HI%WINDOWS TELEMETRY OFF%C_RESET%                           %C_SEC%v%APP_VERSION%%C_RESET%  %C_ACC%║%C_RESET%
if "%UI_LANG%"=="RU" (
    echo    %C_ACC%║%C_RESET%  %C_DIM%Приватность и отключение телеметрии Windows 10 / 11%C_RESET%     %C_ACC%║%C_RESET%
) else (
    echo    %C_ACC%║%C_RESET%  %C_DIM%Privacy and telemetry toolkit for Windows 10 / 11%C_RESET%       %C_ACC%║%C_RESET%
)
echo    %C_ACC%╚══════════════════════════════════════════════════════════╝%C_RESET%
echo.
exit /b

:: %1 = color variable name, %2 = RU text, %3 = EN text
:echo_tr
if "%UI_LANG%"=="RU" (set "TXT=%~2") else (set "TXT=%~3")
echo    !%~1!!TXT!%C_RESET%
exit /b

:write_line
set "LINE=%~1"
>>"%LOGFILE%" echo(!LINE!
exit /b

:init_log
> "%LOGFILE%" (
    echo ============================================================
    echo %APP_NAME% v%APP_VERSION%
    echo Date: %date% %time%
    echo Mode: %MODE_NAME%
    echo ============================================================
    echo.
)
exit /b

:: %1 = OK/INFO/WARN/ERR, %2 = RU text, %3 = EN text
:say
if "%UI_LANG%"=="RU" (set "MSG=%~2") else (set "MSG=%~3")
if "%~1"=="OK" (set "T_CLR=%C_OK%" & set "T_SYM=√ OK  " & set "T_LOG=[OK]  " & set /a OK_COUNT+=1)
if "%~1"=="INFO" (set "T_CLR=%C_INFO%" & set "T_SYM=• INFO" & set "T_LOG=[INFO]" & set /a INFO_COUNT+=1)
if "%~1"=="WARN" (set "T_CLR=%C_WARN%" & set "T_SYM=▲ WARN" & set "T_LOG=[WARN]" & set /a WARN_COUNT+=1)
if "%~1"=="ERR" (set "T_CLR=%C_ERR%" & set "T_SYM=× ERR " & set "T_LOG=[ERR] " & set /a ERR_COUNT+=1)
echo    !T_CLR!!T_SYM!%C_RESET%  %C_TXT%!MSG!%C_RESET%
call :write_line "!T_LOG! !MSG!"
exit /b

:: Progress line without counters
:note
if "%UI_LANG%"=="RU" (set "MSG=%~1") else (set "MSG=%~2")
echo    %C_ACC%›%C_RESET% %C_HI%!MSG!%C_RESET%
call :write_line "!MSG!"
exit /b

:: %1 = RU title, %2 = EN title; numbering is automatic
:stage
set /a STAGE_NO+=1
if "%UI_LANG%"=="RU" (set "MSG=%~1" & set "STG=ЭТАП !STAGE_NO!") else (set "MSG=%~2" & set "STG=STAGE !STAGE_NO!")
echo.
echo    %C_ACC%▌%C_RESET% %C_BOLD%%C_ACC%!STG!%C_RESET% %C_DIM%·%C_RESET% %C_BOLD%%C_HI%!MSG!%C_RESET%
echo.
call :write_line ""
call :write_line "[!STG!] !MSG!"
exit /b

:summary
if "%UI_LANG%"=="RU" (set "MSG=%~1") else (set "MSG=%~2")
echo.
echo    %C_ACC%════════════════════════════════════════════════════════════%C_RESET%
echo    %C_ACC%▌%C_RESET% %C_BOLD%%C_HI%!MSG!%C_RESET%
echo    %C_ACC%════════════════════════════════════════════════════════════%C_RESET%
echo.
echo    %C_OK%√ OK  %C_RESET% %C_BOLD%!OK_COUNT!%C_RESET%     %C_INFO%• INFO%C_RESET% %C_BOLD%!INFO_COUNT!%C_RESET%     %C_WARN%▲ WARN%C_RESET% %C_BOLD%!WARN_COUNT!%C_RESET%     %C_ERR%× ERR %C_RESET% %C_BOLD%!ERR_COUNT!%C_RESET%
echo.
call :echo_tr C_DIM "Лог: %LOGFILE%" "Log: %LOGFILE%"
call :write_line ""
call :write_line "!MSG!: OK=!OK_COUNT! INFO=!INFO_COUNT! WARN=!WARN_COUNT! ERR=!ERR_COUNT!"
exit /b

:: 0 = nothing to report, 1 = warnings, 2 = errors
:set_exit_code
set "RUN_CODE=0"
if !WARN_COUNT! GTR 0 set "RUN_CODE=1"
if !ERR_COUNT! GTR 0 set "RUN_CODE=2"
exit /b

:pause_here
if "%SILENT_MODE%"=="1" exit /b
echo.
if defined CLI_ACTION (
    call :echo_tr C_DIM "Нажмите любую клавишу для выхода..." "Press any key to exit..."
) else (
    call :echo_tr C_DIM "Нажмите любую клавишу для продолжения..." "Press any key to continue..."
)
pause >nul
exit /b

:: %1 = choice keys, %2 = RU prompt, %3 = EN prompt
:prompt
if "%UI_LANG%"=="RU" (set "TXT=%~2") else (set "TXT=%~3")
<nul set /p "=%C_RESET%   %C_ACC%›%C_RESET% %C_HI%!TXT!%C_RESET% "
choice /c %~1 /n
exit /b

:: ==============================================================
::  SYSTEM INFO
:: ==============================================================

:read_os_info
set "WIN_EDITION="
set "WIN_VER="
set "WIN_BUILD="
set "WIN_NAME=Windows 10"
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul ^| "%FIND%" "REG_"') do set "WIN_EDITION=%%B"
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v DisplayVersion 2^>nul ^| "%FIND%" "REG_"') do set "WIN_VER=%%B"
for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild 2^>nul ^| "%FIND%" "REG_"') do set "WIN_BUILD=%%B"
if not defined WIN_BUILD set "WIN_BUILD=0"
if !WIN_BUILD! GEQ 22000 set "WIN_NAME=Windows 11"

:: Diagnostic level 0 (Security) is honored only on these editions
set "TELEMETRY_ZERO="
for %%E in (Enterprise EnterpriseN EnterpriseS EnterpriseSN EnterpriseG EnterpriseGN Education EducationN IoTEnterprise IoTEnterpriseS IoTEnterpriseK ServerStandard ServerDatacenter ServerStandardCore ServerDatacenterCore ServerAzureEdition ServerTurbine) do (
    if /i "!WIN_EDITION!"=="%%E" set "TELEMETRY_ZERO=1"
)
set "TLVL=1"
if defined TELEMETRY_ZERO set "TLVL=0"
exit /b

:: One probe per run: logged-in user, Controlled Folder Access, pending reboot, NPU
:probe_environment
if defined ENV_PROBED exit /b
set "ENV_PROBED=1"
set "ENV_USER="
set "ENV_CFA="
set "ENV_REBOOT="
set "HAS_NPU="
:: No pipes inside the quoted command: cmd would pass the escape characters through to PowerShell
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$o=@(); try { $p = @(Get-CimInstance Win32_Process -ErrorAction Stop).Where({ $_.Name -eq 'explorer.exe' })[0]; if ($p) { $u = (Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction Stop).User; if ($u) { $o += 'ENV_USER=' + $u } } } catch {}; try { if ((Get-MpPreference -ErrorAction Stop).EnableControlledFolderAccess -ne 0) { $o += 'ENV_CFA=1' } } catch {}; foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')) { if (Test-Path $k) { $o += 'ENV_REBOOT=1'; break } }; try { if (@(Get-CimInstance Win32_PnPEntity -ErrorAction Stop).Where({ $_.PNPClass -eq 'ComputeAccelerator' }).Count -gt 0) { $o += 'HAS_NPU=1' } } catch {}; [string]::Join([char]10, $o)" 2^>nul`) do set "%%A=%%B"
exit /b

:check_environment
call :probe_environment
if defined ENV_USER if /i not "!ENV_USER!"=="%USERNAME%" (
    call :say WARN "Вход выполнен под !ENV_USER!, а скрипт работает от %USERNAME%: пользовательские настройки применятся к профилю %USERNAME%" "!ENV_USER! is signed in but the script runs as %USERNAME%: per-user settings will apply to the %USERNAME% profile"
)
if defined ENV_CFA (
    call :say WARN "Включён контролируемый доступ к папкам: часть изменений может быть заблокирована Defender" "Controlled folder access is on: Defender may block some changes"
)
if defined ENV_REBOOT (
    call :say WARN "Система ожидает перезагрузки: часть изменений может примениться не сразу" "A restart is pending: some changes may not take effect immediately"
)
exit /b

:detect_windows
call :read_os_info
if not defined WIN_EDITION (
    call :say WARN "Не удалось определить редакцию Windows" "Could not detect the Windows edition"
    exit /b
)
call :say INFO "Система: !WIN_NAME! !WIN_EDITION! !WIN_VER! (сборка !WIN_BUILD!)" "System: !WIN_NAME! !WIN_EDITION! !WIN_VER! (build !WIN_BUILD!)"
if defined TELEMETRY_ZERO (
    call :say INFO "Редакция поддерживает минимальный уровень телеметрии 0 (Security)" "Edition supports the minimum telemetry level 0 (Security)"
) else (
    call :say INFO "Редакция !WIN_EDITION! не поддерживает уровень 0: задаётся 1, отправку блокирует группа полной блокировки" "Edition !WIN_EDITION! does not support level 0: level 1 is set, upload is stopped by the full block group"
)
exit /b

:: ==============================================================
::  REGISTRY / SERVICE / TASK / FIREWALL HELPERS
:: ==============================================================

:: Records the current value before it is changed; first record wins
:: %1 key, %2 value
:snap_reg
if not "%SNAP_ON%"=="1" exit /b
set "SNAP_PFX=R|%~1|%~2|"
if exist "%STATEFILE%" findstr /i /b /c:"!SNAP_PFX!" "%STATEFILE%" >nul 2>&1 && exit /b
set "SNAP_T="
set "SNAP_D="
for /f "tokens=2,*" %%A in ('reg query "%~1" /v "%~2" 2^>nul ^| "%FIND%" "REG_"') do (
    set "SNAP_T=%%A"
    set "SNAP_D=%%B"
)
if not defined SNAP_T set "SNAP_T=@ABSENT@"
set "SNAP_LINE=!SNAP_PFX!!SNAP_T!|!SNAP_D!"
>>"%STATEFILE%" echo(!SNAP_LINE!
exit /b

:: %1 service
:snap_svc
if not "%SNAP_ON%"=="1" exit /b
set "SNAP_PFX=S|%~1|"
if exist "%STATEFILE%" findstr /i /b /c:"!SNAP_PFX!" "%STATEFILE%" >nul 2>&1 && exit /b
set "SNAP_T="
set "SNAP_D="
for /f "tokens=4,5" %%A in ('sc qc "%~1" 2^>nul ^| "%FIND%" "START_TYPE"') do (
    set "SNAP_T=%%A"
    set "SNAP_D=%%B"
)
if not defined SNAP_T exit /b
if /i "!SNAP_D!"=="(DELAYED)" set "SNAP_T=DELAYED_AUTO"
set "SNAP_LINE=!SNAP_PFX!!SNAP_T!"
>>"%STATEFILE%" echo(!SNAP_LINE!
exit /b

:: %1 task path, %2 current state
:snap_task
if not "%SNAP_ON%"=="1" exit /b
if "%~2"=="MISSING" exit /b
set "SNAP_PFX=T|%~1|"
if exist "%STATEFILE%" findstr /i /b /c:"!SNAP_PFX!" "%STATEFILE%" >nul 2>&1 && exit /b
set "SNAP_LINE=!SNAP_PFX!%~2"
>>"%STATEFILE%" echo(!SNAP_LINE!
exit /b

:: %1 rule suffix
:snap_fw
if not "%SNAP_ON%"=="1" exit /b
set "SNAP_PFX=F|%~1|"
if exist "%STATEFILE%" findstr /i /b /c:"!SNAP_PFX!" "%STATEFILE%" >nul 2>&1 && exit /b
set "SNAP_T=ABSENT"
netsh advfirewall firewall show rule name="Windows Telemetry OFF - %~1" >nul 2>&1 && set "SNAP_T=PRESENT"
set "SNAP_LINE=!SNAP_PFX!!SNAP_T!"
>>"%STATEFILE%" echo(!SNAP_LINE!
exit /b

:: %1 key, %2 value, %3 data, %4 RU text, %5 EN text
:reg_set
call :snap_reg "%~1" "%~2"
reg add "%~1" /v "%~2" /t REG_DWORD /d %~3 /f >nul 2>&1
if errorlevel 1 (call :say ERR "%~4" "%~5") else (call :say OK "%~4" "%~5")
exit /b

:: Keys guarded by the UCPD driver cannot be written by reg.exe, cmd.exe or powershell.exe
:reg_set_ucpd
call :snap_reg "%~1" "%~2"
reg add "%~1" /v "%~2" /t REG_DWORD /d %~3 /f >nul 2>&1
if errorlevel 1 (
    call :say WARN "%~4: Windows защищает этот ключ от скриптов, отключите вручную в Параметрах / Персонализация / Панель задач или удалите приложение Widgets" "%~5: Windows guards this key against scripts, turn it off in Settings / Personalization / Taskbar or remove the Widgets app"
) else (
    call :say OK "%~4" "%~5"
)
exit /b

:: Group-policy twin of a setting: written only when POLICY_MODE is on
:reg_set_pol
if "%POLICY_MODE%"=="1" call :reg_set %*
exit /b

:: %1 key, %2 value, %3 string data, %4 RU text, %5 EN text
:reg_set_sz
call :snap_reg "%~1" "%~2"
reg add "%~1" /v "%~2" /t REG_SZ /d "%~3" /f >nul 2>&1
if errorlevel 1 (call :say ERR "%~4" "%~5") else (call :say OK "%~4" "%~5")
exit /b

:: %1 key, %2 value; silently skips values that do not exist
:reg_del
reg query "%~1" /v "%~2" >nul 2>&1
if errorlevel 1 exit /b
call :snap_reg "%~1" "%~2"
for %%K in ("%~1") do set "LEAF=%%~nxK"
reg delete "%~1" /v "%~2" /f >nul 2>&1
if errorlevel 1 (
    call :say WARN "Не удалось удалить: !LEAF!\%~2" "Failed to remove: !LEAF!\%~2"
) else (
    call :say OK "Удалено: !LEAF!\%~2" "Removed: !LEAF!\%~2"
)
exit /b

:: %1 key, %2 value, %3 string data
:reg_restore_sz
for %%K in ("%~1") do set "LEAF=%%~nxK"
reg add "%~1" /v "%~2" /t REG_SZ /d "%~3" /f >nul 2>&1
if errorlevel 1 (
    call :say WARN "Не удалось восстановить: !LEAF!\%~2" "Failed to restore: !LEAF!\%~2"
) else (
    call :say OK "Восстановлено: !LEAF!\%~2 = %~3" "Restored: !LEAF!\%~2 = %~3"
)
exit /b

:: %1 key, %2 value, %3 data
:reg_restore
for %%K in ("%~1") do set "LEAF=%%~nxK"
reg add "%~1" /v "%~2" /t REG_DWORD /d %~3 /f >nul 2>&1
if errorlevel 1 (
    call :say WARN "Не удалось восстановить: !LEAF!\%~2" "Failed to restore: !LEAF!\%~2"
) else (
    call :say OK "Восстановлено: !LEAF!\%~2 = %~3" "Restored: !LEAF!\%~2 = %~3"
)
exit /b

:svc_start_type
set "SVC_START="
for /f "tokens=4" %%A in ('sc qc "%~1" 2^>nul ^| "%FIND%" "START_TYPE"') do set "SVC_START=%%A"
exit /b

:: %1 service, %2 label
:svc_disable
sc query "%~1" >nul 2>&1 || (call :say INFO "%~2: служба не найдена" "%~2: service not found" & exit /b)
call :snap_svc "%~1"
sc stop "%~1" >nul 2>&1
sc config "%~1" start= disabled >nul 2>&1
call :svc_start_type "%~1"
if /i "!SVC_START!"=="DISABLED" (
    call :say OK "%~2: отключена" "%~2: disabled"
) else (
    call :say WARN "%~2: не удалось отключить" "%~2: failed to disable"
)
exit /b

:: %1 service, %2 sc start mode (auto/demand), %3 expected START_TYPE, %4 label
:svc_restore
sc query "%~1" >nul 2>&1 || (call :say INFO "%~4: служба не найдена" "%~4: service not found" & exit /b)
sc config "%~1" start= %~2 >nul 2>&1
call :svc_start_type "%~1"
if /i "!SVC_START!"=="%~3" (
    call :say OK "%~4: тип запуска %~3" "%~4: start type %~3"
) else (
    call :say WARN "%~4: не удалось установить %~3" "%~4: failed to set %~3"
)
exit /b

:: Moves an auto-starting service to manual; %1 service, %2 RU label, %3 EN label
:svc_set_manual
sc query "%~1" >nul 2>&1 || exit /b
call :svc_start_type "%~1"
if /i not "!SVC_START!"=="AUTO_START" (
    call :say INFO "%~2: уже не запускается автоматически" "%~3: already not starting automatically"
    exit /b
)
call :snap_svc "%~1"
sc config "%~1" start= demand >nul 2>&1
call :svc_start_type "%~1"
if /i "!SVC_START!"=="DEMAND_START" (
    call :say OK "%~2: переведена в ручной запуск" "%~3: set to manual start"
) else (
    call :say WARN "%~2: не удалось перевести в ручной запуск" "%~3: failed to set manual start"
)
exit /b

:: Re-enables a service only if it was disabled; %1 service, %2 sc start mode, %3 label
:svc_ensure
sc query "%~1" >nul 2>&1 || exit /b
call :svc_start_type "%~1"
if /i not "!SVC_START!"=="DISABLED" (call :say OK "%~3: не отключена" "%~3: not disabled" & exit /b)
call :snap_svc "%~1"
sc config "%~1" start= %~2 >nul 2>&1
call :svc_start_type "%~1"
if /i "!SVC_START!"=="DISABLED" (
    call :say WARN "%~3: отключена, включить не удалось" "%~3: disabled, failed to re-enable"
) else (
    call :say OK "%~3: была отключена, включена обратно" "%~3: was disabled, re-enabled"
)
exit /b

:: Sets TASK_STATE to MISSING, ENABLED or DISABLED (language-neutral via XML)
:task_state
set "TASK_STATE=MISSING"
schtasks /query /tn "%~1" >nul 2>&1 || exit /b
set "TASK_STATE=ENABLED"
schtasks /query /tn "%~1" /xml 2>nul | findstr /b /c:"    <Enabled>false</Enabled>" >nul && set "TASK_STATE=DISABLED"
exit /b

:: %1 task path, %2 label
:task_disable
call :task_state "%~1"
if "!TASK_STATE!"=="MISSING" exit /b
if "!TASK_STATE!"=="DISABLED" (call :say OK "%~2: уже отключена" "%~2: already disabled" & exit /b)
call :snap_task "%~1" "!TASK_STATE!"
schtasks /change /tn "%~1" /disable >nul 2>&1
call :task_state "%~1"
if "!TASK_STATE!"=="DISABLED" (
    call :say OK "%~2: отключена" "%~2: disabled"
) else (
    call :say WARN "%~2: не удалось отключить (защищённая задача)" "%~2: failed to disable (protected task)"
)
exit /b

:task_enable
call :task_state "%~1"
if not "!TASK_STATE!"=="DISABLED" exit /b
schtasks /change /tn "%~1" /enable >nul 2>&1
call :task_state "%~1"
if "!TASK_STATE!"=="ENABLED" (
    call :say OK "%~2: включена" "%~2: enabled"
) else (
    call :say WARN "%~2: не удалось включить" "%~2: failed to enable"
)
exit /b

:: %1 rule suffix, %2 program path, %3 optional service name
:fw_block
call :snap_fw "%~1"
set "FW_NAME=Windows Telemetry OFF - %~1"
netsh advfirewall firewall delete rule name="%FW_NAME%" >nul 2>&1
if "%~3"=="" (
    netsh advfirewall firewall add rule name="%FW_NAME%" dir=out action=block program="%~2" enable=yes >nul 2>&1
) else (
    netsh advfirewall firewall add rule name="%FW_NAME%" dir=out action=block program="%~2" service="%~3" enable=yes >nul 2>&1
)
if errorlevel 1 (
    call :say WARN "Брандмауэр: не удалось создать правило для %~1 (служба брандмауэра отключена?)" "Firewall: failed to add a rule for %~1 (is the firewall service disabled?)"
) else (
    call :say OK "Брандмауэр: исходящий трафик %~1 заблокирован" "Firewall: outbound traffic of %~1 blocked"
)
exit /b

:fw_unblock
netsh advfirewall firewall show rule name="Windows Telemetry OFF - %~1" >nul 2>&1 || exit /b
netsh advfirewall firewall delete rule name="Windows Telemetry OFF - %~1" >nul 2>&1
if errorlevel 1 (
    call :say WARN "Брандмауэр: не удалось удалить правило %~1" "Firewall: failed to remove the %~1 rule"
) else (
    call :say OK "Брандмауэр: правило %~1 удалено" "Firewall: %~1 rule removed"
)
exit /b

:: ==============================================================
::  SYSTEM ACTIONS
:: ==============================================================

:create_restore_point
call :note "Создание точки восстановления системы..." "Creating a System Restore point..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "$k='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'; $n='SystemRestorePointCreationFrequency'; $old=(Get-ItemProperty -Path $k -Name $n -ErrorAction SilentlyContinue).$n; $r=1; try { Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction SilentlyContinue; New-ItemProperty -Path $k -Name $n -Value 0 -PropertyType DWord -Force | Out-Null; Checkpoint-Computer -Description 'Windows Telemetry OFF' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; $r=0 } catch { $r=1 } finally { if ($null -eq $old) { Remove-ItemProperty -Path $k -Name $n -ErrorAction SilentlyContinue } else { New-ItemProperty -Path $k -Name $n -Value $old -PropertyType DWord -Force | Out-Null } }; exit $r" >nul 2>&1
if errorlevel 1 (
    call :say WARN "Точка восстановления не создана (защита системы отключена или недоступна)" "Restore point was not created (System Protection is disabled or unavailable)"
) else (
    call :say OK "Точка восстановления создана" "Restore point created"
)
exit /b

:clear_dir
if not exist "%~1\" exit /b
del /f /q /s "%~1\*" >nul 2>&1
for /d %%D in ("%~1\*") do rd /s /q "%%D" >nul 2>&1
exit /b

:flush_telemetry_cache
call :note "Очистка кэша телеметрии и отчётов об ошибках..." "Flushing telemetry and error report cache..."
set "DIAG_WAS_RUNNING="
sc query DiagTrack 2>nul | "%FIND%" "RUNNING" >nul && set "DIAG_WAS_RUNNING=1"
sc stop DiagTrack >nul 2>&1
if defined DIAG_WAS_RUNNING timeout /t 2 /nobreak >nul
call :clear_dir "%ProgramData%\Microsoft\Diagnosis"
for %%W in ("%ProgramData%" "%LOCALAPPDATA%") do (
    for %%S in (ReportArchive ReportQueue Temp) do call :clear_dir "%%~W\Microsoft\Windows\WER\%%S"
)
if defined DIAG_WAS_RUNNING sc start DiagTrack >nul 2>&1
call :say OK "Кэш телеметрии и отчётов об ошибках очищен" "Telemetry and error report cache flushed"
exit /b

:block_telemetry_hosts
set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
findstr /c:"BEGIN WINDOWS TELEMETRY OFF" "%HOSTS%" >nul 2>&1 && (call :say OK "Блокировка в hosts уже активна" "Hosts block is already active" & exit /b)
attrib -r "%HOSTS%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$h=Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'; $d='v10.events.data.microsoft.com','v10c.events.data.microsoft.com','v20.events.data.microsoft.com','us-v10c.events.data.microsoft.com','eu-v10c.events.data.microsoft.com','self.events.data.microsoft.com','umwatson.events.data.microsoft.com','watson.events.data.microsoft.com','watson.telemetry.microsoft.com','oca.telemetry.microsoft.com','telecommand.telemetry.microsoft.com','vortex.data.microsoft.com','vortex-win.data.microsoft.com'; $nl=[Environment]::NewLine; $b=$nl + '# === BEGIN WINDOWS TELEMETRY OFF ===' + $nl + (($d | ForEach-Object { '0.0.0.0 ' + $_ }) -join $nl) + $nl + '# === END WINDOWS TELEMETRY OFF ===' + $nl; try { [IO.File]::AppendAllText($h, $b); if ([IO.File]::ReadAllText($h) -match 'BEGIN WINDOWS TELEMETRY OFF') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    call :say WARN "Не удалось изменить hosts (доступ заблокирован антивирусом)" "Failed to update hosts (access blocked by antivirus)"
    exit /b
)
ipconfig /flushdns >nul 2>&1
call :say OK "Серверы телеметрии заблокированы в hosts" "Telemetry endpoints blocked in hosts"
call :say INFO "Microsoft Defender может пометить изменение hosts как HostsFileHijack и откатить его" "Microsoft Defender may flag this hosts change as HostsFileHijack and revert it"
exit /b

:unblock_telemetry_hosts
set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
findstr /c:"BEGIN WINDOWS TELEMETRY OFF" "%HOSTS%" >nul 2>&1 || exit /b
attrib -r "%HOSTS%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$h=Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'; try { $c=[IO.File]::ReadAllText($h); $n=[regex]::Replace($c, '(?ms)\r?\n?# === BEGIN WINDOWS TELEMETRY OFF ===.*?# === END WINDOWS TELEMETRY OFF ===\r?\n?', [Environment]::NewLine); [IO.File]::WriteAllText($h, $n.TrimEnd() + [Environment]::NewLine); exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    call :say WARN "Не удалось удалить блокировку из hosts" "Failed to remove the hosts block"
) else (
    ipconfig /flushdns >nul 2>&1
    call :say OK "Блокировка серверов в hosts снята" "Hosts block removed"
)
exit /b

:post_execution_action
if "%SILENT_MODE%"=="1" exit /b
if defined CLI_ACTION exit /b
echo.
call :echo_tr C_HI "Дальнейшие действия:" "Next actions:"
echo.
if "%UI_LANG%"=="RU" (
    echo    %C_ACC%[1]%C_RESET%  %C_TXT%Перезапустить Проводник%C_RESET%
    echo    %C_WARN%[2]%C_RESET%  %C_TXT%Перезагрузить компьютер%C_RESET%
    echo    %C_DIM%[0]%C_RESET%  %C_TXT%Вернуться в главное меню%C_RESET%
) else (
    echo    %C_ACC%[1]%C_RESET%  %C_TXT%Restart Explorer%C_RESET%
    echo    %C_WARN%[2]%C_RESET%  %C_TXT%Restart the computer%C_RESET%
    echo    %C_DIM%[0]%C_RESET%  %C_TXT%Return to the main menu%C_RESET%
)
echo.
call :prompt 120 "Ваш выбор [1, 2, 0]:" "Your choice [1, 2, 0]:"
set "ACT_CHOICE=%errorlevel%"
if "%ACT_CHOICE%"=="1" goto :restart_explorer
if "%ACT_CHOICE%"=="2" goto :restart_computer
exit /b

:restart_explorer
:: Let Winlogon respawn the shell unelevated; start it manually only as a fallback
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 3 /nobreak >nul
tasklist /fi "imagename eq explorer.exe" 2>nul | "%FIND%" /i "explorer.exe" >nul || start "" explorer.exe
echo.
call :echo_tr C_OK "√ Проводник перезапущен" "√ Explorer restarted"
timeout /t 2 /nobreak >nul
exit /b

:restart_computer
echo.
call :echo_tr C_WARN "Компьютер будет перезагружен через 10 секунд (отмена: shutdown /a)" "Restarting in 10 seconds (cancel with: shutdown /a)"
shutdown /r /t 10 /c "Windows Telemetry OFF"
exit

:: ==============================================================
::  MAIN MENU
:: ==============================================================

:main_menu
set "MODE_ID="
call :header
if "%WIN_BUILD%"=="" call :read_os_info
if defined WIN_EDITION (
    call :echo_tr C_DIM "Система: !WIN_NAME! !WIN_EDITION! !WIN_VER! (сборка !WIN_BUILD!)" "System: !WIN_NAME! !WIN_EDITION! !WIN_VER! (build !WIN_BUILD!)"
    echo.
)
if "%UI_LANG%"=="RU" goto :main_menu_ru

echo    %C_ACC%What this utility does%C_RESET%
echo    %C_DIM%•%C_RESET% Reduces or fully blocks Windows diagnostic data upload
echo    %C_DIM%•%C_RESET% Turns off ads, tips, recommendations and activity collection
echo    %C_DIM%•%C_RESET% Disables telemetry services, tasks and PowerShell 7 telemetry
echo    %C_DIM%•%C_RESET% Audits the current state and restores defaults on demand
echo.
echo    %C_WARN%What it does NOT do%C_RESET%
echo    %C_DIM%•%C_RESET% Does not remove system components or Edge
echo    %C_DIM%•%C_RESET% Does not touch Store, OneDrive, Defender or security updates
echo.
echo    %C_BOLD%%C_HI%Select an option%C_RESET%
echo.
echo    %C_SAFE%[1]%C_RESET%  %C_BOLD%%C_SAFE%Safe%C_RESET%        %C_DIM%Basic telemetry, ads, tips, PowerShell 7%C_RESET%
echo    %C_BAL%[2]%C_RESET%  %C_BOLD%%C_BAL%Balanced%C_RESET%    %C_DIM%Safe + services, tasks, cache flush%C_RESET%
echo    %C_PRO%[3]%C_RESET%  %C_BOLD%%C_PRO%Pro%C_RESET%         %C_DIM%Balanced + full upload block, AI, WER, Edge, hosts%C_RESET%
echo    %C_CUS%[8]%C_RESET%  %C_BOLD%%C_CUS%Custom%C_RESET%      %C_DIM%Choose exactly what to disable%C_RESET%
echo.
echo    %C_SEC%[9]%C_RESET%  %C_TXT%Windows Update: security updates only%C_RESET%
echo.
echo    %C_ACC%[4]%C_RESET%  %C_TXT%Check current privacy state%C_RESET%
echo    %C_WARN%[5]%C_RESET%  %C_TXT%Restore default settings%C_RESET%
echo    %C_ACC%[6]%C_RESET%  %C_TXT%Flush telemetry and error report cache%C_RESET%
echo    %C_SEC%[7]%C_RESET%  %C_TXT%Сменить язык / Change language%C_RESET%
echo    %C_DIM%[0]%C_RESET%  %C_TXT%Exit%C_RESET%
echo.
goto :main_menu_process

:main_menu_ru
echo    %C_ACC%Что делает утилита%C_RESET%
echo    %C_DIM%•%C_RESET% Уменьшает или полностью блокирует отправку диагностических данных
echo    %C_DIM%•%C_RESET% Отключает рекламу, советы, рекомендации и сбор активности
echo    %C_DIM%•%C_RESET% Отключает службы и задачи телеметрии, телеметрию PowerShell 7
echo    %C_DIM%•%C_RESET% Проверяет текущее состояние и восстанавливает настройки по умолчанию
echo.
echo    %C_WARN%Чего утилита НЕ делает%C_RESET%
echo    %C_DIM%•%C_RESET% Не удаляет системные компоненты и Edge
echo    %C_DIM%•%C_RESET% Не трогает Store, OneDrive, Defender и обновления безопасности
echo.
echo    %C_BOLD%%C_HI%Выберите действие%C_RESET%
echo.
echo    %C_SAFE%[1]%C_RESET%  %C_BOLD%%C_SAFE%Safe%C_RESET%        %C_DIM%Базовая телеметрия, реклама, советы, PowerShell 7%C_RESET%
echo    %C_BAL%[2]%C_RESET%  %C_BOLD%%C_BAL%Balanced%C_RESET%    %C_DIM%Safe + службы, задачи, очистка кэша%C_RESET%
echo    %C_PRO%[3]%C_RESET%  %C_BOLD%%C_PRO%Pro%C_RESET%         %C_DIM%Balanced + полная блокировка отправки, AI, WER, Edge, hosts%C_RESET%
echo    %C_CUS%[8]%C_RESET%  %C_BOLD%%C_CUS%Custom%C_RESET%      %C_DIM%Выбрать, что именно отключать%C_RESET%
echo.
echo    %C_SEC%[9]%C_RESET%  %C_TXT%Windows Update: только обновления безопасности%C_RESET%
echo.
echo    %C_ACC%[4]%C_RESET%  %C_TXT%Проверить текущее состояние%C_RESET%
echo    %C_WARN%[5]%C_RESET%  %C_TXT%Восстановить стандартные настройки%C_RESET%
echo    %C_ACC%[6]%C_RESET%  %C_TXT%Очистить кэш телеметрии и отчётов%C_RESET%
echo    %C_SEC%[7]%C_RESET%  %C_TXT%Сменить язык / Change language%C_RESET%
echo    %C_DIM%[0]%C_RESET%  %C_TXT%Выход%C_RESET%
echo.

:main_menu_process
call :prompt 1234567890 "Ваш выбор [0-9]:" "Your choice [0-9]:"
set "MC=%errorlevel%"
if "%MC%"=="1" (set "MODE_ID=SAFE" & set "MODE_NAME=Safe" & goto :confirm_safe)
if "%MC%"=="2" (set "MODE_ID=BALANCED" & set "MODE_NAME=Balanced" & goto :confirm_balanced)
if "%MC%"=="3" (set "MODE_ID=PRO" & set "MODE_NAME=Pro" & goto :confirm_pro)
if "%MC%"=="4" goto :quick_check
if "%MC%"=="5" goto :confirm_restore
if "%MC%"=="6" goto :run_flush_standalone
if "%MC%"=="7" goto :lang_selection
if "%MC%"=="8" goto :custom_menu
if "%MC%"=="9" goto :confirm_updates
if "%MC%"=="10" exit /b 0
goto :main_menu

:: %errorlevel% 1-2 = yes, 3-4 = no
:confirm_prompt
echo.
if "%UI_LANG%"=="RU" (
    echo    %C_OK%[1]%C_RESET%  %C_TXT%Запустить%C_RESET%
    echo    %C_DIM%[0]%C_RESET%  %C_TXT%Вернуться в главное меню%C_RESET%
) else (
    echo    %C_OK%[1]%C_RESET%  %C_TXT%Start%C_RESET%
    echo    %C_DIM%[0]%C_RESET%  %C_TXT%Return to the main menu%C_RESET%
)
echo.
call :prompt 1Y0N "Ваш выбор [1, 0]:" "Your choice [1, 0]:"
exit /b

:confirm_safe
call :header
if "%UI_LANG%"=="RU" goto :confirm_safe_ru
echo    %C_BOLD%%C_SAFE%Safe profile%C_RESET%
echo.
echo    %C_ACC%Will be applied:%C_RESET%
echo    %C_DIM%•%C_RESET% System Restore point
echo    %C_DIM%•%C_RESET% Minimum diagnostic data level allowed by your edition
echo    %C_DIM%•%C_RESET% No device name, extra logs, dumps, app launch or typing data
echo    %C_DIM%•%C_RESET% PowerShell 7 telemetry opt-out (if installed)
echo    %C_DIM%•%C_RESET% Advertising ID, tailored experiences, activity history off
echo    %C_DIM%•%C_RESET% Tips, suggestions, silent app installs and feedback prompts off
echo    %C_DIM%•%C_RESET% Bing web results, search highlights and Widgets off
echo.
echo    %C_DIM%Recommended for most users. Nothing functional is disabled.%C_RESET%
echo    %C_DIM%Applied as ordinary Windows settings: the toggles in Settings stay usable.%C_RESET%
goto :confirm_safe_ask
:confirm_safe_ru
echo    %C_BOLD%%C_SAFE%Режим Safe%C_RESET%
echo.
echo    %C_ACC%Будет выполнено:%C_RESET%
echo    %C_DIM%•%C_RESET% Точка восстановления системы
echo    %C_DIM%•%C_RESET% Минимальный уровень диагностических данных для вашей редакции
echo    %C_DIM%•%C_RESET% Запрет передачи имени устройства, доп. логов, дампов, запусков приложений и ввода
echo    %C_DIM%•%C_RESET% Отключение телеметрии PowerShell 7 (если установлен)
echo    %C_DIM%•%C_RESET% Отключение рекламного ID, персонализации и истории активности
echo    %C_DIM%•%C_RESET% Отключение советов, предложений, тихой установки приложений и feedback
echo    %C_DIM%•%C_RESET% Отключение веб-результатов Bing, Search Highlights и Widgets
echo.
echo    %C_DIM%Подходит большинству пользователей. Функциональность не затрагивается.%C_RESET%
echo    %C_DIM%Применяется как обычные настройки Windows: переключатели в «Параметрах» остаются доступны.%C_RESET%
:confirm_safe_ask
call :confirm_prompt
if errorlevel 3 goto :main_menu
goto :run_mode

:confirm_balanced
call :header
if "%UI_LANG%"=="RU" goto :confirm_balanced_ru
echo    %C_BOLD%%C_BAL%Balanced profile%C_RESET%
echo.
echo    %C_ACC%Everything from Safe, plus:%C_RESET%
echo    %C_DIM%•%C_RESET% DiagTrack and dmwappushservice services disabled
echo    %C_DIM%•%C_RESET% CEIP, Compatibility Appraiser and diagnostic tasks disabled
echo    %C_DIM%•%C_RESET% Application inventory collection disabled
echo    %C_DIM%•%C_RESET% Accumulated telemetry and error report cache flushed
echo.
echo    %C_WARN%Note:%C_RESET% %C_DIM%Windows Update may detect feature update compatibility later.%C_RESET%
goto :confirm_balanced_ask
:confirm_balanced_ru
echo    %C_BOLD%%C_BAL%Режим Balanced%C_RESET%
echo.
echo    %C_ACC%Всё из Safe, а также:%C_RESET%
echo    %C_DIM%•%C_RESET% Отключение служб DiagTrack и dmwappushservice
echo    %C_DIM%•%C_RESET% Отключение задач CEIP, Compatibility Appraiser и диагностики
echo    %C_DIM%•%C_RESET% Отключение сбора инвентаризации приложений
echo    %C_DIM%•%C_RESET% Очистка накопленного кэша телеметрии и отчётов
echo.
echo    %C_WARN%Важно:%C_RESET% %C_DIM%проверка совместимости крупных обновлений может выполняться позже.%C_RESET%
:confirm_balanced_ask
call :confirm_prompt
if errorlevel 3 goto :main_menu
goto :run_mode

:confirm_pro
call :header
if "%UI_LANG%"=="RU" goto :confirm_pro_ru
echo    %C_BOLD%%C_PRO%Pro profile%C_RESET%
echo.
echo    %C_ACC%Everything from Balanced, plus:%C_RESET%
echo    %C_DIM%•%C_RESET% Full diagnostic data upload block, also on Pro and Home:
echo      %C_DIM%DiagTrack autologger, firewall rules for DiagTrack, CompatTelRunner, DeviceCensus,%C_RESET%
echo      %C_DIM%OneSettings, CEIP, commercial data pipeline, Flighting usage reporting tasks%C_RESET%
echo    %C_DIM%•%C_RESET% Recall, Click to Do and legacy Copilot policies
echo    %C_DIM%•%C_RESET% Windows Error Reporting (policies and WerSvc)
echo    %C_DIM%•%C_RESET% Input personalization, online speech recognition
echo    %C_DIM%•%C_RESET% Spotlight, cross-device features
echo    %C_DIM%•%C_RESET% Microsoft Edge diagnostic and background policies
echo    %C_DIM%•%C_RESET% Location, camera and microphone access for apps blocked
echo    %C_DIM%•%C_RESET% Cloud push notifications disabled
echo    %C_DIM%•%C_RESET% Telemetry endpoints blocked in the hosts file
echo.
echo    %C_WARN%Side effects:%C_RESET%
echo    %C_WARN%▲%C_RESET% Store apps lose camera/microphone: Camera app, new Teams, WhatsApp
echo    %C_WARN%▲%C_RESET% No location: weather, maps, automatic time zone, Find my device
echo    %C_WARN%▲%C_RESET% No push notifications from Store apps (Mail, Calendar, messengers)
echo    %C_WARN%▲%C_RESET% Phone Link, Nearby Sharing and clipboard sync stop working
echo    %C_WARN%▲%C_RESET% Voice typing (Win+H) and online speech recognition stop working
echo    %C_WARN%▲%C_RESET% Gradual feature rollouts and remote configuration may not arrive
echo    %C_WARN%▲%C_RESET% Settings are enforced by group policies: matching toggles in Settings turn grey
echo    %C_WARN%▲%C_RESET% Edge shows "Managed by your organization"
echo    %C_WARN%▲%C_RESET% Defender may revert the hosts file change
goto :confirm_pro_ask
:confirm_pro_ru
echo    %C_BOLD%%C_PRO%Режим Pro%C_RESET%
echo.
echo    %C_ACC%Всё из Balanced, а также:%C_RESET%
echo    %C_DIM%•%C_RESET% Полная блокировка отправки диагностических данных, в том числе на Pro и Home:
echo      %C_DIM%автологгер DiagTrack, правила брандмауэра для DiagTrack, CompatTelRunner, DeviceCensus,%C_RESET%
echo      %C_DIM%OneSettings, CEIP, коммерческий конвейер данных, задачи Flighting usage reporting%C_RESET%
echo    %C_DIM%•%C_RESET% Политики Recall, Click to Do и устаревшего Copilot
echo    %C_DIM%•%C_RESET% Отключение отчётов об ошибках (политики и служба WerSvc)
echo    %C_DIM%•%C_RESET% Персонализация ввода, онлайн-распознавание речи
echo    %C_DIM%•%C_RESET% Spotlight, функции между устройствами
echo    %C_DIM%•%C_RESET% Политики диагностики и фоновой работы Microsoft Edge
echo    %C_DIM%•%C_RESET% Запрет доступа приложений к геолокации, камере и микрофону
echo    %C_DIM%•%C_RESET% Отключение облачных push-уведомлений
echo    %C_DIM%•%C_RESET% Блокировка серверов телеметрии в файле hosts
echo.
echo    %C_WARN%Побочные эффекты:%C_RESET%
echo    %C_WARN%▲%C_RESET% Приложения Store теряют камеру и микрофон: «Камера», новый Teams, WhatsApp
echo    %C_WARN%▲%C_RESET% Нет геолокации: погода, карты, автоматический часовой пояс, поиск устройства
echo    %C_WARN%▲%C_RESET% Нет push-уведомлений от приложений Store (Почта, Календарь, мессенджеры)
echo    %C_WARN%▲%C_RESET% Перестают работать «Связь с телефоном», обмен с устройствами и синхронизация буфера
echo    %C_WARN%▲%C_RESET% Перестают работать голосовой ввод (Win+H) и онлайн-распознавание речи
echo    %C_WARN%▲%C_RESET% Постепенно выкатываемые функции и удалённая конфигурация могут не приходить
echo    %C_WARN%▲%C_RESET% Настройки закрепляются групповыми политиками: соответствующие переключатели в «Параметрах» станут серыми
echo    %C_WARN%▲%C_RESET% Edge показывает «Управляется вашей организацией»
echo    %C_WARN%▲%C_RESET% Defender может откатить изменение файла hosts
:confirm_pro_ask
call :confirm_prompt
if errorlevel 3 goto :main_menu
goto :run_mode

:confirm_restore
call :header
if "%UI_LANG%"=="RU" goto :confirm_restore_ru
echo    %C_BOLD%%C_WARN%Restore default settings%C_RESET%
echo.
echo    %C_ACC%Will be performed:%C_RESET%
echo    %C_DIM%•%C_RESET% System Restore point
echo    %C_DIM%•%C_RESET% Exact restore of the values captured before they were changed
echo    %C_DIM%•%C_RESET% Removal of all policies set by any version of this utility
echo    %C_DIM%•%C_RESET% Hosts file block and firewall rules removed
echo    %C_DIM%•%C_RESET% PowerShell 7 telemetry opt-out removed
echo    %C_DIM%•%C_RESET% Windows Update version pinning and update restrictions removed
echo    %C_DIM%•%C_RESET% Services and DiagTrack autologger returned to Windows defaults
echo    %C_DIM%•%C_RESET% Scheduled tasks re-enabled
echo.
echo    %C_WARN%Note:%C_RESET% %C_DIM%personal settings changed before the utility ran are not restored.%C_RESET%
goto :confirm_restore_ask
:confirm_restore_ru
echo    %C_BOLD%%C_WARN%Восстановление стандартных настроек%C_RESET%
echo.
echo    %C_ACC%Будет выполнено:%C_RESET%
echo    %C_DIM%•%C_RESET% Точка восстановления системы
echo    %C_DIM%•%C_RESET% Точный возврат значений, сохранённых перед изменением
echo    %C_DIM%•%C_RESET% Удаление всех политик, заданных любой версией утилиты
echo    %C_DIM%•%C_RESET% Снятие блокировки в hosts и удаление правил брандмауэра
echo    %C_DIM%•%C_RESET% Отмена отключения телеметрии PowerShell 7
echo    %C_DIM%•%C_RESET% Снятие закрепления версии и ограничений Windows Update
echo    %C_DIM%•%C_RESET% Возврат служб и автологгера DiagTrack к значениям Windows по умолчанию
echo    %C_DIM%•%C_RESET% Повторное включение задач планировщика
echo.
echo    %C_WARN%Важно:%C_RESET% %C_DIM%личные настройки, изменённые до запуска утилиты, не восстанавливаются.%C_RESET%
:confirm_restore_ask
call :confirm_prompt
if errorlevel 3 goto :main_menu
goto :run_restore

:confirm_updates
call :header
if "%UI_LANG%"=="RU" goto :confirm_updates_ru
echo    %C_BOLD%%C_SEC%Windows Update: security updates only%C_RESET%
echo.
echo    %C_ACC%Will be applied:%C_RESET%
echo    %C_DIM%•%C_RESET% Windows version pinned, newer versions (feature updates) are blocked
echo    %C_DIM%•%C_RESET% If support for the current version ends sooner, one update to %WU_TARGET_WIN11% first
echo    %C_DIM%•%C_RESET% Optional and preview updates, new features from monthly updates off
echo    %C_DIM%•%C_RESET% Drivers via Windows Update and updates for other Microsoft products off
echo    %C_DIM%•%C_RESET% Microsoft Store automatic app updates off
echo    %C_DIM%•%C_RESET% Update, BITS, Delivery Optimization and Store services re-enabled if disabled
echo.
echo    %C_OK%Keeps working:%C_RESET%
echo    %C_OK%√%C_RESET% Monthly security updates and Microsoft Defender definitions
echo    %C_OK%√%C_RESET% winget, Microsoft Store and other package managers
echo.
echo    %C_WARN%Note:%C_RESET%
echo    %C_WARN%▲%C_RESET% The monthly cumulative update contains security and regular fixes together
echo    %C_WARN%▲%C_RESET% Each version gets security updates only until its end of servicing:
echo      %C_DIM%after a new Windows release, change WU_TARGET_WIN11 at the top of the script and run this again%C_RESET%
echo    %C_WARN%▲%C_RESET% Apps from Microsoft Store are updated manually: winget upgrade --all
goto :confirm_updates_ask
:confirm_updates_ru
echo    %C_BOLD%%C_SEC%Windows Update: только обновления безопасности%C_RESET%
echo.
echo    %C_ACC%Будет выполнено:%C_RESET%
echo    %C_DIM%•%C_RESET% Закрепление версии Windows, новые версии (обновления функций) не устанавливаются
echo    %C_DIM%•%C_RESET% Если поддержка текущей версии заканчивается раньше, сначала одно обновление до %WU_TARGET_WIN11%
echo    %C_DIM%•%C_RESET% Отключение необязательных и предварительных обновлений, новых функций из ежемесячных обновлений
echo    %C_DIM%•%C_RESET% Отключение драйверов через Windows Update и обновлений других продуктов Microsoft
echo    %C_DIM%•%C_RESET% Отключение автообновления приложений Microsoft Store
echo    %C_DIM%•%C_RESET% Включение служб обновления, BITS, оптимизации доставки и Store, если они отключены
echo.
echo    %C_OK%Продолжает работать:%C_RESET%
echo    %C_OK%√%C_RESET% Ежемесячные обновления безопасности и определения Microsoft Defender
echo    %C_OK%√%C_RESET% winget, Microsoft Store и другие менеджеры пакетов
echo.
echo    %C_WARN%Важно:%C_RESET%
echo    %C_WARN%▲%C_RESET% Ежемесячное накопительное обновление содержит исправления безопасности и обычные исправления вместе
echo    %C_WARN%▲%C_RESET% Каждая версия получает обновления безопасности только до окончания её поддержки:
echo      %C_DIM%после выхода новой версии Windows измените WU_TARGET_WIN11 в начале скрипта и запустите пункт снова%C_RESET%
echo    %C_WARN%▲%C_RESET% Приложения из Microsoft Store обновляются вручную: winget upgrade --all
:confirm_updates_ask
call :confirm_prompt
if errorlevel 3 goto :main_menu

:run_updates
set "MODE_ID=UPDATES"
if "%UI_LANG%"=="RU" (set "MODE_NAME=Windows Update: только безопасность") else (set "MODE_NAME=Windows Update: security only")
goto :run_mode

:: ==============================================================
::  CUSTOM MODE
:: ==============================================================

:: %1 group number, %2 key, %3 RU label, %4 EN label, %5 R = has side effects
:custom_item
if "%UI_LANG%"=="RU" (set "TXT=%~3") else (set "TXT=%~4")
if "!G%~1!"=="1" (set "BOX=%C_OK%[√]%C_RESET%") else (set "BOX=%C_DIM%[ ]%C_RESET%")
set "MARK="
if /i "%~5"=="R" set "MARK= %C_WARN%▲%C_RESET%"
echo    %C_CUS%%~2%C_RESET%  !BOX!  %C_TXT%!TXT!%C_RESET%!MARK!
exit /b

:custom_menu
if not defined CUSTOM_INIT (
    set "MODE_ID=SAFE"
    call :profile_flags
    set "CUSTOM_INIT=1"
)
call :header
if "%UI_LANG%"=="RU" (
    echo    %C_BOLD%%C_CUS%Режим Custom%C_RESET%  %C_DIM%нажимайте клавиши, чтобы включать и выключать пункты%C_RESET%
) else (
    echo    %C_BOLD%%C_CUS%Custom mode%C_RESET%  %C_DIM%press keys to toggle items%C_RESET%
)
echo.
call :custom_item 1 1 "Уровень телеметрии и ограничения диагностики" "Telemetry level and diagnostic limits"
call :custom_item 2 2 "Полная блокировка отправки данных (автологгер, брандмауэр, OneSettings)" "Full upload block (autologger, firewall, OneSettings)" R
call :custom_item 3 3 "Телеметрия PowerShell 7" "PowerShell 7 telemetry"
call :custom_item 4 4 "Реклама, советы и предложения" "Ads, tips and suggestions"
call :custom_item 5 5 "История активности и запросы отзывов" "Activity history and feedback"
call :custom_item 6 6 "Bing и веб-результаты в поиске" "Bing and web results in search"
call :custom_item 7 7 "Widgets и новости" "Widgets and news"
call :custom_item 8 8 "Службы DiagTrack и dmwappushservice" "DiagTrack and dmwappushservice services"
call :custom_item 9 9 "Задачи телеметрии и инвентаризация приложений" "Telemetry tasks and app inventory"
call :custom_item 10 A "Recall, Click to Do, Copilot" "Recall, Click to Do, Copilot"
call :custom_item 11 B "Отчёты об ошибках (WER)" "Windows Error Reporting"
call :custom_item 12 C "Персонализация ввода и онлайн-распознавание речи" "Input personalization and online speech" R
call :custom_item 13 D "Spotlight и функции между устройствами" "Spotlight and cross-device features" R
call :custom_item 14 E "Геолокация" "Location services" R
call :custom_item 15 F "Камера и микрофон для приложений" "Camera and microphone for apps" R
call :custom_item 16 G "Облачные push-уведомления" "Cloud push notifications" R
call :custom_item 17 H "Политики Microsoft Edge" "Microsoft Edge policies" R
call :custom_item 18 I "Блокировка серверов в hosts" "Hosts file endpoint block" R
call :custom_item 19 J "Очистка кэша телеметрии" "Flush telemetry cache"
call :custom_item 21 L "Телеметрия приложений: Office и .NET" "Application telemetry: Office and .NET"
call :custom_item 20 K "Windows Update: только обновления безопасности" "Windows Update: security updates only" R
call :custom_item 22 M "Удалить предустановленные приложения" "Remove pre-installed apps" R
echo.
if "%POLICY_MODE%"=="1" (set "PBOX=%C_OK%[√]%C_RESET%") else (set "PBOX=%C_DIM%[ ]%C_RESET%")
if "%UI_LANG%"=="RU" (
    echo    %C_CUS%P%C_RESET%  !PBOX!  %C_TXT%Закреплять настройки групповыми политиками%C_RESET% %C_DIM%^(надёжнее, но переключатели в «Параметрах» станут серыми^)%C_RESET%
    echo.
    echo    %C_WARN%▲%C_RESET% %C_DIM%есть побочные эффекты, см. описание режима Pro%C_RESET%
    echo.
    echo    %C_OK%[S]%C_RESET%  %C_TXT%Запустить выбранное%C_RESET%     %C_ACC%[X]%C_RESET%  %C_TXT%Выбрать всё / снять всё%C_RESET%     %C_SEC%[W]%C_RESET%  %C_TXT%Сохранить выбор%C_RESET%     %C_DIM%[0]%C_RESET%  %C_TXT%Назад%C_RESET%
) else (
    echo    %C_CUS%P%C_RESET%  !PBOX!  %C_TXT%Enforce settings with group policies%C_RESET% %C_DIM%^(stronger, but Settings toggles turn grey^)%C_RESET%
    echo.
    echo    %C_WARN%▲%C_RESET% %C_DIM%has side effects, see the Pro profile description%C_RESET%
    echo.
    echo    %C_OK%[S]%C_RESET%  %C_TXT%Start selected%C_RESET%     %C_ACC%[X]%C_RESET%  %C_TXT%Select all / none%C_RESET%     %C_SEC%[W]%C_RESET%  %C_TXT%Save selection%C_RESET%     %C_DIM%[0]%C_RESET%  %C_TXT%Back%C_RESET%
)
echo.
call :prompt 123456789ABCDEFGHIJKLMPWSX0 "Клавиша:" "Key:"
set "CC=%errorlevel%"
if %CC% LEQ %GROUP_COUNT% (
    if "!G%CC%!"=="1" (set "G%CC%=0") else (set "G%CC%=1")
    goto :custom_menu
)
if %CC% EQU 27 goto :main_menu
if %CC% EQU 26 goto :custom_toggle_all
if %CC% EQU 24 (
    call :save_config
    call :pause_here
    goto :custom_menu
)
if %CC% EQU 23 (
    if "%POLICY_MODE%"=="1" (set "POLICY_MODE=0") else (set "POLICY_MODE=1")
    goto :custom_menu
)
set "ANY="
for /l %%i in (1,1,%GROUP_COUNT%) do if "!G%%i!"=="1" set "ANY=1"
if not defined ANY goto :custom_menu
set "MODE_ID=CUSTOM"
set "MODE_NAME=Custom"
goto :run_selected

:save_config
for %%F in ("%LOGFILE%") do set "CFGFILE=%%~dpFWindows-Telemetry-OFF.cfg"
> "%CFGFILE%" (
    echo # Windows Telemetry OFF selection
    echo # 1 = apply, 0 = skip
    echo POLICY_MODE=!POLICY_MODE!
)
for /l %%i in (1,1,%GROUP_COUNT%) do >>"%CFGFILE%" echo G%%i=!G%%i!
call :say OK "Выбор сохранён: %CFGFILE%" "Selection saved: %CFGFILE%"
exit /b

:load_config
set "CFG_OK="
if not exist "%CFGFILE%" (
    call :say ERR "Файл конфигурации не найден: %CFGFILE%" "Configuration file not found: %CFGFILE%"
    exit /b
)
for /l %%i in (1,1,%GROUP_COUNT%) do set "G%%i=0"
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%CFGFILE%") do set "%%A=%%B"
set "CFG_OK=1"
exit /b

:custom_toggle_all
set "ALL=1"
for /l %%i in (1,1,%GROUP_COUNT%) do if not "!G%%i!"=="1" set "ALL="
set "NEW=1"
if defined ALL set "NEW=0"
for /l %%i in (1,1,%GROUP_COUNT%) do set "G%%i=%NEW%"
goto :custom_menu

:: ==============================================================
::  PROFILES
:: ==============================================================

:: Maps MODE_ID to group flags; profiles never include the Windows Update group
:profile_flags
for /l %%i in (1,1,%GROUP_COUNT%) do set "G%%i=0"
if /i "%MODE_ID%"=="UPDATES" (set "G20=1" & set "POLICY_MODE=1" & exit /b)
set "POLICY_MODE=0"
for %%i in (1 3 4 5 6 7 21) do set "G%%i=1"
if /i "%MODE_ID%"=="SAFE" exit /b
for %%i in (8 9 19) do set "G%%i=1"
if /i "%MODE_ID%"=="BALANCED" exit /b
set "POLICY_MODE=1"
for /l %%i in (1,1,%PROFILE_GROUPS%) do set "G%%i=1"
set "G21=1"
exit /b

:run_mode
call :profile_flags

:run_selected
set "SNAP_ON=1"
call :reset_counters
call :init_log
call :header
call :note "Запуск режима: %MODE_NAME%" "Starting profile: %MODE_NAME%"
echo.
call :detect_windows
call :check_environment
call :create_restore_point
if "!G1!"=="1" call :grp_telemetry
if "!G2!"=="1" call :grp_telemetry_full
if "!G3!"=="1" call :grp_pwsh
if "!G4!"=="1" call :grp_ads
if "!G5!"=="1" call :grp_activity
if "!G6!"=="1" call :grp_search
if "!G7!"=="1" call :grp_widgets
if "!G8!"=="1" call :grp_services
if "!G9!"=="1" call :grp_tasks
if "!G10!"=="1" call :grp_ai
if "!G11!"=="1" call :grp_wer
if "!G12!"=="1" call :grp_input
if "!G13!"=="1" call :grp_spotlight
if "!G14!"=="1" call :grp_location
if "!G15!"=="1" call :grp_app_access
if "!G16!"=="1" call :grp_push
if "!G17!"=="1" call :grp_edge
if "!G18!"=="1" call :grp_hosts
if "!G19!"=="1" call :grp_flush
if "!G21!"=="1" call :grp_apptelemetry
if "!G22!"=="1" call :grp_appremove
if "!G20!"=="1" call :grp_updates
call :summary "Готово" "Finished"
call :echo_tr C_WARN "Перезагрузите компьютер, чтобы изменения применились полностью." "Restart the computer for all changes to take effect."
call :echo_tr C_DIM "Крупные обновления Windows могут вернуть часть настроек." "Major Windows updates may revert some settings."
call :post_execution_action
if defined CLI_ACTION (
    call :pause_here
    call :set_exit_code
    exit /b !RUN_CODE!
)
goto :main_menu

:grp_telemetry
call :stage "Уровень телеметрии и ограничения диагностики" "Telemetry level and diagnostic limits"
call :reg_set "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" !TLVL! "Уровень телеметрии: !TLVL!" "Telemetry level: !TLVL!"
call :reg_set "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "MaxTelemetryAllowed" !TLVL! "Максимальный уровень телеметрии: !TLVL!" "Maximum telemetry level: !TLVL!"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "ShowedToastAtLevel" !TLVL! "Уровень диагностики в интерфейсе согласован" "Diagnostics level shown in Settings kept in sync"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" !TLVL! "Уровень телеметрии закреплён политикой" "Telemetry level enforced by policy"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowDeviceNameInTelemetry" 0 "Имя устройства не передаётся в телеметрии" "Device name excluded from telemetry"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitDiagnosticLogCollection" 1 "Сбор дополнительных диагностических логов ограничен" "Additional diagnostic log collection limited"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitDumpCollection" 1 "Сбор дампов памяти ограничен" "Memory dump collection limited"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0 "Персонализированные предложения отключены" "Tailored experiences disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0 "Отслеживание запуска приложений отключено" "App launch tracking disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Input\TIPC" "Enabled" 0 "Отправка данных для улучшения ввода отключена" "Inking and typing improvement data disabled"
call :reg_set "HKCU\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 1 "Список языков не передаётся сайтам" "Websites no longer receive your language list"
exit /b

:grp_telemetry_full
call :stage "Полная блокировка отправки диагностических данных" "Full diagnostic data upload block"
set "AL=HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener"
reg query "%AL%" >nul 2>&1
if errorlevel 1 (
    call :say INFO "Автологгер DiagTrack отсутствует в этой сборке Windows, шаг пропущен" "The DiagTrack autologger does not exist in this Windows build, skipped"
) else (
    call :reg_set "%AL%" "Start" 0 "Автологгер DiagTrack отключён" "DiagTrack autologger disabled"
)
call :reg_set "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "MaxTelemetryAllowed" !TLVL! "Максимальный уровень телеметрии: !TLVL!" "Maximum telemetry level: !TLVL!"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DisableOneSettingsDownloads" 1 "Загрузка конфигурации OneSettings отключена" "OneSettings configuration downloads disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DisableTelemetryOptInChangeNotification" 1 "Уведомления об изменении уровня телеметрии отключены" "Telemetry opt-in change notifications disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowCommercialDataPipeline" 0 "Коммерческий конвейер данных отключён" "Commercial data pipeline disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowDesktopAnalyticsProcessing" 0 "Обработка Desktop Analytics отключена" "Desktop Analytics processing disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowUpdateComplianceProcessing" 0 "Обработка Update Compliance отключена" "Update Compliance processing disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowWUfBCloudProcessing" 0 "Облачная обработка WUfB отключена" "WUfB cloud processing disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0 "Программа улучшения качества (CEIP) отключена" "Customer Experience Improvement Program disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" "PreventDeviceMetadataFromNetwork" 1 "Загрузка данных об устройствах и сопутствующих приложений отключена" "Device metadata and companion app downloads disabled"
call :fw_block "DiagTrack" "%SystemRoot%\System32\svchost.exe" "DiagTrack"
call :fw_block "CompatTelRunner" "%SystemRoot%\System32\CompatTelRunner.exe"
call :fw_block "DeviceCensus" "%SystemRoot%\System32\DeviceCensus.exe"
set "T=\Microsoft\Windows"
call :task_disable "%T%\Application Experience\MareBackup" "MareBackup"
call :task_disable "%T%\PI\Sqm-Tasks" "Sqm-Tasks"
call :task_disable "%T%\Power Efficiency Diagnostics\AnalyzeSystem" "Power Efficiency Diagnostics"
call :task_disable "%T%\Flighting\FeatureConfig\UsageDataReporting" "Flighting UsageDataReporting"
call :task_disable "%T%\Flighting\FeatureConfig\UsageDataFlushing" "Flighting UsageDataFlushing"
call :task_disable "%T%\Flighting\FeatureConfig\UsageDataReceiver" "Flighting UsageDataReceiver"
call :task_disable "%T%\Flighting\OneSettings\RefreshCache" "OneSettings RefreshCache"
exit /b

:grp_pwsh
call :stage "Телеметрия PowerShell 7" "PowerShell 7 telemetry"
call :snap_reg "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "POWERSHELL_TELEMETRY_OPTOUT"
set "PWSH_FOUND="
where pwsh >nul 2>&1 && set "PWSH_FOUND=1"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH_FOUND=1"
if not defined PWSH_FOUND (
    call :say INFO "PowerShell 7 не установлен, шаг пропущен" "PowerShell 7 is not installed, skipped"
    exit /b
)
setx POWERSHELL_TELEMETRY_OPTOUT 1 /M >nul 2>&1
if errorlevel 1 (
    call :say ERR "Не удалось задать POWERSHELL_TELEMETRY_OPTOUT" "Failed to set POWERSHELL_TELEMETRY_OPTOUT"
) else (
    call :say OK "Телеметрия PowerShell 7 отключена (POWERSHELL_TELEMETRY_OPTOUT=1)" "PowerShell 7 telemetry disabled (POWERSHELL_TELEMETRY_OPTOUT=1)"
)
exit /b

:grp_ads
call :stage "Реклама, советы и предложения" "Ads, tips and suggestions"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0 "Рекламный ID отключён" "Advertising ID disabled"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1 "Рекламный ID заблокирован политикой" "Advertising ID blocked by policy"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1 "Consumer Features отключены политикой" "Consumer Features disabled by policy"
set "CDM=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
call :reg_set "%CDM%" "SubscribedContent-338387Enabled" 0 "Советы на экране блокировки отключены" "Lock screen tips disabled"
call :reg_set "%CDM%" "SubscribedContent-338388Enabled" 0 "Предложения в меню Пуск отключены" "Start menu suggestions disabled"
call :reg_set "%CDM%" "SubscribedContent-338389Enabled" 0 "Советы Windows отключены" "Windows tips disabled"
call :reg_set "%CDM%" "SubscribedContent-353694Enabled" 0 "Предложения в Параметрах отключены" "Settings suggestions disabled"
call :reg_set "%CDM%" "SubscribedContent-338393Enabled" 0 "Рекомендуемый контент в Параметрах отключён" "Suggested content in Settings disabled"
call :reg_set "%CDM%" "SubscribedContent-353696Enabled" 0 "Дополнительные предложения в Параметрах отключены" "Extra Settings suggestions disabled"
call :reg_set "%CDM%" "SubscribedContent-353698Enabled" 0 "Предложения на временной шкале отключены" "Timeline suggestions disabled"
call :reg_set "%CDM%" "RotatingLockScreenOverlayEnabled" 0 "Подсказки на экране блокировки отключены" "Lock screen overlay tips disabled"
call :reg_set "%CDM%" "SubscribedContent-310093Enabled" 0 "Экран приветствия после обновлений отключён" "Post-update welcome experience disabled"
call :reg_set "%CDM%" "SystemPaneSuggestionsEnabled" 0 "Системные предложения отключены" "System pane suggestions disabled"
call :reg_set "%CDM%" "SoftLandingEnabled" 0 "Подсказки о функциях Windows отключены" "Soft landing tips disabled"
call :reg_set "%CDM%" "OemPreInstalledAppsEnabled" 0 "Предустановка OEM-приложений отключена" "OEM pre-installed apps disabled"
call :reg_set "%CDM%" "PreInstalledAppsEnabled" 0 "Предустановка приложений отключена" "Pre-installed apps disabled"
call :reg_set "%CDM%" "PreInstalledAppsEverEnabled" 0 "Повторная предустановка приложений отключена" "Pre-installed apps re-provisioning disabled"
call :reg_set "%CDM%" "SilentInstalledAppsEnabled" 0 "Тихая установка приложений отключена" "Silent app installs disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0 "Рекомендации в меню Пуск отключены" "Start menu recommendations disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_AccountNotifications" 0 "Уведомления аккаунта в меню Пуск отключены" "Start menu account notifications disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard" "Disabled" 1 "Предлагаемые действия буфера обмена отключены" "Clipboard suggested actions disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0 "Недавние файлы в меню Пуск отключены" "Recent files in Start disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0 "Реклама OneDrive в Проводнике отключена" "OneDrive ads in File Explorer disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0 "Предложения по настройке устройства отключены" "Finish-setting-up-your-device prompts disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications" "EnableAccountNotifications" 0 "Уведомления аккаунта в Параметрах отключены" "Account notifications in Settings disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested" "Enabled" 0 "Рекламные уведомления Windows отключены" "Suggested notifications disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Mobility" "OptedIn" 0 "Предложения связать телефон отключены" "Phone Link suggestions disabled"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableConsumerAccountStateContent" 1 "Реклама подписок Microsoft 365 отключена" "Microsoft 365 subscription ads disabled"
exit /b

:grp_activity
call :stage "История активности и запросы отзывов" "Activity history and feedback"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 "История активности отключена" "Activity history disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0 "Публикация активности отключена" "Activity publishing disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 "Отправка активности в облако отключена" "Activity cloud upload disabled"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1 "Уведомления с запросом отзывов отключены политикой" "Feedback notifications disabled by policy"
call :reg_set "HKCU\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0 "Запросы отзывов отключены" "Feedback requests disabled"
exit /b

:grp_search
call :stage "Bing и веб-результаты в поиске" "Bing and web results in search"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0 "Bing в поиске отключён" "Bing in Windows Search disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0 "Облачный поиск ограничен" "Cloud search consent revoked"
call :reg_set "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1 "Веб-подсказки в поиске отключены" "Search box web suggestions disabled"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1 "Веб-поиск отключён политикой" "Web search disabled by policy"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0 "Веб-результаты в поиске отключены политикой" "Web results in search disabled by policy"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "EnableDynamicContentInWSB" 0 "Динамический контент поиска отключён политикой" "Dynamic search box content disabled by policy"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsSearchHighlightsEnabled" 0 "Search Highlights отключены" "Search highlights disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 0 "Динамический контент в поле поиска отключён" "Dynamic content in the search box disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDeviceSearchHistoryEnabled" 0 "История поиска на устройстве отключена" "Device search history disabled"
exit /b

:grp_widgets
call :stage "Widgets и новости" "Widgets and news"
call :reg_set_ucpd "HKLM\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0 "Widgets отключены" "Widgets disabled"
call :reg_set_ucpd "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" "EnableFeeds" 0 "Новости и интересы отключены" "News and interests disabled"
exit /b

:grp_services
call :stage "Службы телеметрии" "Telemetry services"
call :svc_disable "DiagTrack" "DiagTrack (Connected User Experiences and Telemetry)"
call :svc_disable "dmwappushservice" "dmwappushservice (WAP Push)"
call :reg_set "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1 "Запуск программ производителя из прошивки запрещён (WPBT)" "Firmware-injected vendor software blocked (WPBT)"
exit /b

:grp_tasks
call :stage "Задачи телеметрии и инвентаризация приложений" "Telemetry tasks and app inventory"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0 "Телеметрия совместимости приложений отключена" "Application compatibility telemetry disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1 "Сбор инвентаризации приложений отключён" "Inventory collector disabled"
set "T=\Microsoft\Windows"
call :task_disable "%T%\Application Experience\Microsoft Compatibility Appraiser" "Compatibility Appraiser"
call :task_disable "%T%\Application Experience\Microsoft Compatibility Appraiser Exp" "Compatibility Appraiser Exp"
call :task_disable "%T%\Application Experience\ProgramDataUpdater" "ProgramDataUpdater"
call :task_disable "%T%\Autochk\Proxy" "Autochk Proxy"
call :task_disable "%T%\Customer Experience Improvement Program\Consolidator" "CEIP Consolidator"
call :task_disable "%T%\Customer Experience Improvement Program\KernelCeipTask" "CEIP KernelCeipTask"
call :task_disable "%T%\Customer Experience Improvement Program\UsbCeip" "CEIP UsbCeip"
call :task_disable "%T%\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" "DiskDiagnosticDataCollector"
call :task_disable "%T%\Feedback\Siuf\DmClient" "Feedback DmClient"
call :task_disable "%T%\Feedback\Siuf\DmClientOnScenarioDownload" "Feedback DmClientOnScenarioDownload"
call :task_disable "%T%\Device Information\Device" "Device Information"
call :task_disable "%T%\Device Information\Device User" "Device Information User"
call :task_disable "%T%\Application Experience\StartupAppTask" "StartupAppTask"
call :task_disable "%T%\DiskFootprint\Diagnostics" "DiskFootprint Diagnostics"
exit /b

:grp_ai
call :stage "Recall, Click to Do, Copilot" "Recall, Click to Do, Copilot"
call :probe_environment
if not defined HAS_NPU call :say INFO "Нейропроцессор не обнаружен: Recall на этом компьютере отсутствует, политики задаются на будущее" "No neural processor found: Recall is not present on this PC, the policies are set for the future"
set "AI=SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
call :reg_set "HKLM\%AI%" "DisableAIDataAnalysis" 1 "Снимки Recall отключены" "Recall snapshots disabled"
call :reg_set "HKCU\%AI%" "DisableAIDataAnalysis" 1 "Снимки Recall отключены (пользователь)" "Recall snapshots disabled (user)"
call :reg_set "HKCU\%AI%" "DisableRecallDataProviders" 1 "Провайдеры данных Recall отключены" "Recall data providers disabled"
call :reg_set "HKLM\%AI%" "DisableClickToDo" 1 "Click to Do отключён" "Click to Do disabled"
call :reg_set "HKCU\%AI%" "DisableClickToDo" 1 "Click to Do отключён (пользователь)" "Click to Do disabled (user)"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1 "Устаревший Windows Copilot отключён" "Legacy Windows Copilot disabled"
call :reg_set "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1 "Устаревший Windows Copilot отключён (пользователь)" "Legacy Windows Copilot disabled (user)"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0 "Кнопка Copilot на панели задач скрыта" "Copilot taskbar button hidden"
if defined HAS_NPU call :reg_set "HKLM\%AI%" "AllowRecallEnablement" 0 "Компонент Recall отключён на уровне устройства" "The Recall component is disabled at device level"
call :reg_set "HKLM\SOFTWARE\Policies\WindowsNotepad" "DisableAIFeatures" 1 "Функции ИИ в Блокноте отключены" "Notepad AI features disabled"
set "PAINT=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint"
for %%V in (DisableCocreator DisableGenerativeFill DisableImageCreator DisableGenerativeErase DisableRemoveBackground) do call :reg_set "%PAINT%" "%%V" 1 "Paint: %%V отключено" "Paint: %%V disabled"
set "EDGE=HKLM\SOFTWARE\Policies\Microsoft\Edge"
for %%V in (CopilotPageContext CopilotCDPPageContext EdgeEntraCopilotPageContext HubsSidebarEnabled EdgeHistoryAISearchEnabled ComposeInlineEnabled NewTabPageBingChatEnabled) do call :reg_set "%EDGE%" "%%V" 0 "Edge: %%V отключено" "Edge: %%V disabled"
call :reg_set "%EDGE%" "GenAILocalFoundationalModelSettings" 1 "Edge: локальная модель ИИ отключена" "Edge: local AI model disabled"
call :svc_set_manual "WSAIFabricSvc" "Служба ИИ Windows (WSAIFabricSvc)" "Windows AI service (WSAIFabricSvc)"
exit /b

:grp_wer
call :stage "Отчёты об ошибках (WER)" "Windows Error Reporting"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" 1 "Отчёты об ошибках отключены (policy)" "Windows Error Reporting disabled (policy)"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "DoNotSendAdditionalData" 1 "Отправка дополнительных данных WER запрещена" "WER additional data blocked"
call :reg_set "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 1 "Отчёты об ошибках отключены (системный параметр)" "Windows Error Reporting disabled (system value)"
call :svc_disable "WerSvc" "WerSvc (Windows Error Reporting)"
call :task_disable "\Microsoft\Windows\Windows Error Reporting\QueueReporting" "WER QueueReporting"
exit /b

:grp_input
call :stage "Персонализация ввода и речь" "Input personalization and speech"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" "AllowInputPersonalization" 0 "Персонализация ввода отключена" "Input personalization disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1 "Сбор рукописного ввода запрещён (policy)" "Implicit ink collection blocked (policy)"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1 "Сбор набранного текста запрещён (policy)" "Implicit text collection blocked (policy)"
call :reg_set "HKCU\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1 "Сбор рукописного ввода ограничен" "Implicit ink collection restricted"
call :reg_set "HKCU\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1 "Сбор набранного текста ограничен" "Implicit text collection restricted"
call :reg_set "HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0 "Сбор контактов отключён" "Contact harvesting disabled"
call :reg_set "HKCU\SOFTWARE\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0 "Согласие на персонализацию речи и ввода отозвано" "Speech and typing personalization consent revoked"
call :reg_set "HKCU\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" "HasAccepted" 0 "Онлайн-распознавание речи отключено" "Online speech recognition disabled"
exit /b

:grp_spotlight
call :stage "Spotlight и функции между устройствами" "Spotlight and cross-device features"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableSoftLanding" 1 "Советы Windows отключены (policy)" "Windows tips disabled (policy)"
call :reg_set "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableTailoredExperiencesWithDiagnosticData" 1 "Персонализированные предложения запрещены (policy)" "Tailored experiences blocked (policy)"
call :reg_set "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableThirdPartySuggestions" 1 "Сторонние предложения отключены" "Third-party suggestions disabled"
call :reg_set "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "ConfigureWindowsSpotlight" 2 "Windows Spotlight отключён" "Windows Spotlight disabled"
call :reg_set "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsSpotlightFeatures" 1 "Функции Windows Spotlight отключены" "Windows Spotlight features disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreenCamera" 1 "Камера на экране блокировки отключена" "Lock screen camera disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "AllowCrossDeviceClipboard" 0 "Синхронизация буфера обмена отключена" "Cross-device clipboard disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "EnableCdp" 0 "Connected Devices Platform отключена" "Connected Devices Platform disabled"
exit /b

:grp_location
call :stage "Геолокация" "Location services"
call :reg_set_sz "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Deny" "Доступ к геолокации запрещён в параметрах конфиденциальности" "Location access denied in privacy settings"
call :reg_set "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" "SensorPermissionState" 0 "Датчик местоположения отключён" "Location sensor disabled"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1 "Службы геолокации отключены политикой" "Location services disabled by policy"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessLocation" 2 "Доступ приложений к геолокации запрещён политикой" "App location access denied by policy"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\FindMyDevice" "AllowFindMyDevice" 0 "Поиск устройства отключён" "Find my device disabled"
exit /b

:grp_app_access
call :stage "Камера и микрофон для приложений" "Camera and microphone for apps"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessCamera" 2 "Доступ приложений к камере запрещён" "App camera access denied"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMicrophone" 2 "Доступ приложений к микрофону запрещён" "App microphone access denied"
call :reg_set "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1 "Фоновая работа приложений запрещена" "Apps are not allowed to run in the background"
exit /b

:grp_push
call :stage "Облачные push-уведомления" "Cloud push notifications"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" "NoCloudApplicationNotification" 1 "Облачные push-уведомления отключены" "Cloud push notifications disabled"
exit /b

:grp_edge
call :stage "Политики Microsoft Edge" "Microsoft Edge policies"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Edge" "DiagnosticData" 0 "Edge: диагностические данные отключены" "Edge: diagnostic data disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Edge" "PersonalizationReportingEnabled" 0 "Edge: отчёты персонализации отключены" "Edge: personalization reporting disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Edge" "ShowRecommendationsEnabled" 0 "Edge: рекомендации отключены" "Edge: recommendations disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Edge" "UserFeedbackAllowed" 0 "Edge: запросы отзывов отключены" "Edge: feedback prompts disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Edge" "StartupBoostEnabled" 0 "Edge: Startup Boost отключён" "Edge: Startup Boost disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 0 "Edge: фоновый режим отключён" "Edge: background mode disabled"
set "EDGE=HKLM\SOFTWARE\Policies\Microsoft\Edge"
for %%V in (EdgeShoppingAssistantEnabled ShowMicrosoftRewards WebWidgetAllowed EdgeCollectionsEnabled AlternateErrorPagesEnabled NewTabPageContentEnabled SpotlightExperiencesAndRecommendationsEnabled DefaultBrowserSettingsCampaignEnabled EdgeAssetDeliveryServiceEnabled WalletDonationEnabled MicrosoftEdgeInsiderPromotionEnabled TabServicesEnabled) do call :reg_set "%EDGE%" "%%V" 0 "Edge: %%V отключено" "Edge: %%V disabled"
call :reg_set "%EDGE%" "ConfigureDoNotTrack" 1 "Edge: запрос Do Not Track включён" "Edge: Do Not Track request enabled"
call :reg_set "%EDGE%" "HideFirstRunExperience" 1 "Edge: экран первого запуска скрыт" "Edge: first run experience hidden"
call :reg_set "%EDGE%" "NewTabPageHideDefaultTopSites" 1 "Edge: рекламные плитки новой вкладки скрыты" "Edge: promoted tiles on the new tab hidden"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" "CreateDesktopShortcutDefault" 0 "Edge: ярлык на рабочем столе не создаётся" "Edge: desktop shortcut is not recreated"
exit /b

:grp_hosts
call :stage "Блокировка серверов телеметрии в hosts" "Telemetry endpoints in hosts"
call :block_telemetry_hosts
exit /b

:grp_flush
call :stage "Очистка кэша телеметрии" "Telemetry cache flush"
call :flush_telemetry_cache
exit /b

:grp_apptelemetry
call :stage "Телеметрия приложений: Office и средства разработки" "Application telemetry: Office and developer tools"
set "OFP=SOFTWARE\Policies\Microsoft\office\16.0\common"
for %%V in (DisconnectedState UserContentDisabled DownloadContentDisabled ControllerConnectedServicesEnabled) do call :reg_set "HKCU\%OFP%\privacy" "%%V" 2 "Office: %%V отключено" "Office: %%V disabled"
call :reg_set "HKCU\%OFP%\clienttelemetry" "SendTelemetry" 3 "Office: отправка телеметрии отключена" "Office: telemetry sending disabled"
call :task_disable "\Microsoft\Office\OfficeTelemetryAgentFallBack2016" "Office Telemetry Agent Fallback"
call :task_disable "\Microsoft\Office\OfficeTelemetryAgentLogOn2016" "Office Telemetry Agent LogOn"
call :snap_reg "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "DOTNET_CLI_TELEMETRY_OPTOUT"
setx DOTNET_CLI_TELEMETRY_OPTOUT 1 /M >nul 2>&1
if errorlevel 1 (
    call :say ERR "Не удалось отключить телеметрию .NET CLI" "Failed to disable .NET CLI telemetry"
) else (
    call :say OK "Телеметрия .NET CLI отключена" ".NET CLI telemetry disabled"
)
call :say INFO "winget использует общий уровень диагностических данных Windows и отдельной настройки не требует" "winget follows the Windows diagnostic data level and needs no separate setting"
exit /b

:grp_appremove
call :stage "Удаление предустановленных приложений" "Removing pre-installed apps"
:: Never listed here: Store, App Installer (winget), Terminal, Photos, Calculator, Notepad, Paint, Camera, codecs
set "WTO_APPS=Clipchamp.Clipchamp Microsoft.3DBuilder Microsoft.549981C3F5F10 Microsoft.BingFinance Microsoft.BingFoodAndDrink Microsoft.BingHealthAndFitness Microsoft.BingNews Microsoft.BingSports Microsoft.BingTranslator Microsoft.BingTravel Microsoft.BingWeather Microsoft.Getstarted Microsoft.Messaging Microsoft.MicrosoftJournal Microsoft.MicrosoftOfficeHub Microsoft.MicrosoftSolitaireCollection Microsoft.MixedReality.Portal Microsoft.NetworkSpeedTest Microsoft.OneConnect Microsoft.People Microsoft.PowerAutomateDesktop Microsoft.Print3D Microsoft.SkypeApp Microsoft.Todos Microsoft.Windows.DevHome Microsoft.WindowsFeedbackHub Microsoft.WindowsMaps Microsoft.ZuneVideo MicrosoftCorporationII.MicrosoftFamily MicrosoftCorporationII.QuickAssist MicrosoftWindows.Client.WebExperience"
if not "%SILENT_MODE%"=="1" (
    echo.
    call :echo_tr C_WARN "Удаление приложений нельзя отменить откатом: вернуть их можно только через Microsoft Store или winget." "App removal cannot be undone by Restore: apps can only be reinstalled from Microsoft Store or winget."
    echo.
    call :prompt 1Y0N "Удалить приложения? [1, 0]:" "Remove the apps? [1, 0]:"
    if errorlevel 3 (
        call :say INFO "Удаление приложений отменено" "App removal cancelled"
        exit /b
    )
)
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "foreach ($n in ($env:WTO_APPS -split ' ')) { $done = $false; try { foreach ($p in @(Get-AppxPackage -Name $n -AllUsers -ErrorAction SilentlyContinue)) { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; $done = $true } } catch { Write-Output ('FAILED=' + $n) }; try { foreach ($q in @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue).Where({ $_.DisplayName -eq $n })) { Remove-AppxProvisionedPackage -Online -PackageName $q.PackageName -ErrorAction Stop ^> $null; $done = $true } } catch {}; if ($done) { Write-Output ('REMOVED=' + $n) } }" 2^>nul`) do (
    if /i "%%A"=="REMOVED" call :say OK "Удалено приложение: %%B" "App removed: %%B"
    if /i "%%A"=="FAILED" call :say WARN "Не удалось удалить: %%B" "Failed to remove: %%B"
)
call :say INFO "Не тронуты: Microsoft Store, установщик приложений (winget), Terminal, Фотографии, Калькулятор, Блокнот, Paint, Камера и кодеки" "Left alone: Microsoft Store, App Installer (winget), Terminal, Photos, Calculator, Notepad, Paint, Camera and codecs"
exit /b

:grp_updates
call :stage "Windows Update: только обновления безопасности" "Windows Update: security updates only"
if not defined WIN_EDITION call :read_os_info
set "WU=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
set "WU_CUR=!WIN_VER!"
if not defined WU_CUR for /f "tokens=2,*" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ReleaseId 2^>nul ^| "%FIND%" "REG_"') do set "WU_CUR=%%B"
:: Pin the newer of: the version already installed, and the newest release known to the script
if "!WIN_NAME!"=="Windows 11" (set "WU_TARGET=%WU_TARGET_WIN11%") else (set "WU_TARGET=%WU_TARGET_WIN10%")
if defined WU_CUR if /i "!WU_CUR!" GTR "!WU_TARGET!" set "WU_TARGET=!WU_CUR!"
set "WU_PINNED="
for /f "tokens=2,*" %%A in ('reg query "%WU%" /v TargetReleaseVersionInfo 2^>nul ^| "%FIND%" "REG_"') do set "WU_PINNED=%%B"
if defined WU_PINNED if /i not "!WU_PINNED!"=="!WU_TARGET!" call :say INFO "Текущее закрепление !WU_PINNED! будет заменено на !WU_TARGET!" "The current pin !WU_PINNED! will be replaced with !WU_TARGET!"
if /i "!WIN_EDITION:~0,4!"=="Core" call :say WARN "Windows Home официально не поддерживает политики закрепления версии, они могут быть проигнорированы" "Windows Home does not officially support version pinning policies, they may be ignored"

call :reg_set "%WU%" "TargetReleaseVersion" 1 "Закрепление версии Windows включено" "Windows version pinning enabled"
call :reg_set_sz "%WU%" "ProductVersion" "!WIN_NAME!" "Продукт: !WIN_NAME!" "Product: !WIN_NAME!"
call :reg_set_sz "%WU%" "TargetReleaseVersionInfo" "!WU_TARGET!" "Закреплённая версия: !WU_TARGET!, новые версии Windows не устанавливаются" "Pinned version: !WU_TARGET!, newer Windows versions are blocked"
if defined WU_CUR if /i "!WU_CUR!" LSS "!WU_TARGET!" call :say INFO "Установлена !WU_CUR!: Windows один раз обновится до !WU_TARGET!, затем новые версии приходить не будут" "!WU_CUR! is installed: Windows updates once to !WU_TARGET!, then no newer versions are installed"
:: Known end of servicing for Home and Pro editions
if /i "!WU_TARGET!"=="24H2" call :say WARN "Поддержка 24H2 заканчивается 13 октября 2026: закрепите более свежую версию" "24H2 support ends on 13 October 2026: pin a newer version"
if /i "!WU_TARGET!"=="25H2" call :say INFO "Обновления безопасности для 25H2 выходят до 12 октября 2027" "Security updates for 25H2 are published until 12 October 2027"
call :say INFO "После выхода следующей версии Windows измените WU_TARGET_WIN11 в начале скрипта и запустите пункт снова" "When the next Windows release ships, change WU_TARGET_WIN11 at the top of the script and run this option again"
call :reg_set "%WU%" "SetAllowOptionalContent" 1 "Политика необязательных обновлений задана" "Optional updates policy configured"
call :reg_set "%WU%" "AllowOptionalContent" 0 "Необязательные и предварительные обновления отключены" "Optional and preview updates disabled"
call :reg_set "%WU%" "AllowTemporaryEnterpriseFeatureControl" 0 "Новые функции из ежемесячных обновлений не включаются" "New features from monthly updates stay off"
call :reg_set "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsContinuousInnovationOptedIn" 0 "Получение новых функций сразу после выхода отключено" "Get the latest updates as soon as available disabled"
call :reg_set "%WU%" "ManagePreviewBuilds" 1 "Политика сборок Insider задана" "Insider builds policy configured"
call :reg_set "%WU%" "ManagePreviewBuildsPolicyValue" 0 "Сборки Windows Insider запрещены" "Windows Insider builds blocked"
call :reg_set "%WU%" "ExcludeWUDriversInQualityUpdate" 1 "Драйверы через Windows Update отключены" "Driver updates via Windows Update disabled"
call :reg_set "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 0 "Автоматическая загрузка драйверов устройств отключена" "Automatic device driver download disabled"
call :reg_set "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload" 2 "Автообновление приложений Microsoft Store отключено (policy)" "Microsoft Store automatic app updates disabled (policy)"
call :reg_set "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" "AutoDownload" 2 "Автообновление приложений Microsoft Store отключено" "Microsoft Store automatic app updates disabled"
:: Removing the value is how Windows itself stores "off" for this switch
reg query "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v AllowMUUpdateService >nul 2>&1
if errorlevel 1 (
    call :say OK "Обновления других продуктов Microsoft отключены" "Updates for other Microsoft products disabled"
) else (
    call :reg_del "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "AllowMUUpdateService"
)
call :reg_set "HKU\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" "DownloadMode" 0 "Раздача обновлений другим компьютерам отключена" "Sharing updates with other PCs disabled"
call :reg_set_pol "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0 "Раздача обновлений запрещена политикой" "Update sharing blocked by policy"
call :reg_set "%WU%\AU" "AUOptions" 4 "Обновления загружаются, установка по расписанию" "Updates download, installation on schedule"
call :reg_set "%WU%\AU" "NoAutoRebootWithLoggedOnUsers" 1 "Автоматическая перезагрузка при активном сеансе запрещена" "Automatic restart while signed in disabled"

:: Policies that would block security updates, Store or winget (AUOptions stays: it is set above)
for %%V in (NoAutoUpdate DisableWindowsUpdateAccess DoNotConnectToWindowsUpdateInternetLocations SetDisableUXWUAccess) do (
    call :reg_del "%WU%" "%%V"
    call :reg_del "%WU%\AU" "%%V"
)
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" "DisableStoreApps"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" "RemoveWindowsStore"
call :svc_ensure "wuauserv" demand "Windows Update (wuauserv)"
call :svc_ensure "BITS" demand "BITS"
call :svc_ensure "UsoSvc" demand "Update Orchestrator (UsoSvc)"
call :svc_ensure "DoSvc" delayed-auto "Delivery Optimization (DoSvc)"
call :svc_ensure "InstallService" demand "Microsoft Store Install Service"
call :svc_ensure "AppXSvc" demand "AppX Deployment Service"
call :say INFO "Ежемесячное накопительное обновление — один пакет с исправлениями безопасности и обычными исправлениями, Microsoft их не разделяет" "The monthly cumulative update is a single package with security and regular fixes, Microsoft does not split them"
call :say INFO "winget, Microsoft Store и другие менеджеры пакетов работают, приложения обновляются вручную (winget upgrade --all)" "winget, Microsoft Store and other package managers keep working, apps are updated manually (winget upgrade --all)"
exit /b

:: ==============================================================
::  FLUSH
:: ==============================================================

:run_flush_standalone
if "%UI_LANG%"=="RU" (set "MODE_NAME=Очистка кэша телеметрии") else (set "MODE_NAME=Telemetry Cache Flush")
call :reset_counters
call :init_log
call :header
call :flush_telemetry_cache
call :summary "Готово" "Finished"
call :pause_here
if defined CLI_ACTION (call :set_exit_code & exit /b !RUN_CODE!)
goto :main_menu

:: ==============================================================
::  QUICK CHECK
:: ==============================================================

:: %1 key, %2 value, %3 accepted values (space separated), %4 RU label, %5 EN label
:check_reg
set "FOUND="
for /f "tokens=3" %%A in ('reg query "%~1" /v "%~2" 2^>nul ^| "%FIND%" "REG_"') do set "FOUND=%%A"
if not defined FOUND (call :say INFO "%~4: не настроено" "%~5: not configured" & exit /b)
set "HIT="
for %%E in (%~3) do if /i "!FOUND!"=="%%E" set "HIT=1"
if defined HIT (
    call :say OK "%~4: применено" "%~5: applied"
) else (
    call :say WARN "%~4: другое значение (!FOUND!)" "%~5: different value (!FOUND!)"
)
exit /b

:check_service
sc query "%~1" >nul 2>&1 || (call :say INFO "%~2: служба отсутствует" "%~2: service not present" & exit /b)
call :svc_start_type "%~1"
if /i "!SVC_START!"=="DISABLED" (
    call :say OK "%~2: отключена" "%~2: disabled"
) else (
    call :say INFO "%~2: !SVC_START!" "%~2: !SVC_START!"
)
exit /b

:check_task
call :task_state "%~1"
if "!TASK_STATE!"=="MISSING" exit /b
if "!TASK_STATE!"=="DISABLED" (
    call :say OK "%~2: отключена" "%~2: disabled"
) else (
    call :say INFO "%~2: включена" "%~2: enabled"
)
exit /b

:: Warns about settings that break security updates, Store or winget
:check_update_blockers
set "WU_BAD="
for %%V in (NoAutoUpdate DisableWindowsUpdateAccess DoNotConnectToWindowsUpdateInternetLocations) do (
    reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v %%V 2>nul | "%FIND%" "0x1" >nul && set "WU_BAD=1"
    reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v %%V 2>nul | "%FIND%" "0x1" >nul && set "WU_BAD=1"
)
for %%S in (wuauserv BITS DoSvc InstallService) do (
    sc qc %%S 2>nul | "%FIND%" "DISABLED" >nul && set "WU_BAD=1"
)
if defined WU_BAD (
    call :say WARN "Обновления безопасности или загрузка через Store/winget заблокированы (исправляется пунктом 9)" "Security updates or Store/winget downloads are blocked (fixed by option 9)"
) else (
    call :say OK "Обновления безопасности и winget не заблокированы" "Security updates and winget are not blocked"
)
exit /b

:check_fw
netsh advfirewall firewall show rule name="Windows Telemetry OFF - %~1" >nul 2>&1
if errorlevel 1 (
    call :say INFO "Брандмауэр, %~1: блокировки нет" "Firewall, %~1: not blocked"
) else (
    call :say OK "Брандмауэр, %~1: заблокирован" "Firewall, %~1: blocked"
)
exit /b

:quick_check
if "%UI_LANG%"=="RU" (set "MODE_NAME=Проверка состояния") else (set "MODE_NAME=Privacy State Audit")
call :reset_counters
call :init_log
call :header
call :detect_windows
call :check_environment

call :stage "Политики приватности" "Privacy policies"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" "0x0 0x1" "Уровень телеметрии" "Telemetry level"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowDeviceNameInTelemetry" "0x0" "Имя устройства в телеметрии" "Device name in telemetry"
call :check_reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" "0x0" "Отслеживание запуска приложений" "App launch tracking"
call :check_reg "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "POWERSHELL_TELEMETRY_OPTOUT" "1 true yes" "Телеметрия PowerShell 7" "PowerShell 7 telemetry"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" "0x1" "Запросы отзывов" "Feedback notifications"
call :check_reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" "0x0" "Рекламный ID" "Advertising ID"
call :check_reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" "0x0" "Персонализированные предложения" "Tailored experiences"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" "0x0" "История активности" "Activity history"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" "0x1" "Consumer Features" "Consumer Features"
call :check_reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" "0x0" "Тихая установка приложений" "Silent app installs"
call :check_reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" "0x0" "Рекомендации в меню Пуск" "Start menu recommendations"
call :check_reg "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" "0x1" "Веб-подсказки в поиске" "Search box web suggestions"
call :check_reg "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsSearchHighlightsEnabled" "0x0" "Search Highlights" "Search highlights"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" "0x0" "Widgets" "Widgets"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" "0x1" "Инвентаризация приложений" "Inventory collector"

call :stage "Полная блокировка отправки" "Full upload block"
call :check_reg "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener" "Start" "0x0" "Автологгер DiagTrack" "DiagTrack autologger"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DisableOneSettingsDownloads" "0x1" "Загрузки OneSettings" "OneSettings downloads"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" "0x0" "CEIP" "CEIP"
call :check_fw "DiagTrack"
call :check_fw "CompatTelRunner"
call :check_fw "DeviceCensus"
findstr /c:"BEGIN WINDOWS TELEMETRY OFF" "%SystemRoot%\System32\drivers\etc\hosts" >nul 2>&1
if errorlevel 1 (
    call :say INFO "Блокировка в hosts: не активна" "Hosts block: not active"
) else (
    call :say OK "Блокировка в hosts: активна" "Hosts block: active"
)

call :stage "Расширенные политики" "Advanced policies"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" "0x1" "Снимки Recall" "Recall snapshots"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableClickToDo" "0x1" "Click to Do" "Click to Do"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" "0x1" "Устаревший Copilot" "Legacy Copilot"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" "AllowInputPersonalization" "0x0" "Персонализация ввода" "Input personalization"
call :check_reg "HKCU\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" "HasAccepted" "0x0" "Онлайн-распознавание речи" "Online speech recognition"
call :check_reg "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsSpotlightFeatures" "0x1" "Windows Spotlight" "Windows Spotlight"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" "EnableCdp" "0x0" "Connected Devices Platform" "Connected Devices Platform"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" "0x1" "Геолокация" "Location services"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessCamera" "0x2" "Доступ приложений к камере" "App camera access"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMicrophone" "0x2" "Доступ приложений к микрофону" "App microphone access"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" "NoCloudApplicationNotification" "0x1" "Облачные push-уведомления" "Cloud push notifications"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" "Disabled" "0x1" "Отчёты об ошибках (WER)" "Windows Error Reporting"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Edge" "DiagnosticData" "0x0" "Диагностические данные Edge" "Edge diagnostic data"

call :stage "Windows Update" "Windows Update"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "TargetReleaseVersion" "0x1" "Закрепление версии Windows" "Windows version pinning"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "AllowOptionalContent" "0x0" "Необязательные обновления" "Optional updates"
call :check_reg "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" "0x1" "Драйверы через Windows Update" "Drivers via Windows Update"
call :check_reg "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" "AutoDownload" "0x2" "Автообновление приложений Store" "Store app auto-updates"
call :check_update_blockers

call :stage "Службы и задачи" "Services and tasks"
call :check_service "DiagTrack" "DiagTrack"
call :check_service "dmwappushservice" "dmwappushservice"
call :check_service "WerSvc" "WerSvc"
call :check_task "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" "Compatibility Appraiser"
call :check_task "\Microsoft\Windows\Application Experience\ProgramDataUpdater" "ProgramDataUpdater"
call :check_task "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" "CEIP Consolidator"
call :check_task "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" "CEIP UsbCeip"
call :check_task "\Microsoft\Windows\Feedback\Siuf\DmClient" "Feedback DmClient"
call :check_task "\Microsoft\Windows\Device Information\Device" "Device Information"
call :check_task "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting" "Flighting UsageDataReporting"
call :check_task "\Microsoft\Windows\Windows Error Reporting\QueueReporting" "WER QueueReporting"

call :summary "Проверка завершена" "Audit completed"
call :pause_here
if defined CLI_ACTION (call :set_exit_code & exit /b !RUN_CODE!)
goto :main_menu

:: ==============================================================
::  RESTORE
:: ==============================================================

:run_restore
set "SNAP_ON=0"
if "%UI_LANG%"=="RU" (set "MODE_NAME=Восстановление настроек") else (set "MODE_NAME=Restore Default Settings")
call :reset_counters
call :init_log
call :header
call :note "Запуск режима: %MODE_NAME%" "Starting: %MODE_NAME%"
echo.
call :detect_windows
call :create_restore_point
call :restore_policies
call :restore_full_block
call :restore_services
call :restore_tasks
call :restore_updates
call :restore_from_state
call :summary "Стандартные настройки восстановлены" "Default settings restored"
call :pause_here
call :post_restore_check
call :post_execution_action
if defined CLI_ACTION (
    call :pause_here
    call :set_exit_code
    exit /b !RUN_CODE!
)
goto :main_menu

:restore_policies
call :stage "Удаление политик и параметров" "Removing policies and values"
set "P=HKLM\SOFTWARE\Policies\Microsoft\Windows"
for %%V in (AllowTelemetry MaxTelemetryAllowed AllowDeviceNameInTelemetry LimitDiagnosticLogCollection LimitDumpCollection DoNotShowFeedbackNotifications DisableDiagnosticDataViewer DisableOneSettingsDownloads DisableTelemetryOptInChangeNotification DisableTelemetryOptInSettingsUx DisableEnterpriseAuthProxy AllowCommercialDataPipeline AllowDesktopAnalyticsProcessing AllowUpdateComplianceProcessing AllowWUfBCloudProcessing) do call :reg_del "%P%\DataCollection" "%%V"
for %%V in (AllowTelemetry MaxTelemetryAllowed) do call :reg_restore "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "%%V" 3
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" "ShowedToastAtLevel" 3
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable"
call :reg_del "%P%\AdvertisingInfo" "DisabledByGroupPolicy"
for %%V in (EnableActivityFeed PublishUserActivities UploadUserActivities AllowCrossDeviceClipboard EnableCdp) do call :reg_del "%P%\System" "%%V"
for %%V in (DisableWindowsConsumerFeatures DisableSoftLanding DisableTailoredExperiencesWithDiagnosticData DisableThirdPartySuggestions ConfigureWindowsSpotlight DisableWindowsSpotlightFeatures) do (
    call :reg_del "%P%\CloudContent" "%%V"
    call :reg_del "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "%%V"
)
for %%V in (DisableWebSearch ConnectedSearchUseWeb EnableDynamicContentInWSB) do call :reg_del "%P%\Windows Search" "%%V"
call :reg_del "HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests"
call :reg_del "%P%\Windows Feeds" "EnableFeeds"
for %%V in (AITEnable DisableInventory) do call :reg_del "%P%\AppCompat" "%%V"
for %%V in (DisableAIDataAnalysis DisableRecallDataProviders DisableClickToDo) do (
    call :reg_del "%P%\WindowsAI" "%%V"
    call :reg_del "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "%%V"
)
call :reg_del "%P%\WindowsCopilot" "TurnOffWindowsCopilot"
call :reg_del "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
for %%V in (AllowInputPersonalization RestrictImplicitInkCollection RestrictImplicitTextCollection) do call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" "%%V"
for %%V in (NoLockScreenCamera NoLockScreenSlideshow) do call :reg_del "%P%\Personalization" "%%V"
call :reg_del "%P%\LocationAndSensors" "DisableLocation"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\FindMyDevice" "AllowFindMyDevice"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode"
call :reg_restore_sz "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" "Value" "Allow"
call :reg_restore "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" "SensorPermissionState" 1
call :reg_restore "HKU\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" "DownloadMode" 1
for %%V in (LetAppsAccessLocation LetAppsAccessCamera LetAppsAccessMicrophone) do call :reg_del "%P%\AppPrivacy" "%%V"
for %%V in (NoCloudApplicationNotification NoPushApplicationNotification) do call :reg_del "%P%\CurrentVersion\PushNotifications" "%%V"
for %%V in (Disabled DoNotSendAdditionalData) do call :reg_del "%P%\Windows Error Reporting" "%%V"
call :reg_del "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled"
for %%V in (DiagnosticData PersonalizationReportingEnabled ShowRecommendationsEnabled UserFeedbackAllowed StartupBoostEnabled BackgroundModeEnabled) do call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Edge" "%%V"

for %%V in (NumberOfSIUFInPeriod PeriodInNanoSeconds) do call :reg_del "HKCU\SOFTWARE\Microsoft\Siuf\Rules" "%%V"
call :reg_del "HKCU\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut"
for %%V in (DisconnectedState UserContentDisabled DownloadContentDisabled ControllerConnectedServicesEnabled) do call :reg_del "HKCU\SOFTWARE\Policies\Microsoft\office\16.0\common\privacy" "%%V"
call :reg_del "HKCU\SOFTWARE\Policies\Microsoft\office\16.0\common\clienttelemetry" "SendTelemetry"
call :reg_del "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "DOTNET_CLI_TELEMETRY_OPTOUT"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" "PreventDeviceMetadataFromNetwork"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableConsumerAccountStateContent"
call :reg_del "HKLM\SOFTWARE\Policies\WindowsNotepad" "DisableAIFeatures"
for %%V in (DisableCocreator DisableGenerativeFill DisableImageCreator DisableGenerativeErase DisableRemoveBackground) do call :reg_del "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" "%%V"
for %%V in (CopilotPageContext CopilotCDPPageContext EdgeEntraCopilotPageContext HubsSidebarEnabled EdgeHistoryAISearchEnabled ComposeInlineEnabled NewTabPageBingChatEnabled GenAILocalFoundationalModelSettings EdgeShoppingAssistantEnabled ShowMicrosoftRewards WebWidgetAllowed EdgeCollectionsEnabled AlternateErrorPagesEnabled NewTabPageContentEnabled SpotlightExperiencesAndRecommendationsEnabled DefaultBrowserSettingsCampaignEnabled EdgeAssetDeliveryServiceEnabled WalletDonationEnabled MicrosoftEdgeInsiderPromotionEnabled TabServicesEnabled ConfigureDoNotTrack HideFirstRunExperience NewTabPageHideDefaultTopSites) do call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Edge" "%%V"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate" "CreateDesktopShortcutDefault"
call :reg_del "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement"
call :reg_del "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "ConnectedSearchUseWeb"
call :reg_del "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard" "Disabled"
for %%V in (RestrictImplicitInkCollection RestrictImplicitTextCollection) do call :reg_del "HKCU\SOFTWARE\Microsoft\InputPersonalization" "%%V"
call :reg_del "HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts"

call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 1
for %%V in (SubscribedContent-338387Enabled SubscribedContent-338388Enabled SubscribedContent-338389Enabled SubscribedContent-353694Enabled SubscribedContent-338393Enabled SubscribedContent-353696Enabled SubscribedContent-353698Enabled SubscribedContent-310093Enabled SystemPaneSuggestionsEnabled SoftLandingEnabled OemPreInstalledAppsEnabled PreInstalledAppsEnabled PreInstalledAppsEverEnabled SilentInstalledAppsEnabled RotatingLockScreenOverlayEnabled) do call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "%%V" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 1
call :reg_del "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs"
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications" "EnableAccountNotifications" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested" "Enabled" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Mobility" "OptedIn" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 0
for %%V in (IsDynamicSearchBoxEnabled IsDeviceSearchHistoryEnabled) do call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "%%V" 1
:: Windows default for these is "value absent", so removal is the correct restore
for %%V in (Start_IrisRecommendations Start_AccountNotifications Start_TrackProgs ShowCopilotButton) do call :reg_del "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "%%V"
for %%V in (BingSearchEnabled CortanaConsent) do call :reg_del "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "%%V"
call :reg_restore "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" "IsSearchHighlightsEnabled" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Input\TIPC" "Enabled" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 1
call :reg_restore "HKCU\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" "HasAccepted" 1

call :unblock_telemetry_hosts
exit /b

:restore_full_block
call :stage "Отмена полной блокировки и телеметрии PowerShell 7" "Undoing full block and PowerShell 7 opt-out"
set "AL=HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AutoLogger-Diagtrack-Listener"
reg query "%AL%" >nul 2>&1 && call :reg_restore "%AL%" "Start" 1
call :fw_unblock "DiagTrack"
call :fw_unblock "CompatTelRunner"
call :fw_unblock "DeviceCensus"
set "ENVKEY=HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
reg query "%ENVKEY%" /v POWERSHELL_TELEMETRY_OPTOUT >nul 2>&1 || exit /b
reg delete "%ENVKEY%" /v POWERSHELL_TELEMETRY_OPTOUT /f >nul 2>&1
if errorlevel 1 (
    call :say WARN "Не удалось удалить POWERSHELL_TELEMETRY_OPTOUT" "Failed to remove POWERSHELL_TELEMETRY_OPTOUT"
) else (
    call :say OK "POWERSHELL_TELEMETRY_OPTOUT удалена (вступит в силу после перезагрузки)" "POWERSHELL_TELEMETRY_OPTOUT removed (applies after restart)"
)
exit /b

:restore_services
call :stage "Восстановление служб" "Restoring services"
call :svc_restore "DiagTrack" auto AUTO_START "DiagTrack"
sc start DiagTrack >nul 2>&1
call :svc_restore "dmwappushservice" demand DEMAND_START "dmwappushservice"
call :svc_restore "WerSvc" demand DEMAND_START "WerSvc"
call :svc_restore "WSAIFabricSvc" auto AUTO_START "WSAIFabricSvc"
exit /b

:restore_tasks
call :stage "Восстановление задач" "Restoring scheduled tasks"
set "T=\Microsoft\Windows"
call :task_enable "%T%\Application Experience\Microsoft Compatibility Appraiser" "Compatibility Appraiser"
call :task_enable "%T%\Application Experience\Microsoft Compatibility Appraiser Exp" "Compatibility Appraiser Exp"
call :task_enable "%T%\Application Experience\PcaPatchDbTask" "PcaPatchDbTask"
call :task_enable "%T%\Application Experience\ProgramDataUpdater" "ProgramDataUpdater"
call :task_enable "%T%\Application Experience\MareBackup" "MareBackup"
call :task_enable "%T%\Autochk\Proxy" "Autochk Proxy"
call :task_enable "%T%\Customer Experience Improvement Program\Consolidator" "CEIP Consolidator"
call :task_enable "%T%\Customer Experience Improvement Program\KernelCeipTask" "CEIP KernelCeipTask"
call :task_enable "%T%\Customer Experience Improvement Program\UsbCeip" "CEIP UsbCeip"
call :task_enable "%T%\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" "DiskDiagnosticDataCollector"
call :task_enable "%T%\Feedback\Siuf\DmClient" "Feedback DmClient"
call :task_enable "%T%\Feedback\Siuf\DmClientOnScenarioDownload" "Feedback DmClientOnScenarioDownload"
call :task_enable "%T%\Device Information\Device" "Device Information"
call :task_enable "%T%\Device Information\Device User" "Device Information User"
call :task_enable "%T%\PI\Sqm-Tasks" "Sqm-Tasks"
call :task_enable "%T%\Power Efficiency Diagnostics\AnalyzeSystem" "Power Efficiency Diagnostics"
call :task_enable "%T%\Maps\MapsToastTask" "MapsToastTask"
call :task_enable "%T%\Maps\MapsUpdateTask" "MapsUpdateTask"
call :task_enable "%T%\Flighting\FeatureConfig\UsageDataReporting" "Flighting UsageDataReporting"
call :task_enable "%T%\Flighting\FeatureConfig\UsageDataFlushing" "Flighting UsageDataFlushing"
call :task_enable "%T%\Flighting\FeatureConfig\UsageDataReceiver" "Flighting UsageDataReceiver"
call :task_enable "%T%\Flighting\OneSettings\RefreshCache" "OneSettings RefreshCache"
call :task_enable "%T%\Windows Error Reporting\QueueReporting" "WER QueueReporting"
call :task_enable "%T%\Application Experience\StartupAppTask" "StartupAppTask"
call :task_enable "%T%\DiskFootprint\Diagnostics" "DiskFootprint Diagnostics"
call :task_enable "\Microsoft\Office\OfficeTelemetryAgentFallBack2016" "Office Telemetry Agent Fallback"
call :task_enable "\Microsoft\Office\OfficeTelemetryAgentLogOn2016" "Office Telemetry Agent LogOn"
exit /b

:restore_updates
call :stage "Восстановление Windows Update" "Restoring Windows Update"
for %%V in (TargetReleaseVersion ProductVersion TargetReleaseVersionInfo SetAllowOptionalContent AllowOptionalContent AllowTemporaryEnterpriseFeatureControl ManagePreviewBuilds ManagePreviewBuildsPolicyValue ExcludeWUDriversInQualityUpdate) do call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "%%V"
for %%V in (AUOptions NoAutoRebootWithLoggedOnUsers) do call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "%%V"
call :reg_del "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "IsContinuousInnovationOptedIn"
call :reg_del "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" "AutoDownload"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" /v AutoDownload >nul 2>&1 && call :reg_restore "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate" "AutoDownload" 4
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" /v SearchOrderConfig 2>nul | "%FIND%" "0x0" >nul && call :reg_restore "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 1
exit /b

:: Puts back the exact values captured before the changes were applied
:restore_from_state
if not exist "%STATEFILE%" (
    call :say INFO "Снимок состояния не найден: возвращены значения Windows по умолчанию" "No state snapshot found: Windows defaults were applied instead"
    exit /b
)
call :stage "Точный откат по снимку состояния" "Exact restore from the state snapshot"
set /a SNAP_RESTORED=0, SNAP_FAILED=0
for /f "usebackq tokens=1,* delims=|" %%A in ("%STATEFILE%") do (
    if /i "%%A"=="R" call :rs_reg "%%B"
    if /i "%%A"=="S" call :rs_svc "%%B"
    if /i "%%A"=="T" call :rs_task "%%B"
    if /i "%%A"=="F" call :rs_fw "%%B"
)
if !SNAP_RESTORED! GTR 0 call :say OK "Возвращено прежних значений: !SNAP_RESTORED!" "Previous values restored: !SNAP_RESTORED!"
if !SNAP_FAILED! GTR 0 call :say WARN "Не удалось вернуть: !SNAP_FAILED!" "Failed to restore: !SNAP_FAILED!"
if !SNAP_RESTORED! EQU 0 if !SNAP_FAILED! EQU 0 call :say INFO "Все значения из снимка уже соответствуют прежним" "All snapshot values already match the previous state"
move /y "%STATEFILE%" "%STATEFILE%.bak" >nul 2>&1
exit /b

:rs_reg
for /f "tokens=1,2,3,* delims=|" %%K in ("%~1") do (
    set "RSK=%%K"
    set "RSV=%%L"
    set "RST=%%M"
    set "RSD=%%N"
)
if "!RST!"=="@ABSENT@" (
    reg query "!RSK!" /v "!RSV!" >nul 2>&1 || exit /b
    reg delete "!RSK!" /v "!RSV!" /f >nul 2>&1
) else (
    reg add "!RSK!" /v "!RSV!" /t !RST! /d "!RSD!" /f >nul 2>&1
)
if errorlevel 1 (set /a SNAP_FAILED+=1) else (set /a SNAP_RESTORED+=1)
call :write_line "[STATE] !RSK!\!RSV! -> !RST! !RSD!"
exit /b

:rs_svc
for /f "tokens=1,* delims=|" %%K in ("%~1") do (
    set "RSS=%%K"
    set "RSM=%%L"
)
set "RSARG="
if /i "!RSM!"=="AUTO_START" set "RSARG=auto"
if /i "!RSM!"=="DELAYED_AUTO" set "RSARG=delayed-auto"
if /i "!RSM!"=="DEMAND_START" set "RSARG=demand"
if /i "!RSM!"=="DISABLED" set "RSARG=disabled"
if /i "!RSM!"=="BOOT_START" set "RSARG=boot"
if /i "!RSM!"=="SYSTEM_START" set "RSARG=system"
if not defined RSARG exit /b
sc query "!RSS!" >nul 2>&1 || exit /b
sc config "!RSS!" start= !RSARG! >nul 2>&1
if errorlevel 1 (set /a SNAP_FAILED+=1) else (set /a SNAP_RESTORED+=1)
call :write_line "[STATE] service !RSS! -> !RSARG!"
exit /b

:rs_task
for /f "tokens=1,* delims=|" %%K in ("%~1") do (
    set "RSTN=%%K"
    set "RSTS=%%L"
)
call :task_state "!RSTN!"
if "!TASK_STATE!"=="MISSING" exit /b
if /i "!TASK_STATE!"=="!RSTS!" exit /b
if /i "!RSTS!"=="DISABLED" (
    schtasks /change /tn "!RSTN!" /disable >nul 2>&1
) else (
    schtasks /change /tn "!RSTN!" /enable >nul 2>&1
)
if errorlevel 1 (set /a SNAP_FAILED+=1) else (set /a SNAP_RESTORED+=1)
call :write_line "[STATE] task !RSTN! -> !RSTS!"
exit /b

:rs_fw
for /f "tokens=1,* delims=|" %%K in ("%~1") do (
    set "RSFN=%%K"
    set "RSFS=%%L"
)
if /i "!RSFS!"=="PRESENT" exit /b
netsh advfirewall firewall show rule name="Windows Telemetry OFF - !RSFN!" >nul 2>&1 || exit /b
netsh advfirewall firewall delete rule name="Windows Telemetry OFF - !RSFN!" >nul 2>&1
if errorlevel 1 (set /a SNAP_FAILED+=1) else (set /a SNAP_RESTORED+=1)
call :write_line "[STATE] firewall !RSFN! -> removed"
exit /b

:: %1 key, %2 value, %3 RU label, %4 EN label
:check_absent
reg query "%~1" /v "%~2" >nul 2>&1
if errorlevel 1 (
    call :say OK "%~3: по умолчанию" "%~4: default"
    exit /b
)
call :was_in_snapshot "%~1" "%~2"
if "!SNAP_HAD!"=="1" (
    call :say OK "%~3: возвращено значение, которое было до запуска" "%~4: value from before the run put back"
) else (
    call :say WARN "%~3: ограничение всё ещё активно" "%~4: restriction still active"
)
exit /b

:: Tells whether the snapshot holds a real previous value for this entry
:was_in_snapshot
set "SNAP_HAD=0"
if not exist "%STATEFILE%.bak" exit /b
findstr /i /b /c:"R|%~1|%~2|@ABSENT@" "%STATEFILE%.bak" >nul 2>&1 && exit /b
findstr /i /b /c:"R|%~1|%~2|" "%STATEFILE%.bak" >nul 2>&1 && set "SNAP_HAD=1"
exit /b

:: %1 service, %2 expected START_TYPE
:check_service_mode
sc query "%~1" >nul 2>&1 || exit /b
call :svc_start_type "%~1"
if /i "!SVC_START!"=="%~2" (
    call :say OK "%~1: %~2" "%~1: %~2"
) else (
    call :say WARN "%~1: !SVC_START! (ожидалось %~2)" "%~1: !SVC_START! (expected %~2)"
)
exit /b

:check_task_enabled
call :task_state "%~1"
if "!TASK_STATE!"=="DISABLED" (
    call :say WARN "%~2: всё ещё отключена" "%~2: still disabled"
) else if "!TASK_STATE!"=="ENABLED" (
    call :say OK "%~2: включена" "%~2: enabled"
)
exit /b

:check_fw_absent
netsh advfirewall firewall show rule name="Windows Telemetry OFF - %~1" >nul 2>&1
if errorlevel 1 (
    call :say OK "Брандмауэр, %~1: правил нет" "Firewall, %~1: no rules"
) else (
    call :say WARN "Брандмауэр, %~1: правило всё ещё есть" "Firewall, %~1: rule still present"
)
exit /b

:post_restore_check
call :reset_counters
call :header
call :stage "Проверка восстановления" "Verifying restored settings"
set "P=HKLM\SOFTWARE\Policies\Microsoft\Windows"
call :check_absent "%P%\DataCollection" "AllowTelemetry" "Уровень телеметрии" "Telemetry level"
call :check_absent "%P%\DataCollection" "DisableOneSettingsDownloads" "Загрузки OneSettings" "OneSettings downloads"
call :check_absent "%P%\System" "EnableActivityFeed" "История активности" "Activity history"
call :check_absent "%P%\Windows Search" "DisableWebSearch" "Веб-поиск" "Web search"
call :check_absent "%P%\CloudContent" "DisableWindowsConsumerFeatures" "Consumer Features" "Consumer Features"
call :check_absent "HKLM\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" "Widgets" "Widgets"
call :check_absent "%P%\LocationAndSensors" "DisableLocation" "Геолокация" "Location services"
call :check_absent "%P%\AppPrivacy" "LetAppsAccessCamera" "Доступ к камере" "Camera access"
call :check_absent "%P%\Windows Error Reporting" "Disabled" "Отчёты об ошибках (WER)" "Windows Error Reporting"
call :check_absent "HKLM\SOFTWARE\Policies\Microsoft\Edge" "DiagnosticData" "Диагностические данные Edge" "Edge diagnostic data"
call :check_absent "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "POWERSHELL_TELEMETRY_OPTOUT" "Телеметрия PowerShell 7" "PowerShell 7 telemetry"
call :check_absent "%P%\WindowsUpdate" "TargetReleaseVersion" "Закрепление версии Windows" "Windows version pinning"
call :check_fw_absent "DiagTrack"
call :check_service_mode "DiagTrack" AUTO_START
call :check_service_mode "dmwappushservice" DEMAND_START
call :check_service_mode "WerSvc" DEMAND_START
call :check_task_enabled "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" "Compatibility Appraiser"
call :check_task_enabled "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" "CEIP Consolidator"
call :check_task_enabled "\Microsoft\Windows\Feedback\Siuf\DmClient" "Feedback DmClient"
findstr /c:"BEGIN WINDOWS TELEMETRY OFF" "%SystemRoot%\System32\drivers\etc\hosts" >nul 2>&1
if errorlevel 1 (
    call :say OK "Файл hosts: блокировок нет" "Hosts file: no blocks"
) else (
    call :say WARN "Файл hosts: блокировка всё ещё присутствует" "Hosts file: block still present"
)
call :summary "Проверка восстановления завершена" "Restore verification completed"
exit /b
