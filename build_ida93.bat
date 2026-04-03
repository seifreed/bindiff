@echo off
setlocal

echo ========================================
echo BinDiff Build Script for IDA Pro 9.3
echo ========================================
echo.

if "%~1"=="" (
    echo Usage: build_ida93.bat ^<path_to_ida_sdk_93^> [path_to_binexport]
    echo.
    echo Example:
    echo   build_ida93.bat C:\idasdk93
    echo   build_ida93.bat C:\idasdk93 C:\src\binexport
    echo.
    echo Note:
    echo   The IDA installation directory is not enough. You need the
    echo   extracted IDA SDK that contains include\pro.h and ida import libs.
    exit /b 1
)

set "IDA_SDK_PATH=%~1"
if "%~2"=="" (
    set "BINEXPORT_PATH=%~dp0build\binexport"
) else (
    set "BINEXPORT_PATH=%~2"
)

if exist "%IDA_SDK_PATH%\src\include\pro.h" (
    set "IDA_SDK_PATH=%IDA_SDK_PATH%\src"
)

if not exist "%IDA_SDK_PATH%\include\pro.h" (
    echo Error: IDA SDK not found at %IDA_SDK_PATH%
    echo Expected: %IDA_SDK_PATH%\include\pro.h
    if exist "%IDA_SDK_PATH%\ida.exe" (
        echo Detected an IDA installation directory, not the SDK.
    )
    exit /b 1
)

if not exist "%IDA_SDK_PATH%\lib\x64_win_vc_64\ida.lib" (
    echo Error: IDA SDK 9.x import library not found at:
    echo   %IDA_SDK_PATH%\lib\x64_win_vc_64\ida.lib
    exit /b 1
)

if not exist "%BINEXPORT_PATH%\CMakeLists.txt" (
    echo Error: BinExport source tree not found at %BINEXPORT_PATH%
    echo Clone https://github.com/google/binexport there or pass the path
    echo as the second argument.
    exit /b 1
)

set "BUILD_DIR=%~dp0build\out"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

echo.
echo Configuring CMake...
echo --------------------

set "SOURCE_DIR=%~dp0."
cmake -S "%SOURCE_DIR%" -B "%BUILD_DIR%" -G "Visual Studio 17 2022" -A x64 -DCMAKE_INSTALL_PREFIX="%BUILD_DIR%" -DBINDIFF_BINEXPORT_DIR="%BINEXPORT_PATH%" -DIdaSdk_ROOT_DIR="%IDA_SDK_PATH%" -DBINEXPORT_ENABLE_IDAPRO=ON

if errorlevel 1 (
    echo.
    echo CMake configuration failed.
    exit /b 1
)

echo.
echo Building BinDiff...
echo -------------------

cmake --build "%BUILD_DIR%" --config Release --parallel
if errorlevel 1 (
    echo.
    echo Build failed.
    exit /b 1
)

echo.
echo Installing BinDiff...
echo ---------------------

cmake --install "%BUILD_DIR%" --config Release
if errorlevel 1 (
    echo.
    echo Installation failed.
    exit /b 1
)

echo.
echo Build completed successfully.
echo Output: %BUILD_DIR%\bindiff-prefix\
echo.
echo Copy the built plugin DLLs to:
echo   C:\Program Files\IDA Professional 9.0\plugins\
echo.
