@echo off
setlocal enabledelayedexpansion

::Summary:
::1) set defaults
::2) get inputs
::3) validate input
::4) encode video (into .mp4 for ffmpeg)
::5) check if audio needs encoding
::6) merge into final container

::1) set defaults
set tempdir=%temp%\temp%random%

set default_codec=h265
::h264, h265
set default_crfValue=17
::h264 16-28
::h265 14-26
set default_preset=veryslow
::ultrafast, veryfast, fast, medium, slow, veryslow, placebo
set default_bitDepth=10
::8, 10, 12
set default_quality=original
::Original resolution: original
::16:9 Resolutions: 480p, 576p, 720p, 1080p, 1440p, 4k
::4:3 Resolutions: 480p_43, 576p_43, 720p_43, 1080p_43, 1440p_43, 4k_43
set default_chroma=444
::420, 422, 444
set default_fps=original
::original, 24000/1001, 25000/1000, 30000/1001, 30000/1000
set useFFmpegFor8BitEncodes=true
::true, false
set cleanupEncodedVideoTrack=true
::true, false

set encodeAudio=true
::true, false
set default_audioCodec=opus
::opus, vorbis, aac, mp3, ac3, copy
set audioBitrate=192
::128,192,224,320
set volumeLevel=1.0
::0.5, 0.8, 1, 1.5, 2, 2.5, 3.0, 3.5, 4
set cleanupAudioTracks=true
::true, false

set preferredContainer=mkv
::mkv, mp4

if /i "%processor_Architecture%" equ "x86" set architecture=x86
if /i "%processor_Architecture%" equ "amd64" set architecture=x64
set originalDir=%cd%
pushd "%~dp0"
set exePath=%cd%
popd

set ffmpegexe=%exePath%\bin\%architecture%\ffmpeg.exe
set ffprobeexe=%exePath%\bin\%architecture%\ffprobe.exe
set x264prefix=%exePath%\bin\%architecture%\x264
set x265prefix=%exePath%\bin\%architecture%\x265
set mkvMergeExe=%exePath%\bin\%architecture%\mkvmerge.exe

set tempfile=temp.txt
if exist "%tempfile%" del "%tempfile%"
set tempffprobeFile=tempaudio.txt
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
set tempFPSFile=tempFPS.txt
if exist "%tempFPSFile%" del "%tempFPSFile%"


::2) get inputs
if /i "%~1" equ "" goto usageHelp
if /i "%~1" equ "?" goto usageHelp
if /i "%~1" equ "/?" goto usageHelp
if /i "%~1" equ "*" goto batchvEncode
if not exist "%~1" (echo "%cd%\%~1" does not exist
goto end)

set inputVideo_Name=%~n1
set inputVideo_Extension=%~x1

if /i "%~2" equ "" (set codec=%default_codec%) else (set codec=%~2)

if /i "%~3" equ "" (set quality=%default_quality%) else (set quality=%~3)
set resolution=original
if /i "%quality%" equ "2160p_43" (set resolution=2880x2160)
if /i "%quality%" equ "2160_43" (set resolution=2880x2160)
if /i "%quality%" equ "2160p" (set resolution=3840x2160)
if /i "%quality%" equ "2160" (set resolution=3840x2160)
if /i "%quality%" equ "4k_43" (set resolution=2880x2160)
if /i "%quality%" equ "4k" (set resolution=3840x2160)
if /i "%quality%" equ "1440p_43" (set resolution=1920x1440)
if /i "%quality%" equ "1440_43" (set resolution=1920x1440)
if /i "%quality%" equ "1440p" (set resolution=2560x1440)
if /i "%quality%" equ "1440" (set resolution=2560x1440)
if /i "%quality%" equ "1080p_43" (set resolution=1440x1080)
if /i "%quality%" equ "1080_43" (set resolution=1440x1080)
if /i "%quality%" equ "1080p" (set resolution=1920x1080)
if /i "%quality%" equ "1080" (set resolution=1920x1080)
if /i "%quality%" equ "720p_43" (set resolution=960x720)
if /i "%quality%" equ "720_43" (set resolution=960x720)
if /i "%quality%" equ "720p" (set resolution=1280x720)
if /i "%quality%" equ "720" (set resolution=1280x720)
if /i "%quality%" equ "576p_43" (set resolution=768x576)
if /i "%quality%" equ "576_43" (set resolution=768x576)
if /i "%quality%" equ "576p" (set resolution=1024x576)
if /i "%quality%" equ "576" (set resolution=1024x576)
if /i "%quality%" equ "480p_43" (set resolution=640x480)
if /i "%quality%" equ "480_43" (set resolution=640x480)
if /i "%quality%" equ "480p" (set resolution=854x480)
if /i "%quality%" equ "480" (set resolution=854x480)

