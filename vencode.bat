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
set default_crfValue=18
::h264 0, 14-28
::h265 0, 15-32
set default_preset=veryslow
::ultrafast, veryfast, fast, medium, slow, veryslow, placebo
set default_bitDepth=10
::8, 10, 12
set default_quality=original
::Original resolution: original
::16:9 Resolutions: 480p, 576p, 720p, 1080p, 1440p, 2160p, 4k
::4:3 Resolutions: 480p_43, 576p_43, 720p_43, 1080p_43, 1440p_43, 2160p_43, 4k_43
set default_chroma=original
::original, 420, 422, 444
set default_fps=original
::original, 24000/1001, 25000/1000, 30000/1000, 30000/1001
set default_aqMode=3
::AVC: default,0,1,2,3
::HEVC: default,0,1,2,3,4
set useFFmpegFor8BitEncodes=true
::true, false
set cleanupEncodedVideoTrack=true
::true, false

set encodeAudio=true
::true, false
set default_audioCodec=aac
::opus, vorbis, aac, mp3, ac3, copy, flac, wav
set audioBitrate=224
::96, 128, 192, 224, 256, 320
set volumeLevel=1.0
::0.5, 0.6, 0.8, 1.0, 1.2, 1.4, 1.5, 1.6, 1.8, 2.0, 2.2, 2.5, 3.0, 3.5, 4.0
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

set vspipeexe=vspipe.exe
set ffmpegexe=%exePath%\bin\%architecture%\ffmpeg.exe
set ffprobeexe=%exePath%\bin\%architecture%\ffprobe.exe
set x264prefix=%exePath%\bin\%architecture%\x264
set x265prefix=%exePath%\bin\%architecture%\x265
set mkvMergeExe=%exePath%\bin\%architecture%\mkvmerge.exe

set tempfile=temp.%random%.txt
if exist "%tempfile%" del "%tempfile%"
set tempffprobeFile=tempaudio.%random%.txt
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
set tempFPSFile=tempFPS.%random%.txt
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

set vapourSynthFile=false
if /i "%inputVideo_Extension%" equ ".vpy" (set vapourSynthFile=true)

if /i "%~2" equ "" (set codec=%default_codec%) else (set codec=%~2)

if /i "%~3" equ "" (set quality=%default_quality%) else (set quality=%~3)
set resolution=original
if /i "%quality%" equ "4k_43" (set resolution=2880x2160)
if /i "%quality%" equ "4k" (set resolution=4096x2160)
if /i "%quality%" equ "2160p_43" (set resolution=2880x2160)
if /i "%quality%" equ "2160_43" (set resolution=2880x2160)
if /i "%quality%" equ "2160p" (set resolution=3840x2160)
if /i "%quality%" equ "2160" (set resolution=3840x2160)
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

set changeFPS=false
if /i "%~9" equ "" (set fps=%default_fps%) else (
set changeFPS=true
set fps=%~9)

set aqMode=%default_aqMode%


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

if /i "%chroma%" neq "original" if /i "%chroma%" neq "420" if /i "%chroma%" neq "422" if /i "%chroma%" neq "444" (echo   Warning: yuv chroma "%chroma%" unrecognized
echo     Known values: 420, 422, 444
goto end)
::check if special chroma was specified
set changeChroma=false
if /i "%chroma%" neq "original" set changeChroma=true

if /i "%volumeLevel%" neq "0.5" if /i "%volumeLevel%" neq "0.6" if /i "%volumeLevel%" neq "0.8" if /i "%volumeLevel%" neq "1" if /i "%volumeLevel%" neq "1.0" if /i "%volumeLevel%" neq "1.2" if /i "%volumeLevel%" neq "1.4" if /i "%volumeLevel%" neq "1.5" if /i "%volumeLevel%" neq "1.6" if /i "%volumeLevel%" neq "1.8" if /i "%volumeLevel%" neq "2" if /i "%volumeLevel%" neq "2.0" if /i "%volumeLevel%" neq "2.2" if /i "%volumeLevel%" neq "2.5" if /i "%volumeLevel%" neq "3" if /i "%volumeLevel%" neq "3.0" if /i "%volumeLevel%" neq "3.5" if /i "%volumeLevel%" neq "4" if /i "%volumeLevel%" neq "4.0" (echo.
echo   volumeLevel unrecognized "%volumeLevel%"   
echo   known values: 0.5, 0.6, 0.8, 1.0, 1.2, 1.4, 1.5, 1.6, 1.8, 2.0, 2.2, 2.5, 3.0, 3.5, 4.0
goto end)
::set volumeLevel=%default_volumeLevel%)

