@echo off
setlocal enabledelayedexpansion

if /i "%~1" equ "" goto usageHelp
if /i "%~1" equ "?" goto usageHelp
if /i "%~1" equ "/?" goto usageHelp

set tempdir=M:\temp\temp%random%
mkdir %tempdir%
set default_preset=veryslow
set default_chroma=yuv422p
set default_crfValue=20

if not exist "%~1" (echo "%~1" does not exist
goto end)

if /i "%~2" equ "" (set codec=h264) else (set codec=%~2)
if /i "%codec%" neq "h264" if /i "%codec%" neq "h265" (echo codec "%codec%" unsupported
goto usageHelp)

if /i "%~3" equ "" (set preset=%default_preset%) else (set preset=%~3)
if /i "%preset%" neq "ultrafast" if /i "%preset%" neq "superfast" if /i "%preset%" neq "veryfast" if /i "%preset%" neq "faster" if /i "%preset%" neq "fast" if /i "%preset%" neq "medium" if /i "%preset%" neq "slow" if /i "%preset%" neq "slower" if /i "%preset%" neq "veryslow" if /i "%preset%" neq "placebo" (echo preset "%preset%" unsupported
goto usageHelp)

if /i "%~4" equ "" set resolution=other
if /i "%~4" equ "1080p" (set resolution=1920x1080
set quality=1080p)
if /i "%~4" equ "720p" (set resolution=1280x720
set quality=720p)
if /i "%~4" equ "480p" (set resolution=854x480
set quality=480p)
if /i "%resolution%" neq "other" if /i "%resolution%" neq "1920x1080" if /i "%resolution%" neq "1280x720" if /i "%resolution%" neq "854x480" (echo resolution "%~4" not supported, defaulting to input video size
set resolution=other)

call :parsePath "%~1"

set inputVideo_FullNameAndPath=%fullpath%
set inputVideo_Path=%fullfolderpath%
set inputVideo_Name=%filename%
set inputVideo_Extension=%extension%
set tempFileName=temp_rawvideo

if /i "%codec%" equ "h264" goto h264
if /i "%codec%" equ "h265" goto h265

:h264
if /i "%resolution%" equ "other" set outputname=%inputVideo_Path%\%inputVideo_Name%.h264.%extension%
if /i "%resolution%" neq "other" set outputname=%inputVideo_Path%\%inputVideo_Name%.%quality%.h264.%extension%
if exist "%outputname%" del "%outputname%"

if "%resolution%" equ "other" ffmpeg.exe -i "%inputVideo_FullNameAndPath%" -crf %default_crfValue% -preset %preset% -c:a aac -strict experimental -b:a 192k "%outputname%"
if "%resolution%" neq "other" ffmpeg.exe -i "%inputVideo_FullNameAndPath%" -vf scale=%resolution% -crf %default_crfValue% -preset %preset% -c:a aac -strict experimental -b:a 192k "%outputname%"
goto end

:h265
if exist "%tempdir%\%tempfilename%.y4m" del "%tempdir%\%tempfilename%.y4m"
if /i "%resolution%" equ "other" set outputname=%inputVideo_Path%\%inputVideo_Name%.h265
if /i "%resolution%" neq "other" set outputname=%inputVideo_Path%\%inputVideo_Name%.%quality%.h265
if exist "%outputname%" del "%outputname%"

if /i "%resolution%" equ "other" ffmpeg -i "%inputVideo_FullNameAndPath%" -an -sn -pix_fmt %default_chroma% "%tempdir%\%tempfilename%.y4m"
if /i "%resolution%" neq "other" ffmpeg -i "%inputVideo_FullNameAndPath%" -an -sn -vf scale=%resolution% -pix_fmt %default_chroma% "%tempdir%\%tempfilename%.y4m"
x265 --input "%tempdir%\%tempfilename%.y4m" --preset %preset% --crf %default_crfValue% --output "%outputname%"

if exist "%tempdir%\%tempfilename%.y4m" del "%tempdir%\%tempfilename%.y4m"
goto end