if /i "%~4" equ "" (set crfValue=%default_crfValue%) else (set crfValue=%~4)

if /i "%~5" equ "" (set audioCodec=%default_audioCodec%) else (set audioCodec=%~5)

if /i "%~6" equ "" (set preset=%default_preset%) else (set preset=%~6)

if /i "%~7" equ "" (set bitDepth=%default_bitDepth%) else (set bitDepth=%~7)

if /i "%~8" equ "" (set chroma=%default_chroma%) else (set chroma=%~8)

::change this to change FPS dynamically via ffmpeg
::if /i "%~9" equ "" (set volumeLevel=%default_volumeLevel%) else (set volumeLevel=%~9)
if /i "%~9" equ "" (set fps=%default_fps%) else (set fps=%~9)

::echo   vEncode * h265 720p 18 opus veryslow 10 422
::3) validate input
if /i "%codec%" neq "h264" if /i "%codec%" neq "h265" (echo codec "%codec%" unsupported, Supported codecs: h264, h265
echo   Known values: h264, h265
goto end)

if /i "%resolution%" neq "original" if /i "%resolution%" neq "854x480" if /i "%resolution%" neq "1024x576" if /i "%resolution%" neq "1280x720" if /i "%resolution%" neq "1920x1080" if /i "%resolution%" neq "2560x1440" if /i "%resolution%" neq "3840x2160" if /i "%resolution%" neq "640x480" if /i "%resolution%" neq "768x576" if /i "%resolution%" neq "960x720" if /i "%resolution%" neq "1440x1080" if /i "%resolution%" neq "1920x1440" if /i "%resolution%" neq "2880x2160" (echo resolution "%~4" not supported, defaulting to input video size
echo   For original resolution: original
echo   Known 16:9 values: 854x480, 1024x576, 1280x720, 1920x1080, 2560x1440, 3840x2160
echo   Known 4:3 values: 640x480, 768x576, 960x720, 1440x1080, 1920x1440, 2880x2160
set resolution=original
set quality=original)

if /i "%quality%" neq "original" if /i "%quality%" neq "480p" if /i "%quality%" neq "480" if /i "%quality%" neq "576p" if /i "%quality%" neq "576" if /i "%quality%" neq "DVD" if /i "%quality%" neq "720p" if /i "%quality%" neq "720" if /i "%quality%" neq "1080p" if /i "%quality%" neq "1080" if /i "%quality%" neq "1440p" if /i "%quality%" neq "1440" if /i "%quality%" neq "4k" if /i "%quality%" neq "2160p" if /i "%quality%" neq "2160" if /i "%quality%" neq "480p_43" if /i "%quality%" neq "480_43" if /i "%quality%" neq "576p_43" if /i "%quality%" neq "576_43" if /i "%quality%" neq "720p_43" if /i "%quality%" neq "720_43" if /i "%quality%" neq "1080p_43" if /i "%quality%" neq "1080_43" if /i "%quality%" neq "1440p_43" if /i "%quality%" neq "1440_43" if /i "%quality%" neq "2160p_43" if /i "%quality%" neq "2160_43" if /i "%quality%" neq "4k_43" (echo  quality unrecognized, using source's resolution instead
echo   For original resolution: original
echo   Known 16:9 values: 480p, 576p, 720p, 1080p, 1440p, 2160p, 4k
echo   Known 4:3 values: 480p_43, 576p_43, 720p_43, 1080p_43, 1440p_43, 2160p_43, 4k_43
set resolution=original
set quality=original)

