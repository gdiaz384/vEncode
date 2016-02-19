@echo off
setlocal enabledelayedexpansion

if /i "%~1" equ "" goto usageHelp
if /i "%~1" equ "?" goto usageHelp
if /i "%~1" equ "/?" goto usageHelp
if /i "%~1" equ "*" goto batchvEncode
if not exist "%~1" (echo "%cd%\%~1" does not exist
goto end)

::Summary:
::1) set defaults
::2) get inputs
::3) validate input
::4) encode video (into .mp4 for ffmpeg)
::5) check if audio need encoding
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
set default_quality=other
::480p, 720p, 1080p, other
set default_chroma=444
::420, 422, 444
set useFFmpegFor8BitEncodes=true
::true, false

set encodeAudio=true
::true, false
set default_audioCodec=opus
::opus, vorbis, aac, mp3, ac3, copy
set audioBitrate=192
::128,192,224,320

set preferredContainer=mkv
::mkv, mp4

if /i "%processor_Architecture%" equ "x86" set architecture=x86
if /i "%processor_Architecture%" equ "amd64" set architecture=x64
set originalDir=%cd%
pushd "%~dp0"
set exePath=%cd%
popd

set ffmpegexe=%exePath%\bin\%architecture%\ffmpeg.exe
set x264prefix=%exePath%\bin\%architecture%\x264
set x265prefix=%exePath%\bin\%architecture%\x265
set mkvMergeExe=%exePath%\bin\%architecture%\mkvmerge.exe


::2) get inputs
set inputVideo_Name=%~n1
set inputVideo_Extension=%~x1

if /i "%~2" equ "" (set codec=%default_codec%) else (set codec=%~2)

if /i "%~3" equ "" (set quality=%default_quality%) else (set quality=%~3)
set resolution=other
if /i "%quality%" equ "4k" (set resolution=3840x2160)
if /i "%quality%" equ "1440p" (set resolution=2560x1440)
if /i "%quality%" equ "1080p" (set resolution=1920x1080)
if /i "%quality%" equ "720p" (set resolution=1280x720)
if /i "%quality%" equ "480p" (set resolution=854x480)

if /i "%~4" equ "" (set crfValue=%default_crfValue%) else (set crfValue=%~4)

if /i "%~5" equ "" (set audioCodec=%default_audioCodec%) else (
set audioCodec=%~5
set encodeAudio=true
)

if /i "%~6" equ "" (set preset=%default_preset%) else (set preset=%~6)

if /i "%~7" equ "" (set bitDepth=%default_bitDepth%) else (set bitDepth=%~7)

if /i "%~8" equ "" (set chroma=%default_chroma%) else (set chroma=%~8)


::echo   vEncode * h265 720p 18 opus veryslow 10 422
::3) validate input
if /i "%codec%" neq "h264" if /i "%codec%" neq "h265" (echo codec "%codec%" unsupported, Supported codecs: h264, h265
echo   Known values: h264, h265
goto usageHelp)

if /i "%resolution%" neq "other" if /i "%resolution%" neq "854x480" if /i "%resolution%" neq "1280x720" if /i "%resolution%" neq "1920x1080" if /i "%resolution%" neq "2560x1440" if /i "%resolution%" neq "3840x2160" (echo resolution "%~4" not supported, defaulting to input video size
echo   Known values: other, 854x480,, 1280x720, 1920x1080, 2560x1440, 3840x2160
set resolution=other
set quality=other)

if /i "%quality%" neq "other" if /i "%quality%" neq "480p" if /i "%quality%" neq "720p" if /i "%quality%" neq "1080p" if /i "%quality%" neq "1440p" if /i "%quality%" neq "4k" (echo  quality unrecognized, using source's resolution instead
echo   Known values: other, 480p, 720p, 1080p, 1440p, 4k
set resolution=other
set quality=other)

if /i %crfValue% lss 0 (echo   crfValue "%crfValue%" not valid, must be greater than or = 0
goto usageHelp)
if /i %crfValue% gtr 51 (echo   crfValue "%crfValue%" not valid, must be less than 52
goto usageHelp)

if /i "%preset%" neq "ultrafast" if /i "%preset%" neq "superfast" if /i "%preset%" neq "veryfast" if /i "%preset%" neq "faster" if /i "%preset%" neq "fast" if /i "%preset%" neq "medium" if /i "%preset%" neq "slow" if /i "%preset%" neq "slower" if /i "%preset%" neq "veryslow" if /i "%preset%" neq "placebo" (echo    preset "%preset%" unsupported
echo    Supported presets: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
goto usageHelp)

if /i "%bitDepth%" neq "8" if /i "%bitDepth%" neq "10" if /i "%bitDepth%" neq "12" (echo   bit depth %bitDepth% not supported
echo   Known values: 8,10,12
goto usageHelp)

if /i "%chroma%" neq "420" if /i "%chroma%" neq "422" if /i "%chroma%" neq "444" (echo   Warning: chroma "%chroma%" unrecognized
echo     Known values: 420, 422, 444
echo     defaulting to %default_chroma%
set chroma=%default_chroma%)