set volumeFilterDisabled=false
if /i "%volumeLevel%" equ "1.0" set volumeFilterDisabled=true
if /i "%volumeLevel%" equ "1" set volumeFilterDisabled=true

::check fps count
if /i "%fps%" equ "original" (set changeFPS=false
::call :updateFPS "%inputVideo_Name%%inputVideo_Extension%"
call :updateFPS "%~1")
if /i "%fps%" equ "invalid" (echo.
echo  Frames Per Second -FPS- check of "%inputVideo_Name%%inputVideo_Extension%" failed
echo  Please make sure it is a valid video file and try again.
goto end)
::check if a non-original fps specified
if /i "%fps%" neq "original" set changeFPS=true

::aqmode=default,0,1,2,3
if /i "%aqMode%" neq "default" if /i "%aqMode%" neq "1" if /i "%aqMode%" neq "2" if /i "%aqMode%" neq "3" (echo.
echo  Error. Unrecognized AQ-Mode: "%aqMode%"
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
set audioMP4safe=false)
if /i "%audioCodec%" equ "vorbis" (set preferredContainer=mkv
set audioMP4safe=false)

::use ffprobe to discover the number of audio tracks and to see if it's compatible with mp4
set audioMP4safe=true
::call :checkAudioCountAndMP4Safe "%inputVideo_Name%%inputVideo_Extension%"
call :checkAudioCountAndMP4Safe "%~1"
if /i "%audioMP4safe%" neq "true" set preferredContainer=mkv

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
if /i "%audioCodec%" equ "copy" (set codecLibrary=copy
set audioExtension=mkv)
set encodeAudio=true
if /i "%audioCodec%" equ "none" (set encodeAudio=false)
if /i "%audioCodec%" equ "no" (set encodeAudio=false)
if /i "%audioCodec%" equ "n" (set encodeAudio=false)
if /i "%vapourSynthFile%" equ "true" (set encodeAudio=false)
if not defined codecLibrary set codecLibrary=libopus
if not defined audioExtension set audioExtension=opus

if /i "%audioBitrate:~-1%" equ "k" set audioBitrate=%audioBitrate:~,-1%

if %audioBitrate% leq 55 (echo   unrecognized bitrate "%audioBitrate%"
echo   Value must be greater than 55 and less than 1536
goto end)
if %audioBitrate% gtr 1536 (echo   unrecognized bitrate "%audioBitrate%"
echo   Value must be greater than 55 and less than 1536.
goto end)

::vEncode myfile.mp4 {h264/h265} {crf} {preset} {8/10/12} {resolution} {chroma}
::4) encode video (into .mp4 for ffmpeg)
::if 8 bit, use ffmpeg + settings
::if 10-12 bit, make sure the correct bit depth x254/x265 file is present, 
::then use ffmpeg to stream the y4m file to x264/x265
::encode it
::encode/copy the audio
::then use mkvmerge to merge the new video, the audio, and (if mkvmerge safe) the old contents

::prepareForBranch
::set inputname=%inputVideo_Name%%inputVideo_Extension%
set inputname=%~1
set outputname_noext=%inputVideo_Name%.%codec%
if /i "%resolution%" neq "original" set outputname_noext=%outputname_noext%.%quality%

::need code for...
::ffmpeg h264
::ffmpeg h254 vapoursynth
::ffmpeg h265
::ffmpeg h265 vapoursynth
::x264
::x264 vapourysnth
::x265
::x265 vapourysnth

