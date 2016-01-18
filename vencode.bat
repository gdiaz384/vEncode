@echo off
setlocal enabledelayedexpansion

if /i "%~1" equ "" goto usageHelp
if /i "%~1" equ "?" goto usageHelp
if /i "%~1" equ "/?" goto usageHelp
if not exist "%~1" (echo "%cd%\%~1" does not exist
goto end)

::Summary:
::1) set defaults
::2) get inputs
::3) validate input
::4) encode (make sure output is in a container)


::1) set defaults
set tempdir=%temp%\temp%random%
::mkdir "%tempdir%"
set default_codec=h265
set default_crfValue=18
set default_preset=veryslow
set default_bitDepth=10
set default_resolution=none
set default_chroma=yuv422p

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

if /i "%~3" equ "" (set crfValue=%default_crfValue%) else (set crfValue=%~3)

if /i "%~4" equ "" (set preset=%default_preset%) else (set preset=%~4)

if /i "%~5" equ "" (set bitDepth=%default_bitDepth%) else (set bitDepth=%~5)

if /i "%~6" equ "" (set resolution=other
set quality=other)
if /i "%~6" equ "1080p" (set resolution=1920x1080
set quality=1080p)
if /i "%~6" equ "720p" (set resolution=1280x720
set quality=720p)
if /i "%~6" equ "480p" (set resolution=854x480
set quality=480p)

if /i "%~7" equ "" (set chroma=%default_chroma%) else (set chroma=%~7)


::3) validate input
if /i "%codec%" neq "h264" if /i "%codec%" neq "h265" (echo codec "%codec%" unsupported, Supported codecs: h264, h265
goto end)

if /i %crfValue% lss 0 (echo   crfValue "%crfValue%" not valid, must be greater than or = 0
goto end)
if /i %crfValue% gtr 51 (echo   crfValue "%crfValue%" not valid, must be less than 52
goto end)

if /i "%preset%" neq "ultrafast" if /i "%preset%" neq "superfast" if /i "%preset%" neq "veryfast" if /i "%preset%" neq "faster" if /i "%preset%" neq "fast" if /i "%preset%" neq "medium" if /i "%preset%" neq "slow" if /i "%preset%" neq "slower" if /i "%preset%" neq "veryslow" if /i "%preset%" neq "placebo" (echo preset "%preset%" unsupported, Supported presets: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
goto usageHelp)

if /i "%bitDepth%" neq "8" if /i "%bitDepth%" neq "10" if /i "%bitDepth%" neq "12" (echo   bit depth %bitDepth% not supported: 8,10,12 only
goto end)

if /i "%resolution%" neq "other" if /i "%resolution%" neq "1920x1080" if /i "%resolution%" neq "1280x720" if /i "%resolution%" neq "854x480" (echo resolution "%~4" not supported, defaulting to input video size
set resolution=other
set quality=other)

if /i "%quality%" neq "other" if /i "%quality%" neq "480p" if /i "%quality%" neq "720p" if /i "%quality%" neq "1080p" (echo  quality unrecognized, using source's resolution instead
set resolution=other
set quality=other)

if /i "%chroma%" neq "yuv420p" f /i "%chroma%" neq "yuv422p" f /i "%chroma%" neq "yuv444p" (echo   Warning: chroma "%chroma%" unrecognized
echo     Known values: yuv420p, yuv422p, yuv444p)

::There might be options specified that are incompatible together (such as 10/12 bit h264 and non yuv420p chromas)


::vEncode myfile.mp4 {h264/h265} {crf} {preset} {8/10/12} {resolution} {chroma}
::4) encode to %temp%
::if 8 bit, use ffmpeg + settings
::if 10-12 bit, make sure the correct bit depth x254/x265 file is present, then use ffmpeg to dump the y4m file
::encode it, then use mkvmerge to merge the old contents and the new video

if /i "%bitDepth%" equ "8" goto ffmpeg
if /i "%bitDepth%" neq "8" goto videoPipe

:ffmpeg
set inputname=%inputVideo_Name%%inputVideo_Extension%
set outputname_noext=%inputVideo_Name%.%codec%
if /i "%resolution%" neq "other" set outputname_noext=%outputname_noext%.%quality%
::set outputname_noext=%outputname_noext%.mp4

