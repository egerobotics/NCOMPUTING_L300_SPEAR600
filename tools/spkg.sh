#!/bin/sh
# spkg - Simple Package Manager for nComputing L300
# Packages are tar.gz archives with binaries cross-compiled with ELDK 4.1
# Package format: name-version.spkg (tar.gz with install.sh and files)

REPO_URL="${SPKG_REPO:-http://192.168.1.100:8080}"
PKG_DIR="/readable/packages"
BIN_DIR="/readable/bin"
INSTALLED="/readable/packages/installed"

usage() {
    echo "spkg - Simple Package Manager"
    echo "Usage:"
    echo "  spkg install <package>   - Install package from repo"
    echo "  spkg remove <package>    - Remove package"
    echo "  spkg list                - List installed packages"
    echo "  spkg search              - List available packages"
    echo "  spkg local <file.spkg>   - Install local package"
}

cmd_install() {
    pkg="$1"
    mkdir -p $PKG_DIR $BIN_DIR $INSTALLED
    echo "Downloading $pkg..."
    wget -q -O /tmp/${pkg}.spkg ${REPO_URL}/${pkg}.spkg
    if [ $? -ne 0 ]; then
        echo "Error: package $pkg not found"
        return 1
    fi
    cmd_local /tmp/${pkg}.spkg
}

cmd_local() {
    file="$1"
    mkdir -p $PKG_DIR $BIN_DIR $INSTALLED
    echo "Installing $(basename $file)..."
    cd /
    tar xzf "$file"
    pkg=$(basename "$file" .spkg)
    echo "$pkg" >> $INSTALLED/list
    echo "Installed: $pkg"
}

cmd_remove() {
    pkg="$1"
    if [ -f $INSTALLED/${pkg}.files ]; then
        cat $INSTALLED/${pkg}.files | while read f; do
            rm -f "$f"
        done
        rm $INSTALLED/${pkg}.files
        sed -i "/$pkg/d" $INSTALLED/list 2>/dev/null
        echo "Removed: $pkg"
    else
        echo "Package $pkg not installed"
    fi
}

cmd_list() {
    if [ -f $INSTALLED/list ]; then
        cat $INSTALLED/list
    else
        echo "No packages installed"
    fi
}

cmd_search() {
    wget -q -O - ${REPO_URL}/packages.list 2>/dev/null || echo "Cannot reach repo at $REPO_URL"
}

case "$1" in
    install) cmd_install "$2" ;;
    remove)  cmd_remove "$2" ;;
    list)    cmd_list ;;
    search)  cmd_search ;;
    local)   cmd_local "$2" ;;
    *)       usage ;;
esac
