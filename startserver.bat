@echo off
title Servidor ATMONS - by Lupes.

cd /d "%~dp0"

REM ===========================
REM CONFIG
REM ===========================
SET "GIT=git"
SET "BRANCH=main"

SET "REPO_CLEAN=https://github.com/LupesHk/atmons-sv"
SET "GIT_TOKEN="
SET "REPO_TOKEN="

SET "PLAYIT_EXE=playit.exe"
SET "PLAYIT_SECRET="

SET "ZIP_NAME=world.zip"

SET "NEOFORGE_VERSION=21.1.219"
SET "JAVA_CMD=java @user_jvm_args.txt @libraries\net\neoforged\neoforge\%NEOFORGE_VERSION%\win_args.txt nogui"

REM ===========================
REM CARREGAR TOKENS DO ARQUIVO
REM ===========================
if exist "password.env" (
    echo Carregando tokens...
    for /f "usebackq delims=" %%a in ("password.env") do (
        for /f "tokens=1,* delims==" %%b in ("%%a") do (
            set "%%b=%%c"
        )
    )
) else (
    echo ERRO: Arquivo password.env nao encontrado!
    pause
    exit /b 1
)

SET "REPO_TOKEN=https://%GIT_TOKEN%@github.com/LupesHk/atmons-sv"

REM Configurar usuario do Git (se já não configurou)
"%GIT%" config --global user.name "LucasHk" 2>nul
"%GIT%" config --global user.email "lucasgamesbrasil.124@gmail.com" 2>nul

REM ===========================
REM PERGUNTA DO COMMIT
REM ===========================
echo.
echo ================================
echo Deseja puxar o commit mais recente?
echo Se nao responder em 3 segundos, sera considerado SIM.
echo ================================
choice /T 3 /D S /M "Puxar commit mais recente? (S/N): "

if "%errorlevel%"=="2" (
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
REM ===========================
where git >nul 2>&1
if not "%errorlevel%"=="0" (
    echo ERRO: git nao encontrado no PATH.
    echo Instale o Git (ou reinstale o GitHub Desktop marcando Add to PATH).
    pause
    exit /b 1
)

REM ===========================
REM INICIALIZAR REPO SE NECESSARIO
REM ===========================
"%GIT%" rev-parse --git-dir >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Repositorio Git nao encontrado na pasta raiz.
    echo Inicializando novo repositorio...

    "%GIT%" init
    "%GIT%" branch -M main
    "%GIT%" remote add origin "%REPO_TOKEN%"

    if not exist ".gitignore" (
        echo Criando .gitignore...
        (
            echo # Arquivos sensiveis
            echo password.env
            echo.
            echo # Pastas temporarias
            echo logs/
            echo crash-reports/
            echo debug/
            echo world_backup_temp/
            echo.
            echo # Arquivos de sistema/desempenho
            echo *.log
            echo hs_err_*.log
            echo.
            echo # Cache
            echo .cache/
            echo.
            echo # Backups locais
            echo *.zip
            echo backups/
            echo.
            echo # IDE/Editor
            echo .vscode/
            echo .idea/
            echo *.iml
            echo.
            echo # Sistema operacional
            echo Thumbs.db
            echo .DS_Store
            echo desktop.ini
        ) > .gitignore
    )

    echo Fazendo primeiro pull do GitHub...
    "%GIT%" fetch origin
    "%GIT%" reset --hard origin/main
    "%GIT%" clean -fd -e password.env -e whats/
) else (
    echo Repositorio Git encontrado.

    REM Obter branch atual de forma segura
    for /f "delims=" %%b in ('"%GIT%" branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%b"
    
    if not defined CURRENT_BRANCH set "CURRENT_BRANCH=unknown"

    if /I not "%CURRENT_BRANCH%"=="main" (
        echo Mudando para branch main...
        "%GIT%" checkout main 2>nul
        if "%errorlevel%" neq 0 (
            "%GIT%" checkout -b main
        )
    )
)

REM ===========================
REM SINCRONIZANDO REPO
REM ===========================
echo.
echo ================================
echo SINCRONIZANDO COM GITHUB
echo ================================

"%GIT%" remote set-url origin "%REPO_TOKEN%"

REM Reset seguro mantendo arquivos importantes
"%GIT%" fetch origin
"%GIT%" reset --hard origin/main
"%GIT%" clean -fd -e password.env -e whats/

if "%PULL_RECENTE%"=="S" (
    echo Fazendo pull da branch main...
    "%GIT%" pull origin %BRANCH% --rebase --autostash
) else (
    if defined COMMIT_HASH (
        echo Fazendo fetch do commit especifico...
        "%GIT%" fetch origin
        "%GIT%" checkout %COMMIT_HASH%
    ) else (
        echo AVISO: Commit hash nao definido. Pulando checkout.
    )
)

"%GIT%" remote set-url origin "%REPO_CLEAN%"
echo Sincronizacao concluida!
echo.

REM ===========================
echo VERIFICANDO PLAYIT...
REM ===========================
tasklist /FI "IMAGENAME eq playit.exe" | find /I "playit.exe" >nul
if "%errorlevel%"=="0" (
    echo Playit ja esta aberto.
) else (
    echo Iniciando Playit...
    start "" /min "%PLAYIT_EXE%" --secret "%PLAYIT_SECRET%"
)
echo.

REM ===========================
echo AVISANDO WHATSAPP: SERVER ON
REM ===========================
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
"%JAVA_CMD%"

echo SERVIDOR FOI FECHADO.
echo Avisando WhatsApp: SERVER OFF

if exist "whats\bot.js" (
    cd whats
    node bot.js off
    cd ..
)
echo.

:WAIT_JAVA
tasklist | find /i "java.exe" >nul
if "%errorlevel%"=="0" (
    timeout /t 10 >nul
    goto WAIT_JAVA
)

echo.
echo ============================
echo BACKUP SERA INICIADO AGORA.
echo ============================

echo.
echo Deseja desligar o PC ao final do backup? (S/N)
choice /T 10 /D S /M "Se nao responder, sera considerado SIM: "

if "%errorlevel%"=="2" (
    set "DESLIGAR=N"
) else (
    set "DESLIGAR=S"
)

echo Resposta final: %DESLIGAR%
echo.

REM ===========================
echo COMMITANDO TUDO NO GIT...
REM ===========================
echo Preparando backup para GitHub...
"%GIT%" remote set-url origin "%REPO_TOKEN%"

"%GIT%" add -A

"%GIT%" diff --cached --quiet
if "%errorlevel%"=="0" (
    echo Nenhuma mudanca detectada para commit.
) else (
    echo Criando commit com as mudancas...
    "%GIT%" commit -m "Backup automatico completo - %date% %time%"
    echo Enviando para GitHub...
    "%GIT%" push origin %BRANCH% --force
    echo Backup completo enviado para GitHub!
)

"%GIT%" remote set-url origin "%REPO_CLEAN%"
echo.

REM ===========================
echo COMPACTANDO WORLD...
REM ===========================
IF EXIST "%ZIP_NAME%" del "%ZIP_NAME%"
powershell -command "Compress-Archive -Path 'world' -DestinationPath '%ZIP_NAME%' -Force"
echo World compactado em: %ZIP_NAME%
echo.

REM ===========================
echo LIMPEZA DE ARQUIVOS TEMPORARIOS
REM ===========================
if exist "world_backup_temp" (
    rmdir /s /q "world_backup_temp"
)

echo.
echo ============================
echo BACKUP COMPLETO!
echo ============================
echo.

if "%DESLIGAR%"=="S" (
    echo Desligando em 30 segundos...
    shutdown /s /t 30
)

pause