if exist "%outputname_noext%.mp4" del "%outputname_noext%.mp4"
if exist "%outputname_noext%.mkv" del "%outputname_noext%.mkv"

if /i "%codec%" equ "h265" goto ffmpegH265
if "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%" -pix_fmt %chroma% -preset %preset% -crf %crfValue% -c:a aac -strict experimental -b:a 192k "%outputname_noext%.mp4"
if "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%" -pix_fmt %chroma% -preset %preset% -crf %crfValue% -vf scale=%resolution% -c:a aac -strict experimental -b:a 192k "%outputname_noext%.mp4"
goto postFFmpegEncode

:ffmpegH265
if "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%"  -pix_fmt %chroma% -c:v libx265 -preset %preset% -x265-params crf=%crfValue% -c:a aac -strict experimental -b:a 192k "%outputname_noext%.mp4"
if "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%"  -pix_fmt %chroma% -vf scale=%resolution% -c:v libx265 -preset %preset% -x265-params crf=%crfValue% -c:a aac -strict experimental -b:a 192k "%outputname_noext%.mp4"

:postFFmpegEncode
"%mkvMergeExe%" --output %outputname_noext%.mkv "%outputname_noext%.mp4"
::--title "inputVideo_Name"

if exist "%outputname_noext%.mp4" del "%outputname_noext%.mp4"
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
if exist "%outputname_noext%.mkv" del "%outputname_noext%.mkv"

if /i "%quality%" equ "other" "%ffmpegexe%" -i "%inputname%" -an -sn -pix_fmt %chroma% "%outputname_noext%.y4m"
if /i "%quality%" neq "other" "%ffmpegexe%" -i "%inputname%" -an -sn -vf scale=%resolution% -pix_fmt %chroma% "%outputname_noext%.y4m"

::h264 and h265 might use different syntaxes
if /i "%codec%" equ "h265" goto videoPipeH265
"%encodeExe%" --crf %crfValue% --preset %preset% --output "%outputname_noext%.%codec%" "%outputname_noext%.y4m"
goto afterVideoPipeH265
:videoPipeH265
"%encodeExe%" --input "%outputname_noext%.y4m" --crf %crfValue% --preset %preset% --output "%outputname_noext%.%codec%"
:afterVideoPipeH265

"%mkvMergeExe%" --output "%outputname_noext%.mkv" --no-video "%inputname%" "%outputname_noext%.%codec%"
::--title "inputVideo_Name"

if exist "%outputname_noext%.y4m" del "%outputname_noext%.y4m"
if exist "%outputname_noext%.%codec%" del "%outputname_noext%.%codec%"
goto end


::defaults h264, 720p, "slow" quality
:usageHelp
echo   "vEncode" re-encodes an existing file into h264/h265 formats
echo   Dependencies: ffmpeg.exe, mkvmerge.exe
echo   For 10Bit Support: x264-10.exe, x265-10.exe, ~50GB HD space
echo   For 12Bit Support: x264-12.exe, x265-12.exe, ~50GB HD space
echo   Syntax:
echo   vEncode myfile.mp4 {h264/h265} {crf} {preset} {8/10/12} {resolution} {chroma}
echo   Examples:
echo   vEncode myfile.mkv
echo   vEncode "my file.mkv" h264
echo   vEncode "my file.mkv" h265
echo   vEncode file.mkv h264 20
echo   vEncode file.mkv "" 20
echo   vEncode file.mkv "" 20 veryslow
echo   vEncode file.mkv h265 20 slow 8
echo   vEncode file.mkv h265 "" slow 8 720p
echo   vEncode file.mkv h264 "" slow 8 480p yuv420p
echo   vEncode file.mkv h265 20 slow 10 "" yuv422p
echo   vEncode file.mkv h265 18 veryslow 12 1080p yuv444p
echo.
echo   Suggested values and (defaults):
echo   CRF values: usually 16-28, (18)
echo   Presets: ultrafast,fast,medium,slow,veryslow,placebo, (veryslow)
echo   Bit depth: 8, 10 or 12, (10)
echo   Resolution: 480p, 720p, 1080p, (n/a)
echo   PixelFormat: yuv420p, yuv422p, yuv444p, (yuv422p)

:end
if exist "%tempdir%" rmdir /s /q "%tempdir%"
endlocal