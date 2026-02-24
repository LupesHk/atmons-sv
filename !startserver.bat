@echo off
title Servidor ATMONS - by Lupes.
setlocal enabledelayedexpansion

SET "BRANCH=main"
SET "REPO_URL=https://github.com/LupesHk/atmons-sv"

SET "PLAYIT_EXE=playit.exe"
SET "PLAYIT_SECRET="

SET "ZIP_NAME=world.zip"

SET "NEOFORGE_VERSION=21.1.219"
SET "JAVA_CMD=java @user_jvm_args.txt @libraries\net\neoforged\neoforge\%NEOFORGE_VERSION%\win_args.txt nogui"

REM ===========================
REM (Opcional) Carregar secrets locais (nao vai pro Git)
REM ===========================
if exist "password.env" (
    echo Carregando variaveis do password.env...
    for /f "usebackq tokens=1,* delims==" %%a in ("password.env") do (
        set "%%a=%%b"
    )
) else (
    echo Aviso: password.env nao encontrado (ok se nao precisar).
)

echo.
echo ================================
echo Deseja puxar o commit mais recente?
echo Se nao responder em 3 segundos, sera considerado SIM.
echo ================================
choice /T 3 /D S /M "Puxar commit mais recente? (S/N): "

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

echo ===========================
echo VERIFICANDO GIT (do sistema)...
echo ===========================
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo ERRO: git nao encontrado no PATH.
    echo Instale o Git (ou reinstale o GitHub Desktop com Git incluido).
    pause
    exit /b 1
)

REM ===========================
REM Verifica se e um repo Git
REM ===========================
git rev-parse --is-inside-work-tree >nul 2>&1
if %errorlevel% neq 0 (
    echo ERRO: Esta pasta nao e um repositorio Git.
    echo Dica: Use o GitHub Desktop para clonar o repo nesta pasta.
    echo Repo: %REPO_URL%
    pause
    exit /b 1
)

REM Garante branch main
for /f "delims=" %%b in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%b"
if /I not "%CURRENT_BRANCH%"=="%BRANCH%" (
    echo Mudando para branch %BRANCH%...
    git checkout %BRANCH% 2>nul || git checkout -b %BRANCH%
)

echo.
echo ================================
echo SINCRONIZANDO COM GITHUB
echo ================================

REM (Importante) Nao altera remote. GitHub Desktop cuida da auth.
git fetch origin

REM Evita perder alteracoes locais: guarda stash automatico, reseta, e aplica de volta
git stash push -u -m "auto-stash before sync" >nul 2>&1

if "%PULL_RECENTE%"=="S" (
    echo Atualizando para o mais recente em origin/%BRANCH%...
    git reset --hard origin/%BRANCH%
) else (
    echo Indo para o commit especifico...
    git checkout %COMMIT_HASH%
)

REM volta stash se existir
git stash list | find /i "auto-stash before sync" >nul
if %errorlevel%==0 (
    git stash pop >nul 2>&1
)

REM limpa lixo mantendo secrets e whats
git clean -fd -e password.env -e whats/ >nul 2>&1

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
    if not exist "%PLAYIT_EXE%" (
        echo Aviso: %PLAYIT_EXE% nao encontrado.
    ) else (
        start "" /min "%PLAYIT_EXE%" --secret "%PLAYIT_SECRET%"
    )
)
echo.

echo ===========================
echo AVISANDO WHATSAPP: SERVER ON
echo ===========================
if exist "whats\bot.js" (
    pushd whats
    node bot.js on
    popd
) else (
    echo Bot WhatsApp nao encontrado.
)

echo ===========================
echo INICIANDO SERVIDOR...
echo ===========================
%JAVA_CMD%

echo SERVIDOR FOI FECHADO.
echo Avisando WhatsApp: SERVER OFF

if exist "whats\bot.js" (
    pushd whats
    node bot.js off
    popd
)
echo.

:WAIT_JAVA
tasklist | find /i "java.exe" >nul
if %errorlevel%==0 (
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

if %errorlevel%==2 (
    set "DESLIGAR=N"
) else (
    set "DESLIGAR=S"
)

echo Resposta final: %DESLIGAR%
echo.

echo ===========================
echo COMMITANDO + PUSH (via GitHub Desktop auth)...
echo ===========================

REM Garante que password.env nao entre no commit
if not exist ".gitignore" (
    echo Criando .gitignore...
    (
        echo password.env
        echo logs/
        echo crash-reports/
        echo debug/
        echo world_backup_temp/
        echo *.log
        echo hs_err_*.log
        echo .cache/
        echo *.zip
        echo backups/
        echo .vscode/
        echo .idea/
        echo *.iml
        echo Thumbs.db
        echo .DS_Store
        echo desktop.ini
    ) > .gitignore
)

git add -A
git diff --cached --quiet
if %errorlevel% equ 0 (
    echo Nenhuma mudanca detectada para commit.
) else (
    git commit -m "Backup automatico completo - %date% %time%"
    echo Enviando para GitHub...
    git push origin %BRANCH%
    if %errorlevel% neq 0 (
        echo ERRO no push. Abra o GitHub Desktop e faca o Push por la (pode pedir login).
    ) else (
        echo Backup enviado para GitHub!
    )
)

echo.
echo ===========================
echo COMPACTANDO WORLD...
echo ===========================
IF EXIST "%ZIP_NAME%" del "%ZIP_NAME%"
powershell -command "Compress-Archive -Path 'world' -DestinationPath '%ZIP_NAME%' -Force"
echo World compactado em: %ZIP_NAME%
echo.

echo ===========================
echo LIMPEZA DE ARQUIVOS TEMPORARIOS
echo ===========================
if exist "world_backup_temp" rmdir /s /q "world_backup_temp" 2>nul
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