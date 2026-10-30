@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%~dp0WorkMode.ps1"
if errorlevel 1 pause