if /i %crfValue% lss 0 (echo   crfValue "%crfValue%" not valid, must be greater than or = 0
goto end)
if /i %crfValue% gtr 51 (echo   crfValue "%crfValue%" not valid, must be less than 52
goto end)

if /i "%preset%" neq "ultrafast" if /i "%preset%" neq "superfast" if /i "%preset%" neq "veryfast" if /i "%preset%" neq "faster" if /i "%preset%" neq "fast" if /i "%preset%" neq "medium" if /i "%preset%" neq "slow" if /i "%preset%" neq "slower" if /i "%preset%" neq "veryslow" if /i "%preset%" neq "placebo" (echo    preset "%preset%" unsupported
echo    Supported presets: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
goto end)

if /i "%bitDepth%" neq "8" if /i "%bitDepth%" neq "10" if /i "%bitDepth%" neq "12" (echo   bit depth %bitDepth% not supported
echo   Known values: 8,10,12
goto end)

if /i "%chroma%" neq "420" if /i "%chroma%" neq "422" if /i "%chroma%" neq "444" (echo   Warning: yuv chroma "%chroma%" unrecognized
echo     Known values: 420, 422, 444
echo     defaulting to %default_chroma%
set chroma=%default_chroma%)

if /i "%volumeLevel%" neq "0.5" if /i "%volumeLevel%" neq "0.8" if /i "%volumeLevel%" neq "1" if /i "%volumeLevel%" neq "1.0" if /i "%volumeLevel%" neq "1.5" if /i "%volumeLevel%" neq "2" if /i "%volumeLevel%" neq "2.0" if /i "%volumeLevel%" neq "2.5" if /i "%volumeLevel%" neq "3" if /i "%volumeLevel%" neq "3.5" if /i "%volumeLevel%" neq "4" if /i "%volumeLevel%" neq "4.0" (echo.
echo   volumeLevel unrecognized "%volumeLevel%"   
echo   known values: 0.5, 0.8, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0
goto end)

::check fps count
if /i "%fps%" equ "original" call :updateFPS "%inputVideo_Name%%inputVideo_Extension%"
if /i "%fps%" equ "invalid" (echo.
echo  Frames Per Second -FPS- check of "%inputVideo_Name%%inputVideo_Extension%" failed
echo  Please make sure it is a valid video file and try again.
goto end)


::There are options specified that are not really compatible together such as:
::12-bit h264
::12-bit h265 with yuv444p

::x265's ultrafast preset, when used with yuv422p/yuv444p, is buggy as of v1.9. It crops the video stream sometimes.
if /i "%chroma%" neq "420" if /i "%preset%" equ "ultrafast" set preset=veryfast
::Note: yuv444p video still sometimes gets cropped regardless of preset at certain resolutions (esp 480p) but is less noticable.
::Instead of relying on the metainfo, be sure to play the stream back to check for this yuv422p/yuv444p bug in x265 encodes.

::mpg/wmv/asf/avc are not mkvmerge safe so can't use them to import metadata
set mkvMergeSafe=false
if /i "%inputVideo_Extension%" equ ".mkv" set mkvMergeSafe=true
if /i "%inputVideo_Extension%" equ ".mp4" set mkvMergeSafe=true
if /i "%inputVideo_Extension%" equ ".ogg" set mkvMergeSafe=true
if /i "%inputVideo_Extension%" equ ".avi" set mkvMergeSafe=true
if /i "%inputVideo_Extension%" equ ".webm" set mkvMergeSafe=true
if /i "%inputVideo_Extension%" equ ".flv" set mkvMergeSafe=true

