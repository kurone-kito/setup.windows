@echo off

start /b %HOMEPATH%\Downloads\setup.windows\setup.cmd
(goto) 2>nul & del "%~f0" & cmd /c exit /b 0
