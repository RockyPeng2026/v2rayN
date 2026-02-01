#!/bin/bash
# Local package script for v2rayN on Ubuntu
# This creates a .deb package from locally built binaries

set -e

VERSION="7.17.3-local"
ARCH="amd64"
PACKAGE_NAME="v2rayn-local"
OUTPUT_DIR="./publish/linux-x64"
PACKAGE_DIR="./v2rayN-Package-local"

echo "=== Building v2rayN .deb package ==="
echo "Version: $VERSION"
echo "Architecture: $ARCH"

# Clean up previous package directory
rm -rf "$PACKAGE_DIR"

# Create package structure
mkdir -p "${PACKAGE_DIR}/DEBIAN"
mkdir -p "${PACKAGE_DIR}/opt/v2rayN"
mkdir -p "${PACKAGE_DIR}/usr/share/applications"
mkdir -p "${PACKAGE_DIR}/etc/sudoers.d"

# Copy built files
echo "Copying built files..."
cp -r ${OUTPUT_DIR}/* "${PACKAGE_DIR}/opt/v2rayN/"

# Copy the existing cores from user config (if they exist)
if [ -d "$HOME/.local/share/v2rayN/bin" ]; then
    echo "Copying existing cores from ~/.local/share/v2rayN/bin..."
    cp -r "$HOME/.local/share/v2rayN/bin" "${PACKAGE_DIR}/opt/v2rayN/" || true
fi

# Copy geo data if exists
for f in geoip.dat geosite.dat Country.mmdb geoip.metadb geoip-only-cn-private.dat; do
    if [ -f "$HOME/.local/share/v2rayN/bin/$f" ]; then
        cp "$HOME/.local/share/v2rayN/bin/$f" "${PACKAGE_DIR}/opt/v2rayN/bin/" || true
    fi
done

# Mark as packaged install
echo "When this file exists, app will not store configs under this folder" > "${PACKAGE_DIR}/opt/v2rayN/NotStoreConfigHere.txt"

# Create control file
cat >"${PACKAGE_DIR}/DEBIAN/control" <<-EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: Local Build <local@localhost>
Depends: libc6 (>= 2.34), fontconfig (>= 2.13.1), desktop-file-utils (>= 0.26), xdg-utils (>= 1.1.3), coreutils (>= 8.32), bash (>= 5.1), libfreetype6 (>= 2.11)
Conflicts: v2rayn
Replaces: v2rayn
Description: v2rayN - A GUI client for Linux with passwordless TUN support
 A GUI client for Linux, support Xray core and sing-box-core and others.
 This is a locally built version with passwordless sudo TUN support.
EOF

# Create desktop entry file
cat >"${PACKAGE_DIR}/usr/share/applications/v2rayN.desktop" <<-EOF
[Desktop Entry]
Name=v2rayN
Comment=A GUI client for Linux, support Xray core and sing-box-core and others
Exec=/opt/v2rayN/v2rayN
Icon=/opt/v2rayN/v2rayN.png
Terminal=false
Type=Application
Categories=Network;Application;
EOF

# Create sudoers file for passwordless TUN
cat >"${PACKAGE_DIR}/etc/sudoers.d/v2rayn" <<-EOF
# Allow v2rayN to run sing-box and xray without password for TUN mode
%sudo ALL=(ALL) NOPASSWD: /opt/v2rayN/bin/sing_box/sing-box *
%sudo ALL=(ALL) NOPASSWD: /opt/v2rayN/bin/xray/xray *
%sudo ALL=(ALL) NOPASSWD: /usr/bin/kill *
EOF

# Create postinst script
cat >"${PACKAGE_DIR}/DEBIAN/postinst" <<-'EOF'
#!/bin/bash
set -e
update-desktop-database 2>/dev/null || true
echo "v2rayN installed successfully!"
echo "You can launch it from your application menu or run: /opt/v2rayN/v2rayN"
EOF

# Create prerm script (cleanup)
cat >"${PACKAGE_DIR}/DEBIAN/prerm" <<-'EOF'
#!/bin/bash
set -e
# Kill running instances
pkill -f '/opt/v2rayN/v2rayN' 2>/dev/null || true
EOF

# Set permissions
echo "Setting permissions..."
chmod 0755 "${PACKAGE_DIR}/DEBIAN/postinst"
chmod 0755 "${PACKAGE_DIR}/DEBIAN/prerm"
chmod 0440 "${PACKAGE_DIR}/etc/sudoers.d/v2rayn"
chmod 0755 "${PACKAGE_DIR}/opt/v2rayN/v2rayN"

# Set correct ownership and permissions for package contents
sudo chown -R root:root "${PACKAGE_DIR}"
sudo find "${PACKAGE_DIR}/opt/v2rayN" -type d -exec chmod 755 {} +
sudo find "${PACKAGE_DIR}/opt/v2rayN" -type f -exec chmod 644 {} +
sudo chmod 755 "${PACKAGE_DIR}/opt/v2rayN/v2rayN"

# Make all binaries in bin subdirectories executable
if [ -d "${PACKAGE_DIR}/opt/v2rayN/bin" ]; then
    for binary in $(find "${PACKAGE_DIR}/opt/v2rayN/bin" -type f -name "sing-box" -o -name "xray" -o -name "mihomo" -o -name "hysteria*"); do
        sudo chmod 755 "$binary" 2>/dev/null || true
    done
fi

# Build the package
echo "Building .deb package..."
sudo dpkg-deb -Zxz --build "$PACKAGE_DIR"
sudo mv "${PACKAGE_DIR}.deb" "v2rayN-${VERSION}-${ARCH}.deb"
sudo chown $(whoami):$(whoami) "v2rayN-${VERSION}-${ARCH}.deb"

echo ""
echo "=== Package built successfully! ==="
echo "Package: v2rayN-${VERSION}-${ARCH}.deb"
echo ""
echo "To install, run:"
echo "  sudo dpkg -i v2rayN-${VERSION}-${ARCH}.deb"
echo ""
