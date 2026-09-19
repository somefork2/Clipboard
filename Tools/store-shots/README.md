# Store shots

Marketing screenshots for the Mac App Store listing.

Each frame is plain HTML in `shots.html`, selected with `?n=`. `shoot.sh N`
renders it through headless Chrome at a 2× device scale from a 1440×900 window,
which lands at exactly the 2880×1800 the store asks for.

    ./shoot.sh 1          # writes out/1.png

The scenes show CopyWell doing its job inside another app, because that is the
moment the product is worth something — a palette on an empty desktop is not.
The app's own windows are drawn here rather than screenshotted: a real capture
of a floating palette cannot be composed with the window behind it.

One screenshot in the listing is a real capture of the running app, produced by
`CopyWell --demo-content --render-screenshots`, and it goes last.