::build command lines
set miscSettingsFFmpeg=
set miscSettingsX264=
set miscSettingsX265=
if /i "%changeFPS%" equ "true" if /i "%quality%" equ "original" set miscSettingsFFmpeg=%miscSettingsFFmpeg% -vf "fps=%fps%"
if /i "%changeFPS%" equ "false" if /i "%quality%" neq "original" set miscSettingsFFmpeg=%miscSettingsFFmpeg% -vf "scale=%resolution%"
if /i "%changeFPS%" equ "true" if /i "%quality%" neq "original"  set miscSettingsFFmpeg=%miscSettingsFFmpeg% -vf "fps=%fps%,scale=%resolution%"
if /i "%changeChroma%" equ "true" set miscSettingsFFmpeg=%miscSettingsFFmpeg% -pix_fmt yuv%chroma%p


::branch
if /i "%useFFmpegFor8BitEncodes%" equ "true" if /i "%bitDepth%" equ "8" goto ffmpegEnc
goto videoPipe

:ffmpegEnc
if /i "%changeChroma%" neq "true" set videoOnlyOutputName=%outputname_noext%.ffmpeg.%crfValue%.%preset%.%bitdepth%.mp4
if /i "%changeChroma%" equ "true" set videoOnlyOutputName=%outputname_noext%.ffmpeg.%crfValue%.%preset%.%bitdepth%.%chroma%.mp4
if exist "%videoOnlyOutputName%" del "%videoOnlyOutputName%"

::fork
if /i "%codec%" equ "h265" goto ffmpegH265
::need "-x264-params" for aq mode
if /i "%aqMode%" neq "default" set miscSettingsFFmpeg=%miscSettingsFFmpeg% -x264-params aq-mode=3
::need "-x265-params" for lossless mode

if /i "%vapourSynthFile%" equ "true" goto ffmpegH264VapourSynth

:ffmpegH264
::echo "%ffmpegexe%" -i "%inputname%" %miscSettingsFFmpeg% -preset %preset% -crf %crfValue% -an -sn  "%videoOnlyOutputName%"
"%ffmpegexe%" -i "%inputname%" %miscSettingsFFmpeg% -preset %preset% -crf %crfValue% -an -sn  "%videoOnlyOutputName%"
goto afterFFmpegEncode

:ffmpegH264VapourSynth
"%vspipeexe%" --y4m "%inputname%" - | "%ffmpegexe%" -i - -an %miscSettingsFFmpeg% -preset %preset% -crf %crfValue% "%videoOnlyOutputName%"
goto afterFFmpegEncode

:ffmpegH265
::need -x265-params for lossless mode and aq mode
if /i "%crfValue%" neq "0" if /i "%aqMode%" neq "default" set miscSettingsFFmpeg=%miscSettingsFFmpeg% -x265-params aq-mode=3
if /i "%crfValue%" equ "0" set miscSettingsFFmpeg=%miscSettingsFFmpeg% -x265-params lossless=1

::It is pointless to specify an aq mode in lossless mode, but the syntax would be:
::if /i "%crf%" equ "0" if /i "%aqMode%" neq "default" set miscSettingsFFmpeg=%miscSettingsFFmpeg% -x265-params aq-mode=3:lossless=1


if /i "%vapourSynthFile%" equ "true" goto ffmpegH265VapourSynth

"%ffmpegexe%" -i "%inputname%" -an %miscSettingsFFmpeg% -c:v libx265 -preset %preset% -crf %crfValue% "%videoOnlyOutputName%"

goto afterFFmpegEncode

:ffmpegH265VapourSynth
"%vspipeexe%" --y4m "%inputname%" - | "%ffmpegexe%" -i - -an %miscSettingsFFmpeg% -c:v libx265 -preset %preset% -crf %crfValue% "%videoOnlyOutputName%"

:afterFFmpegEncode

goto processAudio


:videoPipe
@echo on
echo chroma=%chroma%
::uses MEGUI and wal pl naming format: x265-10b.exe 
if /i "%codec%" equ "h264" set encodeExe=%x264prefix%-%bitDepth%b.exe
if /i "%codec%" equ "h265" set encodeExe=%x265prefix%-%bitDepth%b.exe

if not exist "%encodeExe%" (echo.
echo   unable to find "%encodeExe%"
echo   please verify this file exists to encode at %bitDepth%-bit depth
goto end)

if /i "%changeChroma%" neq "true" set videoOnlyOutputName=%outputname_noext%.%crfValue%.%preset%.%bitdepth%.%codec%
if /i "%changeChroma%" equ "true" set videoOnlyOutputName=%outputname_noext%.%crfValue%.%preset%.%bitdepth%.%chroma%.%codec%
if exist "%videoOnlyOutputName%" del "%videoOnlyOutputName%"

