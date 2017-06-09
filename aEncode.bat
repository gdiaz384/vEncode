@echo off
setlocal enabledelayedexpansion

::1) set defaults
set default_audioCodec=aac
::opus, vorbis, aac, mp3, ac3, wav, flac

set default_audioBitrate=224
::96, 128, 160, 192, 224, 320

set default_volumeLevel=1.0
::0.5, 0.6, 0.8, 1, 1.2, 1.4, 1.5, 1.6, 1.8, 2, 2.2, 2.5, 3.0, 3.5, 4

set maxNumberOfAudioTracks=all
::1,2,3,4,all

::If set to extract, then audio will be extracted from a/v files and encoded.
::If not set to extract, then, for a/v files, a new mkv file will be created with the encoded audio merged back with the untouched video stream.
set default_extractOrMerge=extract
::This has no effect unless extractAudioFromVideo is true.
set cleanupAudioTracks=true


if /i "%~1" equ "?" goto usageHelp
if /i "%~1" equ "/?" goto usageHelp
if /i "%~1" equ "" goto usageHelp

if not exist "%~1" (echo  "%cd%\%~1" does not exist
goto end)


::1) set defaults
::2) read input 
::3) validate input
::4) switch to batch mode if appropriate
::5) extract out audio from file -non batch mode
::6) find all files in the current directory -batch
::7) for each one extract out the audio in the specified format -batch
::8) use mkvmerge to merge the contents of the original but with no audio

if /i "%processor_Architecture%" equ "x86" set architecture=x86
if /i "%processor_Architecture%" equ "amd64" set architecture=x64
set originalDir=%cd%
pushd "%~dp0"
set exePath=%cd%
popd

set ffmpegexe=%exePath%\bin\%architecture%\ffmpeg.exe
set ffprobeexe=%exePath%\bin\%architecture%\ffprobe.exe
set mkvMergeExe=%exePath%\bin\%architecture%\mkvmerge.exe

set tempfile=temp.txt
if exist "%tempfile%" del "%tempfile%"
set tempffprobeFile=tempaudio.txt
if exist "%tempffprobeFile%" del "%tempffprobeFile%"


::2) read input 
set inputFile=%~1

if /i "%~2" equ "" (set audioCodec=%default_audioCodec%) else (set audioCodec=%~2)

if /i "%~3" equ "" (set audioBitrate=%default_audioBitrate%) else (set audioBitrate=%~3)

if /i "%~4" equ "" (set extractOrMerge=%default_extractOrMerge%) else (set extractOrMerge=%~4)

if /i "%~5" equ "" (set volumeLevel=%default_volumeLevel%) else (set volumeLevel=%~5)

if /i "%audioCodec%" neq "opus" if /i "%audioCodec%" neq "libopus" if /i "%audioCodec%" neq "vorbis" if /i "%audioCodec%" neq "libvorbis" if /i "%audioCodec%" neq "aac" if /i "%audioCodec%" neq "libfdk_aac" if /i "%audioCodec%" neq "mp3" if /i "%audioCodec%" neq "libmp3lame" if /i "%audioCodec%" neq "ac3" if /i "%audioCodec%" neq "wav"  if /i "%audioCodec%" neq "pcm_s16le" if /i "%audioCodec%" neq "flac" (echo   unsupported codec: "%audioCodec%" Using "%default_audioCodec%" instead.
set audioCodec=%default_audioCodec%)

::3) validate input
set batchmode=false
if /i "%inputFile%" equ "*" set batchmode=true

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
if /i "%audioCodec%" equ "wav" (set codecLibrary=pcm_s16le
set audioExtension=wav)
if /i "%audioCodec%" equ "pcm_s16le" (set codecLibrary=pcm_s16le
set audioExtension=wav)
if /i "%audioCodec%" equ "flac" (set codecLibrary=flac
set audioExtension=flac)

if /i "%audioBitrate:~-1%" equ "k" set audioBitrate=%audioBitrate:~,-1%

if %audioBitrate% leq 55 (echo   unrecognized bitrate "%audioBitrate%"
echo   Value must be greater than 55 and less than 1536
goto end)
if %audioBitrate% gtr 1536 (echo   unrecognized bitrate "%audioBitrate%"
echo   Value must be greater than 55 and less than 1536.
goto end)

