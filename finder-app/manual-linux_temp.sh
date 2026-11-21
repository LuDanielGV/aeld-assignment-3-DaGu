#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.
set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-
FILESYS=rootfs


#-------------------------------------------------------------------------------
echo "Library dependencies"

cd "${OUTDIR}/${FILESYS}"

${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

#Populate target root filesystem with the dynamic linker and shared libraries
#required by busybox, discovered from ELF metadata
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

INTERP=$(
${CROSS_COMPILE}readelf -a bin/busybox |
grep "program interpreter" |
awk '{print $4}' |
tr -d '[]'
)
echo "[$INTERP]"

cp -v "${SYSROOT}${INTERP}" lib/

for lib in $(${CROSS_COMPILE}objdump -p bin/busybox | awk '/NEEDED/ {print $2}')
do
LIBPATH=$(find "${SYSROOT}" -name "${lib}" | head -n 1)


if [ -z "${LIBPATH}" ]; then
    echo "ERROR: could not find ${lib}"
    exit 1
fi

cp -v "${LIBPATH}" lib64/

done

#-------------------------------------------------------------------------------
# -DONE-: Make device nodes
#According with 'Linux Root Filesystems' mod2 video min.12.30
sudo mknod -m 666 dev/null c 1 3       #to dump things
sudo mknod -m 622 dev/console c 5 1    #To display console

#-------------------------------------------------------------------------------
# -DONE-: Clean and build the writer utility
# Your writer application from Assignment 2 should be cross compiled and placed in the
# outdir/rootfs/home directory for execution on target. - Global var is available -
cd "$FINDER_APP_DIR"
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

#-------------------------------------------------------------------------------
# -DONE-: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
#Copy your finder.sh, conf/username.txt, conf/assignment.txt and finder-test.sh scripts 
#from Assignment 2 into the outdir/rootfs/home directory.
cp -RL ${FINDER_APP_DIR}/* ${OUTDIR}/${FILESYS}/home

#-------------------------------------------------------------------------------
# -DONE-: Chown the root directory
#Copy the autorun-qemu.sh script into the outdir/rootfs/home directory
sudo chown -hR root:root ${OUTDIR}/${FILESYS}

#-------------------------------------------------------------------------------
# -DONE-: Create initramfs.cpio.gz
#Create a standalone initramfs and outdir/initramfs.cpio.gz file based on the contents 
#of the staging directory tree.
cd ${OUTDIR}/${FILESYS}
#According with 'Linux Root Filesystems' mod2 video min.13.23
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio
