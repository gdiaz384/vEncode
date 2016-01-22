@echo off
setlocal enabledelayedexpansion

if /i "%~1" equ "?" goto usageHelp
if /i "%~1" equ "/?" goto usageHelp

set default_audioCodec=opus
::opus, vorbis, aac, mp3, ac3

set default_audioBitrate=192
::128, 160, 192, 224, 320

set maxNumberOfAudioTracks=all
::1,2,3,all

set cleanupAudioTracks=true

::1) read input and validate
::maybe a UI: "would you like to 1) encode everything as default codec, 2) change codec, 3) exit"
::2) find all video files in the current directory
::3) for each one extract out the audio in the specified format
::4) use mkvmerge to merge the contents of the original but with no video
::todo, figure out how to work with (convert and remerge) files that have multiple audio tracks


::1) read input and validate
if /i "%~1" neq "" (set audioCodec=%~1) else (set audioCodec=%default_audioCodec%)

if /i "%~2" neq "" (set audioBitrate=%~2) else (set audioBitrate=%default_audioBitrate%)

if /i "%audioCodec%" neq "opus" if /i "%audioCodec%" neq "libopus" if /i "%audioCodec%" neq "vorbis" if /i "%audioCodec%" neq "libvorbis" if /i "%audioCodec%" neq "aac" if /i "%audioCodec%" neq "libfdk_aac" if /i "%audioCodec%" neq "mp3" if /i "%audioCodec%" neq "libmp3lame" if /i "%audioCodec%" neq "ac3" (echo   unsupported codec: "%audioCodec%" Using "%default_audioCodec%" instead.
set audioCodec=%default_audioCodec%)

::validate input
if /i "%audioCodec%" equ "opus" (set codecLibrary=libopus
set audioExtension=opus)
if /i "%audioCodec%" equ "libopus" (set codecLibrary=libopus
set audioExtension=opus)
if /i "%audioCodec%" equ "vorbis" (set codecLibrary=libvorbis
set audioExtension=ogg)
if /i "%audioCodec%" equ "libvorbis" (set codecLibrary=libvorbis
set audioExtension=ogg)
if /i "%audioCodec%" equ "aac" (set codecLibrary=aac
set audioExtension=aac)
if /i "%audioCodec%" equ "libfdk_aac" (set codecLibrary=libfdk_aac
set audioExtension=aac)
if /i "%audioCodec%" equ "mp3" (set codecLibrary=libmp3lame
set audioExtension=mp3)
if /i "%audioCodec%" equ "libmp3lame" (set codecLibrary=libmp3lame
set audioExtension=mp3)
if /i "%audioCodec%" equ "ac3" (set codecLibrary=ac3
set audioExtension=ac3)

if /i "%audioBitrate%" neq "128" if /i "%audioBitrate%" neq "160" if /i "%audioBitrate%" neq "192" if /i "%audioBitrate%" neq "224" if /i "%audioBitrate%" neq "320" (echo unrecognized bitrate "%audioBitrate%" (echo Using default of "%default_audioBitrate%" instead
set audioBitrate=%default_audioBitrate%)

set tempfile=temp.txt
if exist "%tempfile%" del "%tempfile%"
set tempffprobeFile=tempaudio.txt
if exist "%tempffprobeFile%" del "%tempffprobeFile%"

::2) find all video files in the current directory
dir /b *.mkv >> %tempfile% 2>nul
dir /b *.mp4 >> %tempfile% 2>nul
dir /b *.wmv >> %tempfile% 2>nul
dir /b *.webm >> %tempfile% 2>nul
dir /b *.flv >> %tempfile% 2>nul
dir /b *.ogg >> %tempfile% 2>nul

set fileCount=1
for /f "tokens=*" %%i in (%tempfile%) do (
set file[!fileCount!]=%%i
set /a fileCount+=1
)

set /a fileCount-=1
echo   filecount=%fileCount%

for /L %%i in (1,1,%fileCount%) do (
echo  !file[%%i]!
call :extractAudio "!file[%%i]!"
call :mergeVideo "!file[%%i]!"
)
::if %%i geq 2 goto end

goto end

::start functions

::expects a file name as input
:extractAudio
if /i "%~1" equ "" (echo error 
goto :eof)

::figure out how many streams the audio has
ffprobe -v error -select_streams a -show_entries stream=codec_name -of default=noprint_wrappers=1 "%~1" > %tempffprobeFile%

set audioStreamCount=0
if not exist %tempffprobeFile% goto :eof
for /f %%i in (%tempffprobeFile%) do set /a audioStreamCount+=1
echo total audio streams=%audioStreamCount%
if %audioStreamCount% equ 0 goto :eof

::extract out each stream
set currentAudioStreamCount=%audioStreamCount%
set /a currentAudioStreamCount-=1
for /L %%i in (0,1,%currentAudioStreamCount%) do ffmpeg -i "%~1" -map 0:a:%%i -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2 "%~1.audio%%i.%audioExtension%"

goto :eof

:mergeVideo
if %audioStreamCount% equ 0 goto :eof
if %audioStreamCount% equ 1 mkvmerge -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" --no-video --no-audio "%~1"
if %audioStreamCount% equ 2 mkvmerge -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" "%~1.audio1.%audioExtension%" --no-video --no-audio "%~1"
if %audioStreamCount% equ 3 mkvmerge -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" "%~1.audio1.%audioExtension%" "%~1.audio2.%audioExtension%" --no-video --no-audio "%~1"
if %audioStreamCount% geq 4 mkvmerge -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" "%~1.audio1.%audioExtension%" "%~1.audio2.%audioExtension%" "%~1.audio3.%audioExtension%" --no-video --no-audio "%~1"

if /i "%cleanupAudioTracks%" neq "true" goto :eof

for /L %%i in (0,1,%currentAudioStreamCount%) do (del "%~1.audio%%i.%audioExtension%")
goto :eof

:usageHelp
echo.
echo. tracks containing multiple video tracks are not supported
echo.
goto end


:end
if exist "%tempfile%" del "%tempfile%"
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
endlocal
