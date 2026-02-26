@echo off
setlocal EnableExtensions EnableDelayedExpansion

set NEOFORGE_VERSION=21.1.219

echo ===========================
echo CONFIG
echo ===========================
set "GIT=git"
set "BRANCH=main"
set "REPO_CLEAN=https://github.com/LupesHk/atmons-sv"
set "PLAYIT_EXE=playit.exe"
set "ZIP_NAME=world.zip"

if not defined ATM10_JAVA (
    set "ATM10_JAVA=java"
)

echo ===========================
echo CARREGAR TOKENS
echo ===========================
if exist "password.env" (
    echo Carregando tokens...
    for /f "usebackq tokens=1,2 delims==" %%a in ("password.env") do set "%%a=%%b"
)

set "REPO_TOKEN=https://%GIT_TOKEN%@github.com/LupesHk/atmons-sv"

rem Configurar Git
"%GIT%" config --global user.name "LucasHk" >nul 2>&1
"%GIT%" config --global user.email "lucasgamesbrasil.124@gmail.com" >nul 2>&1

echo.
echo ================================
echo Deseja puxar o commit mais recente?
echo Se nao responder em 5 segundos, sera considerado SIM.
echo ================================
choice /T 5 /D S /M "Puxar commit mais recente? (S/N): "

if %errorlevel%==2 (
    set "PULL_RECENTE=N"
) else (
    set "PULL_RECENTE=S"
)

echo Escolha final: %PULL_RECENTE%
echo.

if "%PULL_RECENTE%"=="N" (
    set /p "COMMIT_HASH=Digite o HASH do commit desejado: "
    echo Commit selecionado: %COMMIT_HASH%
    echo.
)

echo ===========================
echo Verificando dependencias...
echo ===========================
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo ERRO: git nao encontrado!
    pause
    exit /b 1
)
echo Git OK!

echo Verificando Java...
"%ATM10_JAVA%" -version 1>nul 2>nul || (
    echo Java nao encontrado!
    pause
    exit /b 1
)
echo Java OK!
echo.