if /i "%extractOrMerge%" equ "extract" (set extractAudioFromVideo=true) else (set extractAudioFromVideo=false)
echo   Current mode of operation is "%extractOrMerge%" mode.

if /i "%volumeLevel%" neq "0.5" if /i "%volumeLevel%" neq "0.6" if /i "%volumeLevel%" neq "0.8" if /i "%volumeLevel%" neq "1" if /i "%volumeLevel%" neq "1.0" if /i "%volumeLevel%" neq "1.2" if /i "%volumeLevel%" neq "1.4" if /i "%volumeLevel%" neq "1.5" if /i "%volumeLevel%" neq "1.6" if /i "%volumeLevel%" neq "1.8" if /i "%volumeLevel%" neq "2" if /i "%volumeLevel%" neq "2.0" if /i "%volumeLevel%" neq "2.2" if /i "%volumeLevel%" neq "2.5" if /i "%volumeLevel%" neq "3" if /i "%volumeLevel%" neq "3.0" if /i "%volumeLevel%" neq "3.5" if /i "%volumeLevel%" neq "4" if /i "%volumeLevel%" neq "4.0" (echo.
echo   volumeLevel unrecognized "%volumeLevel%"   
echo   known values: 0.5, 0.6, 0.8, 1.0, 1.2, 1.4, 1.5, 1.6, 1.8, 2.0, 2.2, 2.5, 3.0, 3.5, 4.0
goto end)
::set volumeLevel=%default_volumeLevel%)

set volumeFilterDisabled=false
if /i "%volumeLevel%" equ "1.0" set volumeFilterDisabled=true
if /i "%volumeLevel%" equ "1" set volumeFilterDisabled=true

::4) switch to batch mode if appropriate
if /i "%batchmode%" equ "true" goto directoryMode


::5) extract out audio from file -non batch mode
call :extractAudio "%inputFile%"
call :mergeVideo "%inputFile%"

goto end


::6) find all files in the current directory -batch
:directoryMode
dir /b *.mkv >> %tempfile% 2>nul
dir /b *.mp4 >> %tempfile% 2>nul
dir /b *.wmv >> %tempfile% 2>nul
dir /b *.mpg >> %tempfile% 2>nul
dir /b *.webm >> %tempfile% 2>nul
dir /b *.flv >> %tempfile% 2>nul
dir /b *.avi >> %tempfile% 2>nul
dir /b *.ogg >> %tempfile% 2>nul
dir /b *.asf >> %tempfile% 2>nul
dir /b *.3gp >> %tempfile% 2>nul

dir /b *.m4a >> %tempfile% 2>nul
dir /b *.ac3 >> %tempfile% 2>nul
dir /b *.mp3 >> %tempfile% 2>nul
dir /b *.aac >> %tempfile% 2>nul
dir /b *.opus >> %tempfile% 2>nul
dir /b *.flac >> %tempfile% 2>nul
dir /b *.wav >> %tempfile% 2>nul

set fileCount=1
for /f "tokens=*" %%i in (%tempfile%) do (
set file[!fileCount!]=%%i
set /a fileCount+=1
)

set /a fileCount-=1
echo   filecount=%fileCount%


::7) for each one extract out the audio in the specified format -batch
for /L %%i in (1,1,%fileCount%) do (
echo  !file[%%i]!
call :extractAudio "!file[%%i]!"
call :mergeVideo "!file[%%i]!"
)
::if %%i geq 2 goto end

goto end


::start functions
::extractAudio expects a file name as input
:extractAudio
if /i "%~1" equ "" (echo error 
goto :eof)
set audioOnlyFile=false
set extractAudioFunctFileName=%~nx1
set inputFileNameNoExt=%~n1
set inputFileExtension=%~x1
set audioStreamCount=0

if /i "%inputFileExtension%" equ ".opus" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".aac" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".mp3" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".ac3" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".flac" set audioOnlyFile=true
if /i "%inputFileExtension%" equ ".wav" set audioOnlyFile=true

::figure out how many streams the audio has by dumping out the codec_name for each
"%ffprobeexe%" -v error -select_streams a -show_entries stream=codec_name -of default=noprint_wrappers=1 "%extractAudioFunctFileName%">%tempffprobeFile%
if not exist %tempffprobeFile% goto :eof

