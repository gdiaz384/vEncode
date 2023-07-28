@echo off
setlocal enabledelayedexpansion
pushd "%~dp1"

::set program options
::true, false
set extractSubtitlesDefaultSetting=false
::in bytes, default is 250 KB    ex. 16152576=15.774 MB; bytes *1024 = KB; KB * 1000 = MB
set minimumFileSizeToProcess=256000

::read input
:: batchMode for usage as: extractAudio *
if /i "%~2" equ "" set extractSubtitles=%extractSubtitlesDefaultSetting%
if /i "%~2" neq "" set extractSubtitles=%~2
if /i "%~1" equ "*" goto batchMode

::input validation
if /i "%~nx1" equ "" (echo No input file specified.
goto end
)
if not exist "%~nx1" (echo Input file "%~nx1" not found.
goto end
)

::Does not work for files with () in the name
::for /f "usebackq" %%i in ("%~nx1") do set fileSize=%%~zi
::@echo on

set fileSizeFile=fileSize.%random%.txt
robocopy . . "%~nx1" /l /nocopy /is /njh /njs /ndl /nc /bytes > %fileSizeFile%
for /f %%i in (%fileSizeFile%) do set fileSize=%%i
::echo fileSize="%fileSize%"
if %fileSize% lss %minimumFileSizeToProcess% (echo Skipping file "%~nx1". Too small.
echo    "%fileSize%" is less than minimum size of "%minimumFileSizeToProcess%"
goto end
)
::goto end

if /i "%extractSubtitles%" neq "true" if /i "%extractSubtitles%" neq "false" (echo Error. extractSubtitles mode of "%extractSubtitles%" is unrecognized. Must be true or false.
goto end)

::set local variables
set tempffprobeFile=temp.%random%.txt
set codecLibrary=copy
set ffprobeexe=ffprobe.exe
set ffmpegexe=ffmpeg.exe

::core logic
call :extractAudio "%~nx1"


::end program
goto end


::start functions
::Usage: extractAudio *
:batchMode
set tempfile=temp.%random%.txt

dir /b *.mkv >> %tempfile% 2>nul
dir /b *.mka >> %tempfile% 2>nul
dir /b *.mp4 >> %tempfile% 2>nul
dir /b *.wmv >> %tempfile% 2>nul
dir /b *.mpg >> %tempfile% 2>nul
dir /b *.webm >> %tempfile% 2>nul
dir /b *.flv >> %tempfile% 2>nul
dir /b *.avi >> %tempfile% 2>nul
dir /b *.ogg >> %tempfile% 2>nul
dir /b *.asf >> %tempfile% 2>nul
dir /b *.3gp >> %tempfile% 2>nul
dir /b *.m2ts >> %tempfile% 2>nul

dir /b *.m4a >> %tempfile% 2>nul
dir /b *.ac3 >> %tempfile% 2>nul
dir /b *.mp3 >> %tempfile% 2>nul
dir /b *.aac >> %tempfile% 2>nul
dir /b *.opus >> %tempfile% 2>nul
dir /b *.flac >> %tempfile% 2>nul
dir /b *.thd >> %tempfile% 2>nul
dir /b *.wav >> %tempfile% 2>nul

set fileCount=1
for /f "tokens=*" %%i in (%tempfile%) do (
set file[!fileCount!]=%%i
set /a fileCount+=1
)

set /a fileCount-=1
echo   filecount=%fileCount%

::for each file extract out the audio
for /L %%i in (1,1,%fileCount%) do (
echo  processingfile=!file[%%i]!
call extractAudio "!file[%%i]!" %extractSubtitles%
)

if exist "%tempfile%" del "%tempfile%"
goto end


::Usage: call :extractAudio myVideoFile.mp4
::Will extract any audio tracks present
:extractAudio
if /i "%~1" equ "" (echo error 
goto :eof)
set audioOnlyFile=false
set extractAudioFunctFileName=%~nx1
set inputFileNameNoExt=%~n1
set inputFileExtension=%~x1
set audioStreamCount=0
set mergedFromM2tsFileName=invalid

if /i "%extractSubtitles%" equ "true" mkvmerge -o "%inputFileNameNoExt%.subtitlesAndChapters.mkv" --no-video --no-audio "%extractAudioFunctFileName%"

