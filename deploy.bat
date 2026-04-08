@echo off
REM === Deploy RE2 Adaptive Triggers Mod ===
REM Копирует файлы мода из рабочей папки в папку игры
REM Запускай после любых изменений в коде

set SRC=%~dp0RE2AdaptiveMod\reframework
set GAME=E:\SteamLibrary\steamapps\common\RESIDENT EVIL 2  BIOHAZARD RE2

echo Copying mod files...

xcopy /Y "%SRC%\autorun\DualsenseX.lua" "%GAME%\reframework\autorun\" >nul
xcopy /Y "%SRC%\autorun\DualsenseX\*.lua" "%GAME%\reframework\autorun\DualsenseX\" >nul
xcopy /Y "%SRC%\data\DualSenseX\weapon_dsx.lua" "%GAME%\reframework\data\DualSenseX\" >nul
xcopy /Y "%SRC%\data\DualSenseX\payload.json" "%GAME%\reframework\data\DualSenseX\" >nul
xcopy /Y "%SRC%\data\DualSenseX\weapon_dsx.lua" "%GAME%\DualSenseX\" >nul
xcopy /Y "%SRC%\data\DualSenseX\payload.json" "%GAME%\DualSenseX\" >nul

echo Done! Now reload scripts in REFramework (Reset Scripts)
pause
