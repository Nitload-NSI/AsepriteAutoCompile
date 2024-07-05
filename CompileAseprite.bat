@echo off
setlocal
cls

echo Before compiling, please read the fallowing notes:
echo=
echo=
echo=
echo *****
echo 1. Befor compiling, you must install VisualStudio and Desktop Development with C++ modeul mannually
echo 2. Windows10 SDK ver. 10.0.18362.0 is required
echo 3. Additional tolls like git, camke and ninja will automatically checke and installed
echo 4. This script can only compile aseprite but not installing it.
echo 5. Checking out connection to international network.
echo *****
echo=
echo=
echo=
echo If confirm all points, enter "compile" to start compiling. Otherwise, press other keys to exit
set /p usrstat=
if "%usrstat%"=="compile" (
    echo making preparations
) else (
    pause
    exit /b 0
)

set current_env=%cd%
mkdir Aseprite
set compile_env=%cd%\Aseprite

REM Step 1: Check if ninja and cmake are installed, if not, install them

echo Checking tools dependency...
set /a installcount=0
set dependency_path = ""
for /f "delims=" %%i in ('where ninja 2^>nul') do set "dependency_path=%%i"
if dependency_path=="" (
    echo Installing ninja...
    winget install Ninja-build.Ninja
    set installcount=1
) else (
    echo Find ninja installed at %dependency_path%
)

for /f "delims=" %%i in ('where cmake 2^>nul') do set "dependency_path=%%i"
if dependency_path=="" (
    echo Installing cmake...
    Winget install -e --id Kitware.CMake
    set installcount=1
) else (
    echo Find cmake installed at %dependency_path%
)

for /f "delims=" %%i in ('where git 2^>nul') do set "dependency_path=%%i"
if dependency_path=="" (
    echo Installing cmake...
    winget install --id Git.Git -e --source winget
    set installcount=1
) else (
    echo Find Git installed at %dependency_path%
)

if %installcount% neq 0 (
    echo Some tools are installed
    echo Please restart this script to load necessary env paths
    echo Press enter to exit
    pause >nul
    exit 
)

REM Step 2: building repo and skia depdency

cd /d %compile_env%
if exist aseprite (
    cd aseprite
    git pull
    git submodule update --init --recursive
    cd /d %compile_env%
) else (
    git clone --recursive https://github.com/aseprite/aseprite.git
    cd aseprite
    git submodule update --init --recursive
    cd /d %compile_env%
)
if %errorlevel% neq 0 (
    cd /d %current_env%
    exit /b %errorlevel%
)
curl -s https://api.github.com/repos/aseprite/skia/releases/latest > %compile_env%\dskiainfo.json
findstr /c:"tag_name" dskiainfo.json > temp.txt
set /p line=<temp.txt
set tagname=%line:~15,-2%
del dskiainfo.json
del temp.txt
echo Downloading skia from https://github.com/aseprite/skia/releases/download/%tagname%/Skia-Windows-Release-x64.zip
curl -o dskia.zip https://ghproxy.net/https://github.com/aseprite/skia/releases/download/%tagname%/Skia-Windows-Release-x64.zip
if %errorlevel% neq 0 (
    cd /d %current_env%
    exit /b %errorlevel%
)

REM Step 3: Get the location of Dev Command Prompt of VS2022
echo Loading Developer Command Prompt for VisualStudio
set "vswherePath=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%vswherePath%" (
    echo vswhere.exe not found. Please install it from https://github.com/microsoft/vswhere.
    exit /b 1
)
for /f "tokens=*" %%i in ('"%vswherePath%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath') do set "vsInstallPath=%%i"
if "%vsInstallPath%"=="" (
    cls
    echo Visual Studio not found.
    echo Please install VisualStudio and C++ Desktop Dev modeul before compiling.
    exit /b 1
) else (
    echo VisualStudio installation find at %vsInstallPath%.
)

set "DevCmdPath=%vsInstallPath%\Common7\Tools\VsDevCmd.bat"
if not exist "%DevCmdPath%" (
    echo Developer Command Prompt not found at %DevCmdPath%.
) else (
    echo Promt find at %DevCmdPath%.
)

REM Step 4: Set a file path variable
mkdir dskia
tar -xf dskia.zip -C dskia
if %errorlevel% neq 0 (
    cd /d %current_env%
    exit /b %errorlevel%
)
set "dskia=%compile_env%\dskia"
cd aseprite
if exist build (
    rmdir /s /q build
)
mkdir build
echo Preparations down, press enter to start compiling
pause >nul
cls

REM Step 5: Run Dev Command Prompt of VS2022 with -arch=x64
call "%DevCmdPath%" -arch=x64

REM Step 6: Navigate to the build folder and run cmake
cd /d %compile_env%\aseprite\build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLAF_BACKEND=skia -DSKIA_DIR=%dskia% -DSKIA_LIBRARY_DIR=%dskia%\out\Release-x64 -DSKIA_LIBRARY=%dskia%\out\Release-x64\skia.lib -G Ninja ..
if %errorlevel% neq 0 (
    cd /d %compile_env%
    exit /b %errorlevel%
)
echo Compiling finished, linking

REM Step 7: Run ninja to link
ninja aseprite
if %errorlevel% neq 0 (
    cd /d %compile_env%
    exit /b %errorlevel%
)

REM Step 8: Export package
cls
cd /d %compile_env%
mkdir bin
xcopy %compile_env%\Aseprite\build\bin %compile_env%\bin /s /e /y

echo Compile finished, please find aseprite on %compile_env%\bin.
echo Press Enter to exit...
endlocal
pause >nul