::@echo on
::ffprobe does not report the correct number of audio streams when working with m2ts files sometimes, so create a temporary mkv file as a workaround
::using parentheses here to reduce the number of "if" comparisons creates a bug when parsing filenames that use parentheses
if /i "%inputFileExtension%" equ ".m2ts" set mergedFromM2tsFileName=%inputFileNameNoExt%.temp.mkv
if /i "%inputFileExtension%" equ ".m2ts" set extractAudioFunctFileName=%inputFileNameNoExt%.temp.mkv
if /i "%inputFileExtension%" equ ".m2ts" set inputFileNameNoExt=%inputFileNameNoExt%.temp
if /i "%inputFileExtension%" equ ".m2ts" set inputFileExtension=.mkv
if /i "%inputFileExtension%" equ ".m2ts" mkvmerge -o "!mergedFromM2tsFileName!" --no-video "%extractAudioFunctFileName%"
::pause


if /i "%inputFileExtension%" equ ".opus" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".aac" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".mp3" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".ac3" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".flac" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".thd" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".wav" set audioOnlyFile=true

::figure out how many streams the audio has by dumping out the codec_name for each
"%ffprobeexe%" -v error -select_streams a -show_entries stream=codec_name -of default=noprint_wrappers=1 "%extractAudioFunctFileName%">%tempffprobeFile%
if not exist %tempffprobeFile% goto :eof

::count logic shenanigans
for /f %%i in (%tempffprobeFile%) do (echo %%i > audio.!audioStreamCount!.txt
set /a audioStreamCount+=1)
echo total audio streams=%audioStreamCount%
if %audioStreamCount% equ 0 goto :eof

set audioExtension=m4a

::extract out each stream
set currentAudioStreamCount=%audioStreamCount%
set /a currentAudioStreamCount-=1



::extract logic
if /i "%audioOnlyFile%" neq "true" for /L %%i in (0,1,%currentAudioStreamCount%) do (call :fixExtension %%i
if /i "!extractedCodec!" equ "!audioExtension!" "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% "%inputFileNameNoExt%.audio%%i.!audioExtension!"
if /i "!extractedCodec!" neq "!audioExtension!" "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% "%inputFileNameNoExt%.audio%%i.!extractedCodec!.!audioExtension!"
)

if /i "%audioOnlyFile%" equ "true" "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -c:a %codecLibrary% "%inputFileNameNoExt%.!extractedCodec!.%%i.!audioExtension!"
::"%inputFileNameNoExt%.!extractedCodec!.!audioExtension!"

goto :eof

:: Changes extension from m4a to a more appropriate extension if possible
:fixExtension
set inputFileNumber=%1
set inputFile=audio.%inputFileNumber%.txt
set extractedCodec=invalid

for /f "delims== tokens=1,2,3*" %%i in (%inputFile%) do set extractedCodec=%%j
echo extractedCodec for %inputFile%="%extractedCodec%"
::pause
::@echo on
if /i "%extractedCodec:~-1%" equ " " set extractedCodec=%extractedCodec:~,-1%
::if /i "%extractedCodec:~0,1%" equ " " set extractedCodec=%extractedCodec:~0,-1%
echo extractedCodec for %inputFile%="%extractedCodec%"
::@echo off
::pause

set audioExtension=mka

if /i "%extractedCodec%" equ "opus" set audioExtension=opus
if /i "%extractedCodec%" equ "libopus" set audioExtension=opus
if /i "%extractedCodec%" equ "vorbis" set audioExtension=ogg
if /i "%extractedCodec%" equ "libvorbis" set audioExtension=ogg
if /i "%extractedCodec%" equ "aac" set audioExtension=aac
if /i "%extractedCodec%" equ "libfdk_aac" set audioExtension=aac
if /i "%extractedCodec%" equ "mp3" set audioExtension=mp3
if /i "%extractedCodec%" equ "libmp3lame" set audioExtension=mp3
if /i "%extractedCodec%" equ "ac3" set audioExtension=ac3
if /i "%extractedCodec%" equ "thd" set audioExtension=thd
if /i "%extractedCodec%" equ "wav" set audioExtension=wav
if /i "%extractedCodec%" equ "pcm_s16le" set audioExtension=wav
if /i "%extractedCodec%" equ "pcm_bluray" set audioExtension=wav
if /i "%extractedCodec%" equ "pcm_dvd" set audioExtension=wav
if /i "%extractedCodec%" equ "flac" set audioExtension=flac
if /i "%extractedCodec%" equ "libflac" set audioExtension=flac

goto :eof

:: call sanatize variableName "variableContentsWithQuotes "
:sanatize
set %~1=%~2
goto :eof


::cleanup temporary files
:end
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
if exist "%fileSizeFile%" del "%fileSizeFile%"
if /i "%mergedFromM2tsFileName%" neq "invalid" if exist "%mergedFromM2tsFileName%" del "%mergedFromM2tsFileName%"
for /L %%i in (0,1,%currentAudioStreamCount%) do if exist "audio.%%i.txt" del "audio.%%i.txt"

popd
