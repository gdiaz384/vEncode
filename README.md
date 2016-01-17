# vencode

vencode is a windows batch script to re-encode video

The development emphasis is on zero-configuration "just works" software.

## Key Features:

1. Easy to use
2. Scripting friendly
3. Simple updates when new versions of tools are released (ffmpeg, x265, mkvmerge)

## Download:

```
Latest Release: none
In Development: v1.0.0-alpha
```
Click [here](//github.com/gdiaz384/vencode/releases) or on "releases" at the top to download the latest version.

## Usage guide:

1. copy the script to somewhere in your enviornmental path
2. open a command prompt
3. navigate to the directory that has the file to encode
4. vencode myfile.mp4 h265

## Release Notes:

1. If downloading from github (other than releases) remember to change the line ending format from unix back to windows using Notepad++
2. Intended use case is to create a temp.cmd, set lots of videos to encode and come back later to do the audio/metainfo using mkvmerge-gui.exe
3. Until I figure out how to pipe stuff in Windows, 10/12-bit encoding temporarily requires lots of free HD space
4. 8-bit encodes will preserve the container format (since that uses ffmpeg) but 10/12 bit video will use the Matroska format
5. Bit depth compatability is not checked at runtime. Make sure the required binary is present in the bin/x86 or bin/x64 for your OS's architecture and codec. The following OS architecture chart lists the default compatability of the provided binaries with various bit depths.

![screenshot1](misc/BitDepthCompatability.png)

## Example usage:
```
vencode myfile.mp4 {h264/h265} {crf} {preset} {8/10/12} {quality} {chroma}
Examples:
vencode "my file.mkv"
vencode "my file.mkv" h264
vencode "my file.mkv" h265
vencode file.mkv h264 20
vencode file.mkv "" 20
vencode file.mkv "" 20 veryslow
vencode file.mkv h265 20 slow 720p
vencode file.mkv h265 "" slow 720p
vencode file.mkv h265 "" slow "" 10 yuv422
vencode file.mkv h264 18 slow "" 8 yuv444
```

## Dependencies: 
Basic: ffmpeg.exe, mkvmerge.exe
For 10Bit Support: x264-10.exe, x265-10.exe, ~50GB HD space
For 12Bit Support: x264-12.exe, x265-12.exe, ~50GB HD space

## License:
Pick your License: GPL (any) or BSD (any) or MIT/Apache
