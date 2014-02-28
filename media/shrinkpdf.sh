#!/bin/sh

# Usage example:
# shrinkpdf.sh /output/directory/ sourcefile-in-current-directory.pdf

TMPFILE=/dev/shm/pdfshrink.pdf
rm $TMPFILE

TMPLINK=/dev/shm/pdfcrop.link.pdf
SRCFILE=`realpath "$2"`

echo ln -sf "$SRCFILE" $TMPLINK
ln -sf "$SRCFILE" $TMPLINK

pdfcrop $TMPLINK $TMPFILE

gs  -q -dNOPAUSE -dBATCH -dSAFER \
    -sDEVICE=pdfwrite \
    -dCompatibilityLevel=1.3 \
    -dPDFSETTINGS=/screen \
    -dEmbedAllFonts=true \
    -dSubsetFonts=true \
    -dColorImageDownsampleType=/Bicubic \
    -dColorImageResolution=72 \
    -dGrayImageDownsampleType=/Bicubic \
    -dGrayImageResolution=72 \
    -dMonoImageDownsampleType=/Bicubic \
    -dMonoImageResolution=72 \
    -sOutputFile="$1/$2" \
     $TMPFILE

ls -l "$2" "$1/$2"