::x264.exe and x265.exe use slightly different syntaxes
if /i "%aqMode%" neq "default" (set miscSettingsX264=--aq-mode %aqMode%
set miscSettingsX265=--aq-mode %aqMode%)

::need x264-params for aq mode
::need x265-params for lossless mode

::update chroma settings for x264; x265 does not need the chroma settings specified and will auto-detect based upon source
if /i "%changeChroma%" equ "true" set miscSettingsX264=%miscSettingsX264% --output-csp i%chroma%
::update lossless settings for x265; x264 does it automatically at crf=0
if /i "%crfValue%" equ "0" set miscSettingsX265=%miscSettingsX265% --lossless

::debug code
::echo miscSettingsX265=%miscSettingsX265%


::fork
if /i "%codec%" equ "h265" goto videoPipeH265
if /i "%vapourSynthFile%" equ "true" goto videoPipeH264VapourSynth

:videoPipeH264
"%ffmpegexe%" -i "%inputname%" -an -sn %miscSettingsFFmpeg% -f yuv4mpegpipe - | "%encodeExe%" - --demuxer y4m %miscSettingsX264% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
goto afterVideoPipeH265

:videoPipeH264VapourSynth
::ideal
::"%ffmpegexe%" -i "%inputname%" -an -sn %miscSettingsFFmpeg% -f yuv4mpegpipe - | "%encodeExe%" - --demuxer y4m %miscSettingsX264% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"

::more efficent, less features
"%vspipeexe%" --y4m "%inputname%" - | "%encodeExe%" - --demuxer y4m %miscSettingsX264% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"

::inefficent, full featured
::"%vspipeexe%" --y4m "%inputname%" - | "%ffmpegexe%" -i - -an -sn %miscSettingsFFmpeg% -f yuv4mpegpipe - | "%encodeExe%" - --demuxer y4m %miscSettingsX264% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
goto afterVideoPipeH265


:videoPipeH265
if /i "%vapourSynthFile%" equ "true" goto videoPipeH265VapourSynth
::echo "%ffmpegexe%" -i "%inputname%" -an -sn %miscSettingsFFmpeg% -f yuv4mpegpipe - ^| "%encodeExe%" --input - --y4m %miscSettingsX265% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
"%ffmpegexe%" -i "%inputname%" -an -sn %miscSettingsFFmpeg% -f yuv4mpegpipe - | "%encodeExe%" --input - --y4m %miscSettingsX265% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
goto afterVideoPipeH265

:videoPipeH265VapourSynth
::The ideal solution is to have ffmpeg read the .vpy file directly (just like .avs files) and manipulate the input as needed for the encodeExe. However, that is not possible without compiling ffmpeg with explicit vapoursynth support since this is not usually included.
::Alternatives are to either drop ffmpeg, or to have a 3-stage pipe. Pick 1:
::ideal command, does not work
::"%ffmpegexe%" -i "%inputname%" -an -sn %miscSettingsFFmpeg% -f yuv4mpegpipe - | "%encodeExe%" --input - --y4m %miscSettingsX265% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"

::more efficent, but fewer features
"%vspipeexe%" --y4m "%inputname%" - | "%encodeExe%" --input - --y4m %miscSettingsX265% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"

::inefficent, but full featured
::"%vspipeexe%" --y4m "%inputname%" - | "%ffmpegexe%" -i - -an -sn %miscSettingsFFmpeg% -f yuv4mpegpipe - | "%encodeExe%" --input - --y4m %miscSettingsX265% --crf %crfValue% --preset %preset% --output "%videoOnlyOutputName%"
:afterVideoPipeH265


:processAudio
::extractAudio will dump the audio streams (encoded/copied as specified) to "%inputname%.audio%%i.%audioExtension%" where %i is 0 to %audioStreamCount%-1
::if /i "%encodeAudio%" equ "true" call :extractAudio "%inputname%"
if /i "%encodeAudio%" equ "true" call :extractAudio "%~1"