::mp4 containers do not support opus/vorbis audio, use mkv instead
if /i "%audioCodec%" equ "opus" (set preferredContainer=mkv
set mp4safe=false)
if /i "%audioCodec%" equ "vorbis" (set preferredContainer=mkv
set mp4safe=false)

::use ffprobe to discover the number of audio tracks and to see if it's compatible with mp4
set mp4safe=true
call :checkAudioCountAndMP4Safe "%inputVideo_Name%%inputVideo_Extension%"
if /i "%mp4safe%" neq "true" set preferredContainer=mkv

if /i "%audioCodec%" equ "opus" (set codecLibrary=libopus
set audioExtension=opus)
if /i "%audioCodec%" equ "vorbis" (set codecLibrary=libvorbis
set audioExtension=ogg)
if /i "%audioCodec%" equ "aac" (set codecLibrary=aac
set audioExtension=aac)
if /i "%audioCodec%" equ "mp3" (set codecLibrary=libmp3lame
set audioExtension=mp3)
if /i "%audioCodec%" equ "ac3" (set codecLibrary=ac3
set audioExtension=ac3)
if /i "%audioCodec%" equ "copy" (set codecLibrary=copy
set audioExtension=mkv)
set encodeAudio=true
if /i "%audioCodec%" equ "none" (set encodeAudio=false)
if /i "%audioCodec%" equ "no" (set encodeAudio=false)
if /i "%audioCodec%" equ "n" (set encodeAudio=false)
if not defined codecLibrary set codecLibrary=libopus
if not defined audioExtension set audioExtension=opus


::vEncode myfile.mp4 {h264/h265} {crf} {preset} {8/10/12} {resolution} {chroma}
::4) encode video (into .mp4 for ffmpeg)
::if 8 bit, use ffmpeg + settings
::if 10-12 bit, make sure the correct bit depth x254/x265 file is present, 
::then use ffmpeg to stream the y4m file to x264/x265
::encode it
::encode/copy the audio
::then use mkvmerge to merge the new video, the audio, and (if mkvmerge safe) the old contents

::prepareForBranch
set inputname=%inputVideo_Name%%inputVideo_Extension%
set outputname_noext=%inputVideo_Name%.%codec%
if /i "%resolution%" neq "original" set outputname_noext=%outputname_noext%.%quality%

::branch
if /i "%useFFmpegFor8BitEncodes%" equ "true" if /i "%bitDepth%" equ "8" goto ffmpeg
goto videoPipe

:ffmpeg
set videoOnlyOutputName=%outputname_noext%.mp4
if exist "%videoOnlyOutputName%" del "%videoOnlyOutputName%"

if /i "%codec%" equ "h265" goto ffmpegH265
if /i "%quality%" equ "original" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -preset %preset% -crf %crfValue% -an -sn -vf "fps=%fps%" "%videoOnlyOutputName%"
if /i "%quality%" neq "original" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -preset %preset% -crf %crfValue% -an -sn -vf "fps=%fps%,scale=%resolution%" "%videoOnlyOutputName%"
goto postFFmpegEncode

:ffmpegH265
if /i "%quality%" equ "original" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -c:v libx265 -preset %preset% -x265-params crf=%crfValue% -an -vf fps=%fps% "%videoOnlyOutputName%"
if /i "%quality%" neq "original" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -c:v libx265 -preset %preset% -x265-params crf=%crfValue% -an -vf fps=%fps%,scale=%resolution% "%videoOnlyOutputName%"
:postFFmpegEncode

goto processAudio


:videoPipe
if /i "%codec%" equ "h264" set encodeExe=%x264prefix%-%bitDepth%.exe
if /i "%codec%" equ "h265" set encodeExe=%x265prefix%-%bitDepth%.exe

if not exist "%encodeExe%" (echo.
echo   unable to find "%encodeExe%"
echo   please verify this file exists to encode at %bitDepth%-bit depth
goto end)

set videoOnlyOutputName=%outputname_noext%.%codec%
if exist "%videoOnlyOutputName%" del "%videoOnlyOutputName%"

::x264.exe and x265.exe use different syntaxes
if /i "%codec%" equ "h265" goto videoPipeH265