::There are options specified that are not really compatible together such as:
::12-bit h264
::12-bit h265 with yuv444p

::opus/vorbis audio are incompatible with mp4 container, default to mkv instead
if /i "%audioCodec%" equ "opus" set preferredContainer=mkv
if /i "%audioCodec%" equ "vorbis" set preferredContainer=mkv
::could also use ffprobe to discover the audio format to see if it's compatible with mp4
::instead of blindly assuming it is not compatible
if /i "%audioCodec%" equ "copy" set preferredContainer=mkv

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
if /i "%encodeAudio%" neq "true" (set codecLibrary=copy
set audioExtension=mkv)


::vEncode myfile.mp4 {h264/h265} {crf} {preset} {8/10/12} {resolution} {chroma}
::4) encode to %temp%
::if 8 bit, use ffmpeg + settings
::if 10-12 bit, make sure the correct bit depth x254/x265 file is present, then use ffmpeg to dump the y4m file
::encode it
::encode/copy the audio
::then use mkvmerge to merge the new video, the audio, and the old contents

::mkdir "%tempdir%"
if /i "%useFFmpegFor8BitEncodes%" equ "true" if /i "%bitDepth%" equ "8" goto ffmpeg
goto videoPipe

:ffmpeg
set inputname=%inputVideo_Name%%inputVideo_Extension%
set outputname_noext=%inputVideo_Name%.%codec%
if /i "%resolution%" neq "other" set outputname_noext=%outputname_noext%.%quality%
::set outputname_noext=%outputname_noext%.mp4

if exist "%outputname_noext%.mp4" del "%outputname_noext%.mp4%"

if /i "%codec%" equ "h265" goto ffmpegH265
if /i "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -preset %preset% -crf %crfValue% -an -sn -vf yadif,fps=24000/1001 "%outputname_noext%.mp4"
if /i "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -preset %preset% -crf %crfValue% -an -sn -vf yadif,fps=24000/1001,scale=%resolution% "%outputname_noext%.mp4"
goto postFFmpegEncode

:ffmpegH265
if /i "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -c:v libx265 -preset %preset% -x265-params crf=%crfValue% -an -vf yadif,fps=24000/1001 "%outputname_noext%.mp4"
if /i "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%" -pix_fmt yuv%chroma%p -c:v libx265 -preset %preset% -x265-params crf=%crfValue% -an -vf yadif,fps=24000/1001,scale=%resolution% "%outputname_noext%.mp4"

:postFFmpegEncode

::encode audio, will dump the first audio stream (encoded/copied as specified) to "%inputname%.%audioExtension%"
call :encodeAudioFunct "%inputname%"

::merge audio and video into one file
::do not use ffmpeg for the initial muxing, it doesn't handle raw aac files well, instead mux again later to mp4 if requested
"%mkvMergeExe%" -o "%outputname_noext%.mkv" --no-audio --no-buttons --no-attachments "%outputname_noext%.mp4" --no-video --no-buttons --no-attachments "%inputname%.%audioExtension%" --no-video --no-audio "%inputname%"
if exist "%outputname_noext%.mp4" del "%outputname_noext%.mp4"

::if preferred container is mp4, then use ffmpeg to copy the video stream and the audio streams
if /i "%preferredContainer%" equ "mp4" ffmpeg -i "%outputname_noext%.mkv" -c:v copy -c:a copy "%outputname_noext%.mp4"

::cleanup
if exist "%inputname%.%audioExtension%" del "%inputname%.%audioExtension%"
if /i "%preferredContainer%" equ "mp4" if exist "%outputname_noext%.mkv" del "%outputname_noext%.mkv"

goto end


:videoPipe
set inputname=%inputVideo_Name%%inputVideo_Extension%
set outputname_noext=%inputVideo_Name%.%codec%
if /i "%resolution%" neq "other" set outputname_noext=%outputname_noext%.%quality%

if /i "%codec%" equ "h264" set encodeExe=%x264prefix%-%bitDepth%.exe
if /i "%codec%" equ "h265" set encodeExe=%x265prefix%-%bitDepth%.exe

if not exist "%encodeExe%" (echo.
echo   unable to find "%encodeExe%"
echo   please verify this file exists to encode at %bitDepth%-bit depth
goto end)

if exist "%outputname_noext%.y4m" del "%outputname_noext%.y4m"
if exist "%outputname_noext%.%codec%" del "%outputname_noext%.%codec%"

::old way, dump *.y4m stream to feed it to ffmpeg later
::if /i "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf yadif,fps=24000/1001 "%outputname_noext%.y4m"
::if /i "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf yadif,fps=24000/1001,scale=%resolution% "%outputname_noext%.y4m"

::x264.exe and x265.exe use different syntaxes
if /i "%codec%" equ "h265" goto videoPipeH265
::old way, feed *.y4m stream to ffmpeg
::x264 chroma needs to be specified with --output-csp i422
::"%encodeExe%" --crf %crfValue% --output-csp i%chroma% --preset %preset% --output "%outputname_noext%.%codec%" "%outputname_noext%.y4m"

