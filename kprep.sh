#!/bin/bash
# author: dniminenn
# ELRepo packages are copyright The ELRepo Project and licensed under GPL v2.
# https://elrepo.org/

# Linux Kernel source code is copyright Linus Torvalds and contributors,
# licensed under GPL v2.

# MIT license applies only to the kprep.sh itself.
# All source components are unmodified and retain their original licenses.

set -e

if [[ $# -lt 1 || $# -gt 2 ]]; then
   echo "usage: $0 <kernel_version> [el_version]"
   echo "example: $0 6.1.141"
   echo "example: $0 6.1.141 el9"
   echo "el_version defaults to el8 if not specified"
   exit 1
fi

KERNEL_VERSION="$1"
EL_VERSION="${2:-el8}"
KERNEL_RELEASE="1.${EL_VERSION}"
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1-2)

ELREPO_SRPM_URL="https://raw.githubusercontent.com/dniminenn/elrepo-srpms/main/kernel/${EL_VERSION}/SRPMS/kernel-ml-${KERNEL_VERSION}-${KERNEL_RELEASE}.nosrc.rpm"
KERNEL_SOURCE_URL="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-${KERNEL_VERSION}.tar.xz"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
   echo -e "${GREEN}[info]${NC} $1"
}

log_error() {
   echo -e "${RED}[error]${NC} $1"
}

if [[ ! -d "rpmbuild/SOURCES" ]]; then
   log_error "run this script from your home directory where rpmbuild/SOURCES exists"
   exit 1
fi

SOURCES_DIR="$(pwd)/rpmbuild/SOURCES"
SPECS_DIR="$(pwd)/rpmbuild/SPECS"
BUILD_DIR="$(pwd)/rpmbuild/BUILD"
BUILDROOT_DIR="$(pwd)/rpmbuild/BUILDROOT"
TEMP_DIR="/tmp/elrepo_setup_$$"

log_info "cleaning up previous builds..."
if [[ -d "$BUILD_DIR" ]]; then
   rm -rf "$BUILD_DIR"
   log_info "✓ cleaned build directory"
fi
if [[ -d "$BUILDROOT_DIR" ]]; then
   rm -rf "$BUILDROOT_DIR"
   log_info "✓ cleaned buildroot directory"
fi

log_info "setting up elrepo kernel build environment..."
log_info "kernel version: ${KERNEL_VERSION}-${KERNEL_RELEASE}"
log_info "el version: ${EL_VERSION}"

mkdir -p "$TEMP_DIR" "$SPECS_DIR"
cd "$TEMP_DIR"

log_info "downloading and extracting elrepo srpm..."
if wget -q "$ELREPO_SRPM_URL"; then
   rpm2cpio "kernel-ml-${KERNEL_VERSION}-${KERNEL_RELEASE}.nosrc.rpm" | cpio -idmv >/dev/null 2>&1
   
   for spec in *.spec; do
       if [[ -f "$spec" ]]; then
           cp "$spec" "${SPECS_DIR}/"
           log_info "✓ spec file copied: $spec"
       fi
   done
   
   for file in *; do
       if [[ "$file" != *.spec && -f "$file" ]]; then
           cp "$file" "${SOURCES_DIR}/"
           if [[ "$file" == *.sh ]]; then
               chmod +x "${SOURCES_DIR}/$file"
           fi
       fi
   done
   log_info "✓ elrepo sources extracted and copied"
else
   log_error "failed to download elrepo srpm from: $ELREPO_SRPM_URL"
   exit 1
fi

log_info "downloading kernel source..."
if [[ ! -f "${SOURCES_DIR}/linux-${KERNEL_VERSION}.tar.xz" ]]; then
   if wget -q "$KERNEL_SOURCE_URL" -O "${SOURCES_DIR}/linux-${KERNEL_VERSION}.tar.xz"; then
       log_info "✓ kernel source downloaded"
   else
       log_error "failed to download kernel source from: $KERNEL_SOURCE_URL"
       exit 1
   fi
else
   log_info "✓ kernel source already exists"
fi

log_info "✓ setup complete"
echo ""
log_info "now build with:"
log_info "  rpmbuild -ba --without bpftool ${SPECS_DIR}/kernel-ml-${KERNEL_MAJOR}.spec"

cd /
rm -rf "$TEMP_DIR"
