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
::4) encode to %temp%
::5) make sure audio is in final container
::6) move from temp to current dir

::1) set defaults
set tempdir=%temp%\temp%random%
mkdir "%tempdir%"
set tempFileName=temp_rawvideo
set default_codec=h264
set default_crfValue=20
set default_preset=slow
set default_bitDepth=8
set default_resolution=none
set default_chroma=yuv420p

if /i "%processor_Architecture%" equ "x86" set architecture=x86
if /i "%processor_Architecture%" equ "amd64" set architecture=x64
set ffmpegexe=bin\%architecture%\ffmpeg.exe
set x264prefix=bin\%architecture%\x265
set x265prefix=bin\%architecture%\x265
set mkmergeExe=bin\%architecture%\mkvmerge.exe

set originalDir=%cd%
pushd "%~dp0"
set exePath=%cd%
popd

::2) get inputs
set inputVideo_Name=%~n1
set inputVideo_Extension=%~x1

if /i "%~2" equ "" (set codec=%default_codec%) else (set codec=%~2)

if /i "%~3" equ "" (set preset=%default_crfValue%) else (set crfValue=%~3)

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

::vEncode myfile.mp4 {h264/h265} {crf} {preset} {8/10/12} {resolution} {chroma}
::3) validate input

if /i "%codec%" neq "h264" if /i "%codec%" neq "h265" (echo codec "%codec%" unsupported, Supported codecs: h264, h265
goto end)

if /i %crfValueset% lss 0 (echo   crfValue "%crfValue%" not valid, must be greater than or = 0
goto end)
if /i %crfValueset% gtr 51 (echo   crfValue "%crfValue%" not valid, must be less than 52
goto end)

if /i "%preset%" neq "ultrafast" if /i "%preset%" neq "superfast" if /i "%preset%" neq "veryfast" if /i "%preset%" neq "faster" if /i "%preset%" neq "fast" if /i "%preset%" neq "medium" if /i "%preset%" neq "slow" if /i "%preset%" neq "slower" if /i "%preset%" neq "veryslow" if /i "%preset%" neq "placebo" (echo preset "%preset%" unsupported, Supported presets: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
goto usageHelp)

if /i "%bitDepth%" neq "8" f /i "%bitDepth%" neq "10" f /i "%bitDepth%" neq "12" (echo   bit depth "%bitDepth%" not supported, 8, 10, 12 only
goto end)

if /i "%quality%" neq "other" if /i "%quality%" neq "480p" if /i "%quality%" neq "720p" if /i "%quality%" neq "1080p" (echo  resolution unrecognized, using source video's resolution instead
set resolution=other
set quality=other)

if /i "%resolution%" neq "other" if /i "%resolution%" neq "1920x1080" if /i "%resolution%" neq "1280x720" if /i "%resolution%" neq "854x480" (echo resolution "%~4" not supported, defaulting to input video size
set resolution=other)

if /i "%chroma%" neq "yuv420p" f /i "%chroma%" neq "yuv422p" f /i "%chroma%" neq "yuv444p" (echo   Warning: chroma "%chroma%" unrecognized
echo     Known values: yuv420p, yuv422p, yuv444p)


if /i "%bitDepth%" equ "8" goto ffmpeg
if /i "%bitDepth%" neq "8" goto videoPipe

::if 8 bit, use ffmpeg + settings
::if 10-12 bit, make sure the correct bit depth x254/x265 file is present, then use ffmpeg to dump the y4m file
::encode it, then use mkvmerge to merge the old contents and the new video

:ffmpeg
if /i "%resolution%" equ "other" set outputname=%inputVideo_Name%.h264.%extension%
if /i "%resolution%" neq "other" set outputname=%inputVideo_Name%.%quality%.h264.%extension%
if exist "%outputname%" del "%outputname%"

if "%resolution%" equ "other" ffmpeg.exe -i "%inputVideo_FullNameAndPath%" -crf %default_crfValue% -preset %preset% -c:a aac -strict experimental -b:a 192k "%outputname%"
if "%resolution%" neq "other" ffmpeg.exe -i "%inputVideo_FullNameAndPath%" -vf scale=%resolution% -crf %default_crfValue% -preset %preset% -c:a aac -strict experimental -b:a 192k "%outputname%"
goto end

:videoPipe
if exist "%tempdir%\%tempfilename%.y4m" del "%tempdir%\%tempfilename%.y4m"
if /i "%resolution%" equ "other" set outputname=%inputVideo_Name%.h265
if /i "%resolution%" neq "other" set outputname=%inputVideo_Name%.%quality%.h265
if exist "%outputname%" del "%outputname%"

if /i "%resolution%" equ "other" ffmpeg -i "%inputVideo_FullNameAndPath%" -an -sn -pix_fmt %default_chroma% "%tempdir%\%tempfilename%.y4m"
if /i "%resolution%" neq "other" ffmpeg -i "%inputVideo_FullNameAndPath%" -an -sn -vf scale=%resolution% -pix_fmt %default_chroma% "%tempdir%\%tempfilename%.y4m"
x265 --input "%tempdir%\%tempfilename%.y4m" --preset %preset% --crf %default_crfValue% --output "%outputname%"

if exist "%tempdir%\%tempfilename%.y4m" del "%tempdir%\%tempfilename%.y4m"
goto end


:functions

goto :eof

::defaults h264, 720p, "slow" quality
:usageHelp
echo   "vEncode" re-encodes an existing file into h264/h265 formats
echo   Dependencies: 
echo   Basic: ffmpeg.exe, mkvmerge.exe
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
echo   vEncode file.mkv h264 "" slow 8 480p yuv420
echo   vEncode file.mkv h265 18 slow 10 1080p yuv444
echo.
echo   Suggested values and (defaults):
echo   CRF values: usually 16-28, (20)
echo   Presets: ultrafast,medium,slow,veryslow,placebo, (slow)
echo   Bit depth: 8, 10 or 12, (8)
echo   Resolution: 480p, 720p, 1080p, (n/a)
echo   PixelFormat: yuv420p, yuv422p, yuv444p, (yuv420p)

:end
if exist "%tempdir%" rmdir /s /q "%tempdir%"
endlocal