if /i "%quality%" equ "original" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf "fps=%fps%" -f yuv4mpegpipe - | "%encodeExe%" - --demuxer y4m --output-csp i%chroma% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
if /i "%quality%" neq "original" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf "fps=%fps%,scale=%resolution%" -f yuv4mpegpipe - | "%encodeExe%" - --demuxer y4m --output-csp i%chroma% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"

goto afterVideoPipeH265
:videoPipeH265

if /i "%quality%" equ "original" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf "fps=%fps%" -f yuv4mpegpipe - | "%encodeExe%" --input - --y4m --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
if /i "%quality%" neq "original" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf "fps=%fps%,scale=%resolution%" -f yuv4mpegpipe - | "%encodeExe%" --input - --y4m --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
:afterVideoPipeH265


:processAudio
::extractAudio will dump the audio streams (encoded/copied as specified) to "%inputname%.audio%%i.%audioExtension%" where %i is 0 to %audioStreamCount%-1
if /i "%encodeAudio%" equ "true" call :extractAudio "%inputname%"


::merge audio and video into one file
call :mergeStreams "%videoOnlyOutputName%"
if /i "%cleanupEncodedVideoTrack%" equ "true" if exist "%videoOnlyOutputName%" del "%videoOnlyOutputName%"

::if preferred container is mp4, then use ffmpeg to copy the video stream and 1 audio stream
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if exist "%outputname_noext%.mp4" del "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 0 ffmpeg -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 1 ffmpeg -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 2 ffmpeg -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 -map 0:a:1 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 3 ffmpeg -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 -map 0:a:1 -map 0:a:2 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 4 ffmpeg -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 -map 0:a:1 -map 0:a:2 -map 0:a:3 "%outputname_noext%.mp4"

::cleanup
if /i "%cleanupAudioTracks%" equ "true" if /i "%encodeAudio%" equ "true" for /L %%i in (0,1,%currentAudioStreamCount%) do (del "%inputname%.audio%%i.%audioExtension%")
if /i "%cleanupEncodedVideoTrack%" equ "true" if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if exist "%outputname_noext%.mp4" if exist "%outputname_noext%.mkv" del "%outputname_noext%.mkv"



goto end

::startFunctions::
:batchvEncode
set tempfile=temp.txt
if exist "%tempfile%" del "%tempfile%"
if exist "temp.cmd" del "temp.cmd"

dir /b *.mkv >> %tempfile% 2>nul
dir /b *.mp4 >> %tempfile% 2>nul
dir /b *.m4v >> %tempfile% 2>nul
dir /b *.ogg >> %tempfile% 2>nul
dir /b *.ogv >> %tempfile% 2>nul
dir /b *.webm >> %tempfile% 2>nul
dir /b *.flv >> %tempfile% 2>nul
dir /b *.avi >> %tempfile% 2>nul
dir /b *.wmv >> %tempfile% 2>nul
dir /b *.mpg >> %tempfile% 2>nul
dir /b *.asf >> %tempfile% 2>nul
dir /b *.3gp >> %tempfile% 2>nul
dir /b *.h264 >> %tempfile% 2>nul
dir /b *.h265 >> %tempfile% 2>nul
dir /b *.avs >> %tempfile% 2>nul
dir /b *.y4m >> %tempfile% 2>nul

for /f "delims=*" %%i in (%tempfile%) do echo call vencode "%%i" %2 %3 %4 %5 %6 %7 %8 %9>>temp.cmd

if exist "%tempfile%" del "%tempfile%"
type temp.cmd
call temp.cmd
type temp.cmd
del temp.cmd

goto end


::takes a filesource %1 as an input
:encodeAudioFunct
set audioInput=%~1
ffmpeg -i "%audioInput%" -vn -sn -c:a %codecLibrary% -b:a %audioBitrate%k "%audioInput%.%audioExtension%"
goto :eof