for /f %%i in (%tempffprobeFile%) do set /a audioStreamCount+=1
echo total audio streams=%audioStreamCount%
if %audioStreamCount% equ 0 goto :eof

::extract out each stream
set currentAudioStreamCount=%audioStreamCount%
set /a currentAudioStreamCount-=1
if /i "%volumeFilterDisabled%" equ "true" if /i "%audioOnlyFile%" neq "true" for /L %%i in (0,1,%currentAudioStreamCount%) do "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2 -af "volume=%volumeLevel%" "%extractAudioFunctFileName%.audio%%i.%audioExtension%"
if /i "%volumeFilterDisabled%" equ "true" if /i "%audioOnlyFile%" equ "true" "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2  "%inputFileNameNoExt%.%audioExtension%"
if /i "%volumeFilterDisabled%" neq "true" if /i "%audioOnlyFile%" neq "true" for /L %%i in (0,1,%currentAudioStreamCount%) do "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2 -af "volume=%volumeLevel%" "%extractAudioFunctFileName%.audio%%i.%audioExtension%"
if /i "%volumeFilterDisabled%" neq "true" if /i "%audioOnlyFile%" equ "true" "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2 -af "volume=%volumeLevel%" "%inputFileNameNoExt%.%audioExtension%"

goto :eof


::8) use mkvmerge to merge the contents of the original but with no audio
::mergeVideo depends upon :extractAudio
:mergeVideo
if /i "%extractAudioFromVideo%" equ "true" goto :eof
if /i "%audioOnlyFile%" equ "true" goto :eof
if %audioStreamCount% equ 0 goto :eof

if %audioStreamCount% equ 1 "%mkvMergeExe%" -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" --no-video --no-audio "%~1"
if %audioStreamCount% equ 2 "%mkvMergeExe%" -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" "%~1.audio1.%audioExtension%" --no-video --no-audio "%~1"
if %audioStreamCount% equ 3 "%mkvMergeExe%" -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" "%~1.audio1.%audioExtension%" "%~1.audio2.%audioExtension%" --no-video --no-audio "%~1"
if %audioStreamCount% geq 4 "%mkvMergeExe%" -o "%~1.%codecLibrary%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%~1.audio0.%audioExtension%" "%~1.audio1.%audioExtension%" "%~1.audio2.%audioExtension%" "%~1.audio3.%audioExtension%" --no-video --no-audio "%~1"

if /i "%cleanupAudioTracks%" neq "true" goto :eof

for /L %%i in (0,1,%currentAudioStreamCount%) do (del "%~1.audio%%i.%audioExtension%")
goto :eof


:usageHelp
echo.
echo   "aEncode" encodes audio with different codecs using ffmpeg.
echo   For files with both video/audio, the output will be in Matroska containers.
echo.
echo   Dependencies: ffmpeg.exe, ffprobe.exe, mkvmerge.exe
echo   Syntax:
echo   aEncode myfile.mp4 {audioCodec} {audioBitrate} {extract^|merge} {volumeLevel}
echo   Examples:
echo   aEncode myfile.mp4
echo   aEncode myfile.mp4 opus
echo   aEncode myfile.mp4 mp3 192 extract
echo   aEncode myfile.mp4 aac 320 extract 1
echo   aEncode myfile.mp4 "" 320 extract 1
echo   aEncode myfile.mp4 opus "" merge 3.5
echo.
echo   Suggested values and (defaults):
echo   Codec: opus, vorbis, aac, mp3, ac3, wav, flac (%default_audioCodec%)
echo   Bitrate: 64, 96, 128, 160, 192, 224, 320, 448, (%default_audioBitrate%)
echo   Extract audio or merge it back with video stream: extract, merge, (extract)
echo   VolumeLevel: 0.5, 0.6, 0.8, 1.0, 1.2, 1.4, 1.5, 1.6, 1.8, 
echo                2.0, 2.2, 2.5, 3.0, 3.5, 4.0, (%default_volumeLevel%)
echo.
echo   To encode all media files in a directory:
echo   aEncode *
echo   aEncode * opus
echo   aEncode * opus 192
echo   aEncode * aac 192 extract
echo   aEncode * "" 224 merge 1
echo   aEncode * vorbis 224 extract 2.0

:end
if exist "%tempfile%" del "%tempfile%"
if exist "%tempffprobeFile%" del "%tempffprobeFile%"

endlocal