::merge audio and video into one file
call :mergeStreams "%videoOnlyOutputName%"
if /i "%cleanupEncodedVideoTrack%" equ "true" if exist "%videoOnlyOutputName%" del "%videoOnlyOutputName%"

::if preferred container is mp4, then use ffmpeg to copy the video stream and 1 audio stream
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if exist "%outputname_noext%.mp4" del "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 0 "%ffmpegexe%" -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 1 "%ffmpegexe%" -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 2 "%ffmpegexe%" -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 -map 0:a:1 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 3 "%ffmpegexe%" -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 -map 0:a:1 -map 0:a:2 "%outputname_noext%.mp4"
if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if %audioStreamCount% equ 4 "%ffmpegexe%" -i "%outputname_noext%.mkv" -c:v copy -c:a copy -map 0:v:0 -map 0:a:0 -map 0:a:1 -map 0:a:2 -map 0:a:3 "%outputname_noext%.mp4"

::cleanup
if /i "%cleanupAudioTracks%" equ "true" if /i "%encodeAudio%" equ "true" for /L %%i in (0,1,%currentAudioStreamCount%) do (del "%inputname%.audio%%i.%audioExtension%")
if /i "%cleanupEncodedVideoTrack%" equ "true" if /i "%preferredContainer%" equ "mp4" if /i "%mp4Safe%" equ "true" if exist "%outputname_noext%.mp4" if exist "%outputname_noext%.mkv" del "%outputname_noext%.mkv"



goto end

::startFunctions::
:batchvEncode
set tempfile=temp.%random%.txt
if exist "%tempfile%" del "%tempfile%"
set tempcmdfile=temp.%random%.cmd
if exist "%tempcmdfile%" del "%tempcmdfile%"

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
dir /b *.avc >> %tempfile% 2>nul
dir /b *.hevc >> %tempfile% 2>nul
dir /b *.avs >> %tempfile% 2>nul
dir /b *.vpy >> %tempfile% 2>nul
dir /b *.y4m >> %tempfile% 2>nul

for /f "delims=*" %%i in (%tempfile%) do echo call vencode2 "%%i" %2 %3 %4 %5 %6 %7 %8 %9>>"%tempcmdfile%"

if exist "%tempfile%" del "%tempfile%"
type "%tempcmdfile%"
call "%tempcmdfile%"
type "%tempcmdfile%"
del "%tempcmdfile%"

goto end


::takes a filesource %1 as an input
:encodeAudioFunct
set audioInput=%~1
"%ffmpegexe%" -i "%audioInput%" -vn -sn -c:a %codecLibrary% -b:a %audioBitrate%k "%audioInput%.%audioExtension%"
goto :eof


::Used to update %fps% variable for "ffmpeg -vf fps=%fps%" and takes ffprobe compatible video file as input
::Usage: call :updateFPS "%video%"
:updateFPS
if not exist "%~1" (echo "%~1" does not exist
goto :eof)
set fps=invalid

::debug code
::echo vapourSynthFile=%vapourSynthFile%
::@echo on

if /i "%vapourSynthFile%" neq "true" "%ffprobeexe%" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1 "%~1">"%tempFPSFile%"
if /i "%vapourSynthFile%" equ "true" "%vspipeexe%" --y4m "%~1" - | "%ffprobeexe%"  -f yuv4mpegpipe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1 -i - >"%tempFPSFile%"
if not exist "%tempFPSFile%" goto :eof

for /f "delims== tokens=1,2,3,4" %%i in (%tempFPSFile%) do (set fps=%%j)

if not defined fps set fps=invalid
if /i "%fps%" equ "" set fps=invalid
if /i "%fps%" equ " " set fps=invalid

::debug code
::type %tempFPSFile%
::echo fps=%fps%
::echo pie pie
::pause

if exist "%tempFPSFile%" del "%tempFPSFile%"
goto :eof


:checkAudioCountAndMP4Safe
if not exist "%~1" (echo "%~1" does not exist
goto :eof)
set audioStreamCount=0

::VapourSynth does not support audio
if /i "%vapourSynthFile%" equ "true" goto :eof

::figure out how many streams the audio has by dumping out the codec_name for each