::Used to update %fps% variable for "ffmpeg -vf fps=%fps%" and takes pprobe compatible video file as input
::Usage: call :updateFPS "%video%"
:updateFPS
if not exist "%~1" (echo "%~1" does not exist
goto :eof)
set fps=invalid

"%ffprobeexe%" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1 "%~1">"%tempFPSFile%"
if not exist "%tempFPSFile%" goto :eof

for /f "delims== tokens=1,2,3,4" %%i in (%tempFPSFile%) do (set fps=%%j)

if not defined fps set fps=invalid
if /i "%fps%" equ "" set fps=invalid
if /i "%fps%" equ " " set fps=invalid

if exist "%tempFPSFile%" del "%tempFPSFile%"
goto :eof


:checkAudioCountAndMP4Safe
if not exist "%~1" (echo "%~1" does not exist
goto :eof)
set audioStreamCount=0

::figure out how many streams the audio has by dumping out the codec_name for each
"%ffprobeexe%" -v error -select_streams a -show_entries stream=codec_name -of default=noprint_wrappers=1 "%~1">"%tempffprobeFile%"
if not exist "%tempffprobeFile%" goto :eof

for /f %%i in (%tempffprobeFile%) do set /a audioStreamCount+=1
echo total audio streams=%audioStreamCount%
if %audioStreamCount% equ 0 (set audioCodec=none
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
goto :eof)

for /f "delims== tokens=1,2,3,4" %%i in (%tempffprobeFile%) do (if /i "%audioCodec%" equ "copy" if /i "%%j" equ "pcm_f32le" set mp4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "opus" set mp4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "vorbis" set mp4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "flac" set mp4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wma" set mp4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wma2" set mp4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wmav" set mp4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wmav2" set mp4safe=false)
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
goto :eof


:extractAudio
if /i "%~1" equ "" (echo error 
goto :eof)
set extractAudioFunctFileName=%~nx1

if %audioStreamCount% equ 0 goto :eof

::extract out each stream
set currentAudioStreamCount=%audioStreamCount%
set /a currentAudioStreamCount-=1
for /L %%i in (0,1,%currentAudioStreamCount%) do (if exist "%extractAudioFunctFileName%.audio%%i.%audioExtension%" del "%extractAudioFunctFileName%.audio%%i.%audioExtension%")

if /i "%audioCodec%" equ "copy" for /L %%i in (0,1,%currentAudioStreamCount%) do "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% "%extractAudioFunctFileName%.audio%%i.%audioExtension%"
if /i "%audioCodec%" neq "copy" for /L %%i in (0,1,%currentAudioStreamCount%) do "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2 -af "volume=%volumeLevel%" "%extractAudioFunctFileName%.audio%%i.%audioExtension%"

goto :eof


::8) use mkvmerge to merge the video and extracted audio tracks
::mergeStreams depends upon :extractAudio and needs to be called as "call :mergeStreams %encodedVideoStream%"
::do not use ffmpeg for the initial muxing, it doesn't handle raw aac files well, instead mux again later to mp4 if requested
:mergeStreams
set inputFileNameNoExt=%~n1

if exist "%inputFileNameNoExt%.mkv" del "%inputFileNameNoExt%.mkv"
if /i "%mkvMergeSafe%" equ "true" goto mergeStreamsMKV

if /i "%encodeAudio%" neq "true" goto mergeStreamsNotMergeSafeNoAudio
if %audioStreamCount% equ 0 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1"
if %audioStreamCount% equ 1 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%"
if %audioStreamCount% equ 2 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%" "%inputname%.audio1.%audioExtension%"
if %audioStreamCount% equ 3 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%" "%inputname%.audio1.%audioExtension%" "%inputname%.audio2.%audioExtension%"
if %audioStreamCount% geq 4 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%" "%inputname%.audio1.%audioExtension%" "%inputname%.audio2.%audioExtension%" "%inputname%.audio3.%audioExtension%"
goto :eof

:mergeStreamsNotMergeSafeNoAudio
"%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1"
goto :eof