:functions
::parsePath returns drive, extension, lastEntry, filename, foldername, filepath, folderpath (no trailing \ either at the start or end, and not incl the last entry), fullfolderpath (again, no last entry) and fullpath
::if not valid will return nul for a value (check for it, especially folderpath will be nul if asked to parse d:\), maximum depth=26
::a non-serialized version with spaces and comments for debuging and alteration is available at D:\workspace\generalInfo\code snippets\strings\buildPathv2.bat
::Syntax:
::echo drive=%drive%                                       &:: returns nul if driveFlag ":" was not set
::echo extension=%extension%                       &:: just the extension no dot, but returns nul if folderFlag "\" is set
::echo lastEntry=%lastEntry%                          &:: consistently returns folder/filename in rawFormat
::echo filename=%filename%                           &:: filename with no extension but returns nul if folderFlag "\" was set
::echo foldername=%foldername%                 &:: returns 2nd to last name in path, unless folderFlag, then returns lastEntry
::echo filepath=%filepath%                               &:: does not include last entry (same as folderpath)
::echo folderpath=%folderpath%                      &:: does not include last entry (same as filepath)
::echo fullfolderpath=%fullfolderpath%             &:: this is the folderpath with the drive letter but not lastEntry
::echo fullpath=%fullpath%                                &:: this is the folderpath with the drive letter and lastEntry
::Example: call :parsePath  d:\my\lo ng\p ath.txt
::echo drive=%drive%                                       d:
::echo extension=%extension%                       txt
::echo lastEntry=%lastEntry%                          p ath.txt
::echo filename=%filename%                          path
::echo foldername=%foldername%                 p ath.txt
::echo filepath=%filepath%                               my\lo ng
::echo folderpath=%folderpath%                      my\lo ng
::echo fullfolderpath=%fullfolderpath%            d:\my\lo ng
::echo fullpath=%fullpath%                                d:\my\lo ng\p ath.txt
:parsePath
if "%~1" equ "" goto :eof
set folderFlag=false&set rawDriveFlag=false&set oneEntryFlag=false&set twoEntryFlag=false&set rawInput=%~1
if /i "%rawInput:~-1%" equ "\" set folderFlag=true
if /i "%rawInput:~-1%" equ "\" set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
set windows_extension=%~x1&set windows_filename_noext=%~n1
for /f "tokens=1-26 delims=\" %%a in ("%rawInput%") do (set entry0=%%a&set entry1=%%b&set entry2=%%c&set entry3=%%d&set entry4=%%e&set entry5=%%f&set entry6=%%g&set entry7=%%h&set entry8=%%i&set entry9=%%j&set entry10=%%k&set entry11=%%l&set entry12=%%m&set entry13=%%n&set entry14=%%o&set entry15=%%p&set entry16=%%q&set entry17=%%r&set entry18=%%s&set entry19=%%t&set entry20=%%u&set entry21=%%v&set entry22=%%w&set entry23=%%x&set entry24=%%y&set entry25=%%z)
set counter=0
for /l %%a in (0,1,25) do if /i "!entry%%a%!" neq "" set /a counter+=1
set /a maxPaths=%counter%-1
if "!entry0:~-1!" equ ":" set rawDriveFlag=true
if %maxPaths% equ 0 (set oneEntryFlag=true
goto assignOutput)
if %maxPaths% equ 1 (set twoEntryFlag=true
goto assignOutput)
if exist tempFilePaths.txt del tempFilePaths.txt&set string=invalid
set /a maxPaths=%counter%-2
for /l %%a in (1,1,%maxPaths%) do echo !entry%%a%!>>tempFilePaths.txt
if exist tempFilePaths.txt set /p string=<tempFilePaths.txt
for /f "skip=1 tokens=*" %%a in (tempFilePaths.txt) do set string=!string!\%%a
if exist tempFilePaths.txt del tempFilePaths.txt
set secondToLastEntry=!entry%maxPaths%!
set /a maxPaths=%counter%-1
set lastEntry=!entry%maxPaths%!
:assignOutput
if /i "%rawDriveFlag%" equ "true" (set drive=!entry0!)
if /i "%rawDriveFlag%" neq "true" (set drive=nul)
if "%oneEntryFlag%" equ "true" if /i "%rawDriveFlag%" equ "true" (set lastEntry=!entry0!&set foldername=nul&set filepath=nul&set folderpath=nul&set fullfolderpath=!entry0!&set fullpath=!entry0!&goto finalCleanup)
if "%oneEntryFlag%" equ "true" if /i "%rawDriveFlag%" equ "false" (set lastEntry=!entry0!&set foldername=!entry0!&set filepath=nul&set folderpath=nul&set fullfolderpath=nul&set fullpath=nul&goto finalCleanup)
if "%twoEntryFlag%" equ "true" if /i "%rawDriveFlag%" equ "true" (set lastEntry=!entry1!&set foldername=!entry1!&set filepath=nul&set folderpath=nul&set fullfolderpath=!entry0!&set fullpath=!entry0!&goto finalCleanup)
if "%twoEntryFlag%" equ "true" if /i "%rawDriveFlag%" neq "true" (set lastEntry=!entry1!&set foldername=!entry0!&set filepath=!entry0!&set folderpath=!entry0!&set fullfolderpath=!entry0!&set fullpath=!entry0!&goto finalCleanup)
if /i "%folderFlag%" neq "true" (set lastEntry=%lastEntry%&set foldername=%lastEntry%&set filepath=%string%&set folderpath=%string%&set fullfolderpath=!entry0!\%string%&set fullpath=!entry0!\%string%\%lastEntry%&goto finalCleanup)
if /i "%folderFlag%" equ "true" (set lastEntry=%lastEntry%&set foldername=%lastEntry%&set filepath=%string%&set folderpath=%string%&set fullfolderpath=!entry0!\%string%&set fullpath=!entry0!\%string%\%lastEntry%&goto finalCleanup)
echo unspecified error&goto :eof
:finalCleanup
if /i "%windows_extension%" equ "" (set extension=nul) else (set extension=%windows_extension%)
for /f "delims=." %%a in ("%extension%") do set extension=%%a
if /i "%folderFlag%" neq "true" (set filename=%windows_filename_noext%)
if /i "%folderFlag%" equ "true" (set extension=nul&set filename=nul)
goto :eof

::defaults h264, 720p, "slow" quality
:usageHelp
echo.
echo   "encode" re-encodes an existing file into h264/h265 formats
echo   h264 encoding preserves containers but h265 outputs a raw .h265 file
echo   Dependencies: ffmpeg.exe, x265.exe (compiled w/desired bit depth)
echo   Syntax:
echo   encode myfile.mp4 {h264/h265} {slow} {720p}
echo   Examples:
echo   encode "c:\myfile.mkv" 
echo   encode "c:\myfile.mkv" h264 
echo   encode "c:\myfile.mkv" h264 slow
echo   encode "c:\myfile.mkv" "" slow
echo   encode "c:\myfile.mkv" h265 slow 720p
echo   encode "c:\myfile.mkv" h265 "" 720p
:end
if exist "%tempdir%" rmdir /s /q "%tempdir%"
endlocal