::if /i "%vapourSynthFile%" neq "true"  "%ffprobeexe%" -v error -select_streams a -show_entries stream=codec_name -of default=noprint_wrappers=1 "%~1">"%tempffprobeFile%"
::if /i "%vapourSynthFile%" equ "true" "%vspipeexe%" --y4m "%~1" - | "%ffprobeexe%" -v error -select_streams a -show_entries stream=codec_name -of default=noprint_wrappers=1 -i - >"%tempffprobeFile%"
"%ffprobeexe%" -v error -select_streams a -show_entries stream=codec_name -of default=noprint_wrappers=1 "%~1">"%tempffprobeFile%"
if not exist "%tempffprobeFile%" goto :eof

for /f %%i in (%tempffprobeFile%) do set /a audioStreamCount+=1
echo total audio streams=%audioStreamCount%
if %audioStreamCount% equ 0 (set audioCodec=none
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
goto :eof)

for /f "delims== tokens=1,2,3,4" %%i in (%tempffprobeFile%) do (if /i "%audioCodec%" equ "copy" if /i "%%j" equ "pcm_f32le" set audioMP4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "opus" set audioMP4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "vorbis" set audioMP4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "flac" set audioMP4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wma" set audioMP4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wma2" set audioMP4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wmav" set audioMP4safe=false
if /i "%audioCodec%" equ "copy" if /i "%%j" equ "wmav2" set audioMP4safe=false)
if exist "%tempffprobeFile%" del "%tempffprobeFile%"
goto :eof


:extractAudio
if /i "%~1" equ "" (echo error 
goto :eof)
::set extractAudioFunctFileName=%~nx1
set extractAudioFunctFileName=%~1

if %audioStreamCount% equ 0 goto :eof

::extract out each stream
set currentAudioStreamCount=%audioStreamCount%
set /a currentAudioStreamCount-=1
for /L %%i in (0,1,%currentAudioStreamCount%) do (if exist "%extractAudioFunctFileName%.audio%%i.%audioExtension%" del "%extractAudioFunctFileName%.audio%%i.%audioExtension%")

if /i "%audioCodec%" equ "copy" for /L %%i in (0,1,%currentAudioStreamCount%) do "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% "%extractAudioFunctFileName%.audio%%i.%audioExtension%"
if /i "%audioCodec%" neq "copy" if /i "%volumeFilterDisabled%" equ "true" for /L %%i in (0,1,%currentAudioStreamCount%) do "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2 "%extractAudioFunctFileName%.audio%%i.%audioExtension%"
if /i "%audioCodec%" neq "copy" if /i "%volumeFilterDisabled%" neq "true" for /L %%i in (0,1,%currentAudioStreamCount%) do "%ffmpegexe%" -i "%extractAudioFunctFileName%" -y -map 0:a:%%i -c:a %codecLibrary% -b:a %audioBitrate%k -ac 2 -af "volume=%volumeLevel%" "%extractAudioFunctFileName%.audio%%i.%audioExtension%"

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
echo   For Vapoursynth support: "vspipe" in ^%%path^%%
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
echo   16:9 Resolutions: (original), 480p, 576p, 720p, 1080p, 1440p, 2160p, 4k
echo   4:3: 480p_43, 576p_43, 720p_43, 1080p_43, 1440p_43, 2160p_43, 4k_43
echo   CRF values: usually 16-28, 0=lossless, (%default_crfValue%)
echo   AudioCodecs: copy, none, opus, vorbis, aac, mp3, ac3, wav, flac (%default_audioCodec%)
echo   Presets: ultrafast,veryfast,fast,medium,slow,veryslow,placebo, (%default_preset%)
echo   Bit depth: 8, 10 or 12, (%default_bitDepth%)
echo   YUV Pixel Format: original, 420, 422, 444, (%default_chroma%)
echo   FPS: original, 24000/1001, 25000/1000, 30000/1000, 30000/1001, (%default_fps%)
echo   Note: Use "" for a value to use the default.
echo.
echo   To encode all video files in a directory:
echo   vEncode * h264 "" 16 copy veryslow 8 420
echo   vEncode * h264 "" 18 none "" 10 420
echo   vEncode * h265 "" 18  aac "" 12 420
echo   vEncode * h265 720p 17 opus veryslow 10 444 24000/1001   
echo   vEncode *

:end
endlocal
