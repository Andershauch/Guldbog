@echo off
rem Fetches the newest Guldbog from GitHub into this folder.
cd /d "%~dp0"
git pull
echo.
echo Faerdig. Skriv /reload i spillet for at bruge den nye version.
pause