echo ===========================
echo INICIALIZAR REPOSITORIO
echo ===========================
"%GIT%" rev-parse --git-dir >nul 2>&1
if %errorlevel% neq 0 (
    echo Repositorio nao encontrado. Inicializando...
    "%GIT%" init
    "%GIT%" branch -M main
    "%GIT%" remote add origin "%REPO_TOKEN%"

    if not exist ".gitignore" (
        (
            echo password.env
            echo logs/
            echo crash-reports/
            echo debug/
            echo world_backup_temp/
            echo *.log
            echo *.zip
            echo whats/
            echo .vscode/
            echo .idea/
            echo *.iml
            echo Thumbs.db
            echo .DS_Store
        ) > .gitignore
    )

    "%GIT%" fetch origin
    "%GIT%" reset --hard origin/main
    "%GIT%" clean -fd -e password.env -e whats/
) else (
    echo Repositorio encontrado.
    for /f "delims=" %%b in ('"%GIT%" branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%b"
    if not defined CURRENT_BRANCH set "CURRENT_BRANCH=unknown"
    if not "%CURRENT_BRANCH%"=="main" (
        "%GIT%" checkout main 2>nul
    )
)

echo.
echo ===========================
echo SINCRONIZANDO COM GITHUB...
echo ===========================

"%GIT%" remote set-url origin "%REPO_TOKEN%"

"%GIT%" fetch origin
"%GIT%" reset --hard origin/main
"%GIT%" clean -fd -e password.env -e whats/

if "%PULL_RECENTE%"=="S" (
    "%GIT%" pull origin %BRANCH% --rebase --autostash
) else (
    if defined COMMIT_HASH (
        "%GIT%" checkout %COMMIT_HASH%
    )
)

"%GIT%" remote set-url origin "%REPO_CLEAN%"
echo Sincronizacao concluida!
echo.

echo ===========================
echo VERIFICANDO PLAYIT...
echo ===========================
tasklist /FI "IMAGENAME eq playit.exe" | find /I "playit.exe" >nul
if %errorlevel%==0 (
    echo Playit ja esta aberto.
) else (
    echo Iniciando Playit...
    start "" /min "%PLAYIT_EXE%" --secret "%PLAYIT_SECRET%"
)
echo.

echo ===========================
echo INICIANDO SERVIDOR...
echo ===========================
"%ATM10_JAVA%" @user_jvm_args.txt @libraries\net\neoforged\neoforge\%NEOFORGE_VERSION%\win_args.txt nogui

echo ===========================
echo SERVIDOR FOI FECHADO.
echo ===========================

rem ==========================================================
rem ESPERAR O JAVA FECHAR (COM TIMEOUT + KILL DO PID DO SERVIDOR)
rem ==========================================================
set "STOP_TIMEOUT=240"

for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command ^
  "$p=(Get-CimInstance Win32_Process | ?{ $_.Name -eq 'java.exe' -and $_.CommandLine -match 'win_args\.txt' } | select -First 1).ProcessId; if($p){$p}else{0}"`) do set "SV_PID=%%P"

if "%SV_PID%"=="0" (
  echo Nao achei PID do servidor. Continuando...
  goto AFTER_WAIT
)

echo Aguardando servidor encerrar... PID=%SV_PID% (timeout %STOP_TIMEOUT%s)
set /a SECS=0

:WAIT_LOOP
powershell -NoProfile -Command "exit (Get-Process -Id %SV_PID% -ErrorAction SilentlyContinue) -ne $null"
if %errorlevel%==1 (
  echo Servidor encerrou OK.
  goto AFTER_WAIT
)

timeout /t 1 >nul
set /a SECS+=1

if %SECS% geq %STOP_TIMEOUT% (
  echo Servidor travou no shutdown. Forcando kill do PID %SV_PID%...
  powershell -NoProfile -Command "Stop-Process -Id %SV_PID% -Force"
  rem se matou, nao precisa ficar em loop infinito
  goto AFTER_WAIT
)

goto WAIT_LOOP

:AFTER_WAIT

echo.
echo Deseja desligar o PC ao final do backup? (S/N)

powershell -NoProfile -Command ^
  "[console]::beep(1200,300); [console]::beep(1200,300); [console]::beep(1200,300); " ^
  "[console]::beep(1200,300); [console]::beep(1200,300); [console]::beep(1200,300); " ^
  "[console]::beep(1200,300); [console]::beep(1200,300); [console]::beep(1200,300); " ^
  "[System.Media.SystemSounds]::Exclamation.Play(); Start-Sleep -Milliseconds 100; " ^
  "[System.Media.SystemSounds]::Exclamation.Play(); Start-Sleep -Milliseconds 200; " ^
  "[System.Media.SystemSounds]::Exclamation.Play()"

choice /T 30 /D S /M "Se nao responder, sera considerado SIM: "

if %errorlevel%==2 (
    set "DESLIGAR=N"
) else (
    set "DESLIGAR=S"
)

echo Resposta final: %DESLIGAR%
echo.

echo ===========================
echo COMMITANDO TUDO...
echo ===========================
"%GIT%" remote set-url origin "%REPO_TOKEN%"

"%GIT%" add -A

"%GIT%" diff --cached --quiet
if %errorlevel% equ 0 (
    echo Nenhuma mudanca para commit.
) else (
    "%GIT%" commit -m "Backup - %date% %time%"
    "%GIT%" push origin %BRANCH% --force
    echo Backup enviado!
)

"%GIT%" remote set-url origin "%REPO_CLEAN%"
echo.

echo ===========================
echo COMPACTANDO WORLD...
echo ===========================

if exist "%ZIP_NAME%" del "%ZIP_NAME%"
powershell -command "Compress-Archive -Path 'world' -DestinationPath '%ZIP_NAME%' -Force"
echo World compactado: %ZIP_NAME%
echo.

if exist "world_backup_temp" rmdir /s /q "world_backup_temp" 2>nul

echo ============================
echo BACKUP COMPLETO!
echo ============================

if "%DESLIGAR%"=="S" (
    echo Desligando em um minuto...
    shutdown /s /t 60
)

pause
endlocal