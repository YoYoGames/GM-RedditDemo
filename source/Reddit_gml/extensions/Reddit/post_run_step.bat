@echo off
set Utils="%~dp0scriptUtils.bat"

:: ######################################################################################
:: Script Logic

:: Always init the script
call %Utils% scriptInit

:: --------------------------------------------------------------------
:: Fetch extension options
:: --------------------------------------------------------------------

:: Version locks
call %Utils% optionGetValue "versionStable" RUNTIME_VERSION_STABLE
call %Utils% optionGetValue "versionBeta" RUNTIME_VERSION_BETA
call %Utils% optionGetValue "versionDev" RUNTIME_VERSION_DEV
call %Utils% optionGetValue "versionLTS" RUNTIME_VERSION_LTS

:: Extension specific
call %Utils% optionGetValue "outputPath" OUTPUT_PATH
call %Utils% optionGetValue "projectName" PROJECT_NAME

:: --------------------------------------------------------------------
:: Validate project name with PowerShell regex. 3–16 of a–z, 0–9, or -
:: --------------------------------------------------------------------
:: Is required
if "%PROJECT_NAME%" == "" (
    call %Utils% logError "Extension option 'Project Name' is required and cannot be empty."
    exit /b 1
)

:: Documentation: App names must be unique, between 3 and 16 characters long, and can contain lowercase letters, numbers, and hyphens.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$n=$env:PROJECT_NAME; if ($n -match '^[a-z0-9-]{3,16}$') { exit 0 } else { exit 1 }" >nul 2>&1

if errorlevel 1 (
    call %Utils% logError "Project name must be 3-16 chars and only contain lowercase letters, numbers, or hyphens."
    exit /b 1
)

:: --------------------------------------------------------------------
:: Verify depedencies
:: --------------------------------------------------------------------
:: Check if we have npm installed (we will need it)
:: call %Utils% logInformation "Detecting installed 'npm' version..."
:: call npm --version
:: if ERRORLEVEL 1 (
::    call %Utils% logError "Failed to detect npm, please install npm in your system."
::)
:: Ensure the update of devvit (if it gets out-dated)
::call npm install -g devvit
::call %Utils% logInformation "Detected devvit tool init processing..."

:: --------------------------------------------------------------------
:: Verify the app exists in Devvit; fail if NOT found
:: --------------------------------------------------------------------
set "DEVVIT_LIST=%TEMP%\devvit_apps_%RANDOM%%RANDOM%.txt"
start "Devvit Apps" /wait cmd /c "devvit list apps > "%DEVVIT_LIST%" 2>&1"

if not exist "%DEVVIT_LIST%" (
    call %Utils% logError "Could not retrieve Devvit app list."
    exit /b 1
)

set "DEVVIT_HIT="
:: FOR /F splits on spaces/tabs and ignores leading whitespace.
for /f "usebackq tokens=1" %%A in ("%DEVVIT_LIST%") do (
    if /I "%%A"=="%PROJECT_NAME%" set "DEVVIT_HIT=1"
)

del /q "%DEVVIT_LIST%" >nul 2>&1

if not defined DEVVIT_HIT (
    call %Utils% logError "Devvit app '%PROJECT_NAME%' was not found. Create the app first: https://developers.reddit.com/new."
    exit /b 1
)

call %Utils% logInformation "Devvit app '%PROJECT_NAME%' confirmed."

:: Resolve the output directory
call %Utils% pathResolve "%YYprojectDir%" "%OUTPUT_PATH%" OUTPUT_DIR

:: --------------------------------------------------------------------
:: Make sure we have a devvit project
:: --------------------------------------------------------------------
:: This section is responsible for creating a project if there is none
:: It will try to do either a git repo or use a local zipped template (on failure)
set "TEMPLATE_ZIP=%~dp0GameMakerRedditTemplate.zip"
if not exist "%OUTPUT_DIR%/%PROJECT_NAME%" (

    :: Make sure the ouput folder exists
    if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%" 2>nul
    pushd "%OUTPUT_DIR%"

    :: If there are no access to the repo use the local zipped template
    if not exist "%TEMPLATE_ZIP%" (
        call %Utils% logError "Fallback zip not found: %TEMPLATE_ZIP%"
        popd
        exit /b 1
    )
    call %Utils% logInformation "Local template project found, expanding..."

    :: Extract as-is
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Expand-Archive -Force '%TEMPLATE_ZIP%' '%PROJECT_NAME%'"

    if ERRORLEVEL 1 (
        call %Utils% logError "Failed to expand fallback zip."
        popd
        exit /b 1
    )
    call %Utils% logInformation "Local template project extracted."

    popd
)

:: We are not ready to run the template projects batch file
:: The tempalte is responsible for what needs to be done.
pushd "%OUTPUT_DIR%/%PROJECT_NAME%"
if not exist "setup-gamemaker-devvit.bat" (
    call %Utils% logError "Current folder '%CD%' not valid devvit GameMaker project."
    popd
    exit /b 1
)
call cmd /c ""setup-gamemaker-devvit.bat" "%YYoutputFolder%" "%PROJECT_NAME%""

:: -------------------------------------------------------------
:: npm run dev in a new visible window, blocking this script
:: -------------------------------------------------------------
start "npm dev - %PROJECT_NAME%" /wait cmd /c "npm install --no-fund --no-audit && npm run dev"
if errorlevel 1 (
  call %Utils% logError "npm run dev failed."
  exit /b 1
)
call %Utils% logInformation "npm run dev exited cleanly."

popd

exit 1
