# ModernJView

**⬅️ [You can download the app here](https://github.com/Quick-Eyed-Sky/ModernJView/releases/latest)** (see the "Assets" section of the release)

A modern, native Apple Silicon rewrite of **JView**, the classic simple Mac picture viewer (next / previous / random navigation), built with Swift and SwiftUI.

The original JView is a 2010-era universal binary (Intel/PowerPC) that macOS is deprecating support for. ModernJView reproduces its full feature set as a native, fast, arm64 app for Apple Silicon Macs, plus a few additions.

## Features

- Next / previous / random image navigation, with configurable custom keys
- Multi-window browsing (drag one or several images/folders onto the app)
- Zoom: fixed percentages, Resize to Fit (shrink only), Expand to Fit
- Rotate / flip
- Slideshow (Auto Browse) with configurable interval
- Delete to Trash (with confirmation) and Delete Immediately (⇧⌘D, no dialog)
- Reveal in Finder
- Copy Prompt: extracts and copies an image's embedded Draw Things / AI generation prompt (PNG/EXIF/TIFF/IPTC metadata)
- Preferences matching the original JView's options (window placement, cache size, folder scan depth, custom navigation keys, etc.)

## Building

No Xcode project is required — this is a plain Swift Package.

```
swift build -c release
```

The build output then needs to be assembled into a `.app` bundle (Info.plist + icon + binary) and code-signed (ad-hoc signing is enough for local/personal use).

## Credits

ModernJView is a modern rebuild of the original **JView**, created by **Allan Liu** ([home.nc.rr.com/jview/jbrowser.html](http://home.nc.rr.com/jview/jbrowser.html)).

## License

TBD.
