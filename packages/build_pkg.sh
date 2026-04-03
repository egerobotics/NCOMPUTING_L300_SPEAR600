#!/bin/bash
# Build opkg package
# Usage: ./build_pkg.sh <name> <version> <description> <files_dir>
NAME=$1; VER=$2; DESC=$3; FILES=$4
PKG="${NAME}_${VER}_arm.ipk"
TMPDIR=$(mktemp -d)

mkdir -p $TMPDIR/data $TMPDIR/control

# Control file
cat > $TMPDIR/control/control << EOF
Package: $NAME
Version: $VER
Architecture: arm
Description: $DESC
Maintainer: spear600@local
Priority: optional
Section: base
EOF
echo "2.0" > $TMPDIR/debian-binary

# Copy files
cp -a $FILES/* $TMPDIR/data/

# Create package
(cd $TMPDIR/control && tar czf ../control.tar.gz .)
(cd $TMPDIR/data && tar czf ../data.tar.gz .)
(cd $TMPDIR && ar r $PKG debian-binary control.tar.gz data.tar.gz 2>/dev/null)
cp $TMPDIR/$PKG /home/test/spear600/packages/repo/
rm -rf $TMPDIR
echo "Built: $PKG"