if /i "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf yadif,fps=24000/1001 -f yuv4mpegpipe - | "%encodeExe%" - --demuxer y4m --output-csp i%chroma% --crf %crfValue% --preset %preset% --output "%outputname_noext%.%codec%"
if /i "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf yadif,fps=24000/1001,scale=%resolution% -f yuv4mpegpipe - | "%encodeExe%" - --demuxer y4m --output-csp i%chroma% --crf %crfValue% --preset %preset% --output "%outputname_noext%.%codec%"

goto afterVideoPipeH265
:videoPipeH265
::old way, feed *.y4m stream to ffmpeg
::x265 will honor the input chroma automatically (but mess with some quality values if yuv444p chrome is specified)
::"%encodeExe%" --input "%outputname_noext%.y4m" --crf %crfValue% --preset %preset% --output "%outputname_noext%.%codec%"

if /i "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf yadif,fps=24000/1001 -f yuv4mpegpipe - | "%encodeExe%" --input - --y4m --crf %crfValue% --preset %preset% --output "%outputname_noext%.%codec%"
if /i "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt yuv%chroma%p -vf yadif,fps=24000/1001,scale=%resolution% -f yuv4mpegpipe - | "%encodeExe%" --input - --y4m --crf %crfValue% --preset %preset% --output "%outputname_noext%.%codec%"
:afterVideoPipeH265

::encode audio, will dump the first audio stream (encoded/copied as specified) to "%inputname%.%audioExtension%"
if exist "%inputname%.%audioExtension%" del "%inputname%.%audioExtension%"
call :encodeAudioFunct "%inputname%"

::use mkvmerge to copy the video stream and the audio streams, and the source file
::do not use ffmpeg for the initial muxing, it doesn't handle raw h264/h265 file streams well, instead mux again later to mp4 if requested
if exist "%outputname_noext%.mkv" del "%outputname_noext%.mkv"
"%mkvMergeExe%" -o "%outputname_noext%.mkv" --no-audio --no-buttons --no-attachments "%outputname_noext%.%codec%" --no-video --no-buttons --no-attachments "%inputname%.%audioExtension%" --no-video --no-audio "%inputname%"

::if preferred container is mp4, then use ffmpeg to copy the video stream and the audio streams
if /i "%preferredContainer%" equ "mp4" if exist "%outputname_noext%.mp4" del "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" ffmpeg -i "%outputname_noext%.mkv" -c:v copy -c:a copy "%outputname_noext%.mp4"


::cleanup
if exist "%outputname_noext%.y4m" del "%outputname_noext%.y4m"
if exist "%outputname_noext%.%codec%" del "%outputname_noext%.%codec%"
if exist "%inputname%.%audioExtension%" del "%inputname%.%audioExtension%"
if /i "%preferredContainer%" equ "mp4" if exist "%outputname_noext%.mkv" del "%outputname_noext%.mkv"

goto end


:batchvEncode
set tempfile=temp.txt
if exist "%tempfile%" del "%tempfile%"
if exist "temp.cmd" del "temp.cmd"

dir /b *.mkv >> %tempfile% 2>nul
dir /b *.mp4 >> %tempfile% 2>nul
dir /b *.mpg >> %tempfile% 2>nul
dir /b *.avi >> %tempfile% 2>nul
dir /b *.wmv >> %tempfile% 2>nul
dir /b *.flv >> %tempfile% 2>nul
dir /b *.webm >> %tempfile% 2>nul
dir /b *.h264 >> %tempfile% 2>nul
dir /b *.h265 >> %tempfile% 2>nul
dir /b *.avc >> %tempfile% 2>nul

for /f "delims=*" %%i in (%tempfile%) do echo call vencode "%%i" %2 %3 %4 %5 %6 %7 %8 >> temp.cmd

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


:usageHelp
echo   "vEncode" encodes an existing file into h264/h265 formats
echo   Dependencies: ffmpeg.exe, mkvmerge.exe
echo   For 10Bit Support: x264-10.exe, x265-10.exe
echo   For 12Bit Support: x264-12.exe, x265-12.exe
echo   Syntax:
echo   vEncode myfile.mp4 {h264/h265} {res} {crf} {acodec} {preset} {btdph} {chroma}
echo   order is impt, {} is optional, Double quotes "" means "use the default value"
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
echo   vEncode file.mkv h265 "" "" opus "" "" 420
echo.
echo   Suggested values and (defaults):
echo   Codec: h264, h265, (h265)
echo   Resolution: 480p, 720p, 1080p, 1440p, 4k (n/a)
echo   CRF values: usually 16-28, (18)
echo   AudioCodecs: copy, opus, vorbis, aac, mp3, ac3 (opus)
echo   Presets: ultrafast,fast,medium,slow,veryslow,placebo, (veryslow)
echo   Bit depth: 8, 10 or 12, (10)
echo   YUV Pixel Format: 420, 422, 444, (444)
echo   Note: Enter "" for a value to use the default value.
echo.
echo   To encode all video files in a directory:
echo   vEncode * h265 "" 17 copy veryslow 12 420
echo   vEncode * h265 720p 17 opus veryslow 10 444
:end
::if exist "%tempdir%" rmdir /s /q "%tempdir%"
endlocal
