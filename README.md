# vEncode

vEncode is a windows batch script to encode video into h264/h265

The development emphasis is on zero-configuration "just works" software.

## Key Features:

1. Easy to use
2. Scripting friendly
3. H264/H265 support
4. Automatically place encoded video into Matroska (mkv) or standard MPEG (mp4) containers
5. Supports using the latest versions of key tools (ffmpeg, x264, x265, mkvmerge)
6. Supports changing key encode options crf/preset/bit-depth/chroma/resolutions

## Basic Usage Guide:

1. copy the script to somewhere in your enviornmental path
2. open a command prompt
3. navigate to the directory that has the file to encode
4. vEncode myfile.mp4 h265
5. wait a while
6. use mkvmerge-gui to add tracks/subs and/or modify the meta info

## Release Notes:

1. Intended use case is to set lots of videos to encode and come back later to do the audio (gMKVExtractGUI/audacity), subs (Aegisub) and fix the metainfo (mkvmerge-gui).
2. If downloading from github manually (instead of using an offical release) remember to change the line ending format from Unix back to Windows using Notepad++.
3. Until I figure out how to pipe stuff in Windows (unlikely), 10/12-bit encoding temporarily requires lots of free HD space
4. Currently, 8-bit encodes use ffmpeg but 10/12 bit encoding require x264-10.exe/x264-12.exe and x265-10.exe/x265-12.exe
5. The 10-bit x264 encoder does not appear to honor different chroma values and always uses yuv420p.
6. The 12-bit x265 encoder doesn't seem to like yuv444p.
7. The following OS architecture chart lists the default compatability of the provided binaries (mid Jan 2016) with various bit depths. If the required binary is not provided (marked as "No" on the chart) and needed, compile/obtain one and place into bin/x86 or bin/x64.

![screenshot1](misc/BitDepthCompatability.png)

## Example Usage:
```
vEncode myfile.mp4 {h264/h265} {crf} {preset} {bitdepth} {res} {chroma}
Examples:
vEncode myfile.mkv
vEncode "my file.mkv" h264
vEncode "my file.mkv" h265
vEncode file.mkv h264 20
vEncode file.mkv "" 20
vEncode file.mkv "" 20 veryslow
vEncode file.mkv h265 20 slow 8
vEncode file.mkv h265 "" slow 8 720p
vEncode file.mkv h264 "" slow 8 480p yuv420p
vEncode file.mkv h265 20 slow 10 "" yuv422p
vEncode file.mkv h265 18 veryslow 12 1080p yuv444p

Suggested Values and Defaults:
CRF values: usually 16-28, (18)
Presets: ultrafast,medium,slow,veryslow,placebo, (veryslow)
Bit depth: 8, 10 or 12, (10)
Resolution: 480p, 720p, 1080p, (n/a)
PixelFormat: yuv420p, yuv422p, yuv444p, (yuv422p)
```

## Dependencies: 
Basic: ffmpeg.exe, mkvmerge.exe
For 10Bit Support: x264-10.exe, x265-10.exe, ~50GB HD space
For 12Bit Support: x264-12.exe, x265-12.exe, ~50GB HD space

## Download:
```
Latest Release: none
In Development: v1.0.0-beta
```
Click [here](//github.com/gdiaz384/vEncode/releases) or on "releases" at the top to download the latest version.

## License:
Pick your License: GPL (any) or BSD (any) or MIT/Apache
