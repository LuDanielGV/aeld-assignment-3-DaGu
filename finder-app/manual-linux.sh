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

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # DONE: -Add your kernel build steps here-
    #According with 'Building the Linux Kernel' module 2 video at min. 6.47
    #Following build commands need to be executed
    
    #Clean --> deep clean the kernel build tree
    #make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- mrproper
    #Take into acount to use variables {ARCH} and {CROSS_COMPILE} available.
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    
    #defconfig --> Default kernel configs for arm_dev_board simulated in QEMU 
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    
    #vmlinux --> Builds a kernel image for booting with QEMU
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    
    #modules --> Build any kernel modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    
    #devicetree --> Builds the devicetree
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
    
fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/${FILESYS}" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/${FILESYS} and starting over"
    sudo rm  -rf ${OUTDIR}/${FILESYS}
fi

# -DONE-: Create necessary base directories
#Line 64 --> We are currently in OUTDIR
mkdir ${FILESYS}
#Move to recently created dir
cd "$FILESYS"
#According with 'Linux Root Filesystems' mod2 video min.6.46
#All needed directories are created as follows.
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

#-------------------------------------------------------------------------------
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # -DONE-:  Configure busybox
    #According with 'Linux Root Filesystems' mod2 video min.8.46
    #similar steps than building the kernel, we first need deepclean and default configs
    #works because we are in dir busybox (line 87)
    make distclean
    make defconfig
else
    cd busybox
fi

# -DONE-: Make and install busybox
#According with 'Linux Root Filesystems' mod2 video min.8.46
#works because we are in dir busybox (line 87 or 96)
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install
#ln -sf ash ${OUTDIR}/rootfs/bin/bash

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
