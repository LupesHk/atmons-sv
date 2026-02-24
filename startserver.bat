@echo off
setlocal

set NEOFORGE_VERSION=21.1.219

REM ===========================
REM CONFIG
REM ===========================
set "GIT=git"
set "BRANCH=main"
set "REPO_CLEAN=https://github.com/LupesHk/atmons-sv"
set "PLAYIT_EXE=playit.exe"
set "ZIP_NAME=world.zip"

REM Define Java igual ao batch simples (só define se não existir)
if not defined ATM10_JAVA (
    set ATM10_JAVA=java
)

REM ===========================
REM CARREGAR TOKENS (igual ao batch simples)
REM ===========================
if exist "password.env" (
    echo Carregando tokens...
    for /f "tokens=1,2 delims==" %%a in (password.env) do set "%%a=%%b"
)

set "REPO_TOKEN=https://%GIT_TOKEN%@github.com/LupesHk/atmons-sv"

REM Configurar Git
"%GIT%" config --global user.name "LucasHk" >nul 2>&1
"%GIT%" config --global user.email "lucasgamesbrasil.124@gmail.com" >nul 2>&1

REM ===========================
REM PERGUNTA DO COMMIT
REM ===========================
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
    set /p COMMIT_HASH="Digite o HASH do commit desejado: "
    echo Commit selecionado: %COMMIT_HASH%
    echo.
)

REM ===========================
echo Verificando git...
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

REM ===========================
REM INICIALIZAR REPO SE NECESSARIO
REM ===========================
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
    for /f "tokens=2" %%b in ('"%GIT%" branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%b"
    if not defined CURRENT_BRANCH set "CURRENT_BRANCH=unknown"
    if not "%CURRENT_BRANCH%"=="main" (
        "%GIT%" checkout main 2>nul
    )
)

REM ===========================
REM SINCRONIZANDO
REM ===========================
echo.
echo SINCRONIZANDO COM GITHUB...

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

REM ===========================
echo VERIFICANDO PLAYIT...
tasklist /FI "IMAGENAME eq playit.exe" | find /I "playit.exe" >nul
if %errorlevel%==0 (
    echo Playit ja esta aberto.
) else (
    echo Iniciando Playit...
    start "" /min "%PLAYIT_EXE%" --secret "%PLAYIT_SECRET%"
)
echo.

REM ===========================
echo AVISANDO WHATSAPP: SERVER ON
if exist "whats\bot.js" (
    cd whats
    node bot.js on
    cd ..
) else (
    echo Bot WhatsApp nao encontrado.
)

echo ===========================
echo INICIANDO SERVIDOR...
echo ===========================
"%ATM10_JAVA%" @user_jvm_args.txt @libraries\net\neoforged\neoforge\%NEOFORGE_VERSION%\win_args.txt nogui

echo SERVIDOR FOI FECHADO.

echo AVISANDO WHATSAPP: SERVER OFF
if exist "whats\bot.js" (
    cd whats
    node bot.js off
    cd ..
)
echo.

:WAIT_JAVA
tasklist | find /i "java.exe" >nul
if %errorlevel%==0 (
    timeout /t 1 >nul
    goto WAIT_JAVA
)

echo.
echo BACKUP SERA INICIADO AGORA.

echo.
echo Deseja desligar o PC ao final do backup? (S/N)
choice /T 10 /D S /M "Se nao responder, sera considerado SIM: "

if %errorlevel%==2 (
    set "DESLIGAR=N"
) else (
    set "DESLIGAR=S"
)

echo Resposta final: %DESLIGAR%
echo.

REM ===========================
echo COMMITANDO TUDO...
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

REM ===========================
echo COMPACTANDO WORLD...
if exist "%ZIP_NAME%" del "%ZIP_NAME%"
powershell -command "Compress-Archive -Path 'world' -DestinationPath '%ZIP_NAME%' -Force"
echo World compactado: %ZIP_NAME%
echo.

if exist "world_backup_temp" rmdir /s /q "world_backup_temp" 2>nul

echo ============================
echo BACKUP COMPLETO!
echo ============================

if "%DESLIGAR%"=="S" (
    echo Desligando em 30 segundos...
    shutdown /s /t 30
)

pause
endlocal