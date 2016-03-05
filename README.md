# vEncode

vEncode.bat is a windows script that encodes video into h264/h265.

aEncode.bat, a companion script, supports batch multi-audio track encoding.

The development emphasis is on zero-configuration "just works" software.

## Key Features:

- Simplified batch video processing
- Easy to use
- Scripting friendly
- H264/H265/Opus support
- Supports using the latest versions of key tools (ffmpeg, x264, x265, mkvmerge)
- Supports changing key encode options crf/resolution/preset/bit-depth/chroma
- Automatically place encoded video into Matroska (mkv) or standard MPEG (mp4) containers
- Easily change the default encode settings both in the script and at runtime

## Basic Usage Guide:

1. copy the folder somewhere such that vEncode.bat is in %path%
2. open a command prompt
3. navigate using the CLI to the directory that has the file to encode
4. vEncode myfile.mp4 h265
5. wait a while

## Release Notes:

- Intended use case is to set lots of videos to encode and come back later to do the subs (Aegisub/SubtitleEdit) and fix the metainfo (mkvmerge-gui).
- Important: When processing files containing only video or files that mkvmerge just doesn't like (wmv, asf, avs -avisynth scripts-), set the AudioCodec to "none" to process only the video.
-If downloading from github manually (instead of using an official release.zip) remember to change the line ending format from Unix back to Windows using Notepad++.
- 8-bit encodes can use either ffmpeg.exe or x264-8.exe/x265-8.exe but 10/12 bit encoding always require x264-10.exe/x264-12.exe and x265-10.exe/x265-12.exe
- The following OS architecture charts lists the default compatibility of the provided binaries with various bit depths. If the required binary is not provided (marked as "No" on the chart) and needed, compile/obtain one and place into bin/x86 or bin/x64.

![screenshot1](misc/BitDepthCompatability.png)

## Example Usage:
```
vEncode Syntax:
vEncode myfile.mp4 {h264/h265} {resolution} {crf} {audio codec} {preset} {bit-depth} {chroma}
Note1: order is important
Note2: {} means optional
Note3: Double quotes "" means "use the default value"

Examples:
vEncode myfile.mkv
vEncode "my file.mkv" h264
vEncode "my file.mkv" h265
vEncode file.mkv h264
vEncode file.mkv "" 720p
vEncode file.mkv "" 720p 20
vEncode file.mkv h264 1080p 20
vEncode file.mkv h265 1080p 20 opus
vEncode file.mkv h264 1080p 20 aac veryslow
vEncode file.mkv h265 480p 20 opus veryslow
vEncode file.mkv h265 "" 18 opus veryslow
vEncode file.mkv h265 720p 18 opus veryslow 10
vEncode file.mkv h264 720p 16 aac veryslow 10 420
vEncode file.mkv h265 720p 18 opus slow 10 444
vEncode file.mkv h264 1080p 16 copy slow 10 420
vEncode file.mkv h265 720p 18 opus slow 10 444
vEncode file.mkv h265 "" "" opus "" "" 420

Suggested values and (defaults):
Codec: h264, h265, (h265)
Resolution: 480p, 720p, 1080p, 1440p, 4k (n/a)
CRF values: usually 16-28, (17)
AudioCodecs: copy, none, opus, vorbis, aac, mp3, ac3 (opus)
Presets: ultrafast,fast,medium,slow,veryslow,placebo, (veryslow)
Bit depth: 8, 10 or 12, (10)
YUV Pixel Format: 420, 422, 444, (444)
Note: Enter "" for a value to use the default value.

To encode all video files in a directory:
vEncode * h264 "" 16 none veryslow 8 420
vEncode * h265 "" 17 copy "" 12 420
vEncode * h265 720p 17 opus veryslow 10 444
vEncode *
```

```
aEncode Syntax:
aEncode myfile.mp4 {audioCodec} {audioBitrate} {volumeLevel}

Examples:
aEncode myfile.mp4
aEncode myfile.mp4 opus
aEncode myfile.mp4 mp3 192
aEncode myfile.mp4 opus 320 1
aEncode myfile.mp4 opus 320 3.5

Suggested values and (defaults):
Codec: opus, vorbis, aac, mp3, ac3
Bitrate: 96, 128, 160, 192, 224,320
VolumeLevel: 0.5, 0.8, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0

To encode all media files in a directory:
aEncode *
aEncode * opus
aEncode * opus 192
aEncode * opus 192 2.5
```

## Dependencies: 
```
Basic: ffmpeg.exe, mkvmerge.exe
(optional) For native h264/h265 8-bit support: x264-8.exe, x265-8.exe
For 10-bit support: x264-10.exe, x265-10.exe
For 12-bit support: x264-12.exe, x265-12.exe
aEncode.bat requires ffprobe.exe
```

## Download:
```
Latest Version: 1.0.0-rc1
In Development: 1.0.0-rc2
```
Click [here](//github.com/gdiaz384/vEncode/releases) or on "releases" at the top to download the latest version.

## License:
Pick your License: GPL (any) or BSD (any) or MIT/Apache