:mergeStreamsMKV
if /i "%encodeAudio%" neq "true" goto mergeStreamsMergeSafeNoAudio
if %audioStreamCount% equ 0 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" --no-audio --no-video "%inputname%"
if %audioStreamCount% equ 1 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%" --no-video --no-audio "%inputname%"
if %audioStreamCount% equ 2 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%" "%inputname%.audio1.%audioExtension%" --no-video --no-audio "%inputname%"
if %audioStreamCount% equ 3 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%" "%inputname%.audio1.%audioExtension%" "%inputname%.audio2.%audioExtension%" --no-video --no-audio "%inputname%"
if %audioStreamCount% geq 4 "%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" "%inputname%.audio0.%audioExtension%" "%inputname%.audio1.%audioExtension%" "%inputname%.audio2.%audioExtension%" "%inputname%.audio3.%audioExtension%" --no-video --no-audio "%inputname%"
goto :eof

:mergeStreamsMergeSafeNoAudio
"%mkvMergeExe%" -o "%inputFileNameNoExt%.mkv" --no-audio --no-subtitles --no-buttons --no-attachments "%~1" --no-audio --no-video "%inputname%"
goto :eof


:usageHelp
echo.
echo   "vEncode" encodes an existing video file into h264/h265 formats.
echo.
echo   Dependencies: ffmpeg.exe, mkvmerge.exe, ffprobe.exe
echo   For 10Bit Support: x264-10.exe, x265-10.exe
echo   For 12Bit Support: x264-12.exe, x265-12.exe
echo.
echo   Syntax:
echo   vEncode vid.mp4 {codec} {res} {crf} {acodec} {prest} {btdph} {chroma} {fps}
echo   Order is impt, {} is optional, Double quotes "" means "use the default value"
echo   Examples:
echo   vEncode myfile.mkv
echo   vEncode "my file.mkv" h264
echo   vEncode "my file.mkv" h265
echo   vEncode file.mkv h264
echo   vEncode file.mkv "" 720p
echo   vEncode file.mkv "" 720p 20
echo   vEncode file.mkv h264 1080p 20
echo   vEncode file.mkv h265 1080p 20 opus
echo   vEncode file.mkv h264 1080p 20 aac veryslow
echo   vEncode file.mkv h265 480p 20 opus veryslow
echo   vEncode file.mkv h265 "" 18 opus veryslow
echo   vEncode file.mkv h265 720p 18 opus veryslow 10
echo   vEncode file.mkv h264 720p 16 aac veryslow 10 420
echo   vEncode file.mkv h265 720p 18 opus slow 10 444
echo   vEncode file.mkv h264 1080p 16 copy slow 10 420
echo   vEncode file.mkv h265 720p 18 opus slow 10 444
echo   vEncode file.mkv h265 "" "" opus "" "" 420 24000/1001
echo.
echo   Suggested values and (defaults):
echo   Codec: h264, h265, (%default_codec%)
echo   Resolutions (16:9): 480p, 576p, 720p, 1080p, 1440p, 2160p, 4k
echo   (4:3): 480p_43, 576p_43, 720p_43, 1080p_43, 1440p_43, 2160p_43, 4k_43
echo   CRF values: usually 16-28, (%default_crfValue%)
echo   AudioCodecs: copy, none, opus, vorbis, aac, mp3, ac3, (%default_audioCodec%)
echo   Presets: ultrafast,fast,medium,slow,veryslow,placebo, (%default_preset%)
echo   Bit depth: 8, 10 or 12, (%default_bitDepth%)
echo   YUV Pixel Format: 420, 422, 444, (%default_chroma%)
echo   FPS: 24000/1001, 25000/1000, 30000/1001, 30000/1000, (%default_fps%)
echo   Note: Enter "" for a value to use the default value.
echo.
echo   To encode all video files in a directory:
echo   vEncode * h264 "" 16 none veryslow 8 420
echo   vEncode * h265 "" 17 copy "" 12 420
echo   vEncode * h265 720p 17 opus veryslow 10 444 24000/1001   
echo   vEncode *

:end
endlocal
