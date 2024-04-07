#!/bin/bash
#
# Linux installation process for bare metal server
#
# Requires:
#
# busybox (copied from /bin)
# vmlinuz (kernel binary copied from /boot)

set -x

ipxe=$(mktemp -d ipxe.XXX) || exit
sudo cp /boot/vmlinuz ${ipxe} || exit
sudo chmod 644 ${ipxe}/vmlinuz || exit
cp src/boot.ipxe ${ipxe} || exit

initramfs=$(mktemp -d initrams-build-XXXX) || exit

echo "Building initrd image -> ${initramfs}"
mkdir -p ${initramfs}/{bin,dev,etc,lib,lib64,newroot,proc,root,sbin,sys,usr/bin,usr/sbin}

cp -a /usr/bin/busybox ${initramfs}/bin/
ln -s /bin/busybox ${initramfs}/bin/sh

cp -a src/initramfs-init.sh ${initramfs}/init
chmod 755 ${initramfs}/init
cp -a src/rcS ${initramfs}/root/rcS
chmod 755 ${initramfs}/root/rcS

echo "Packaging initramfs image -> initrd"
(
  cd ${initramfs} &&
  find . -print0 | \
    cpio --null --create --verbose --format=newc | \
    gzip --best > ../${ipxe}/initrd
)

rm -r ${initramfs}




echo "Creating blank vmdk/raw disk to simulate /dev/hda"
disk_image=$(mktemp disk-image.XXXX.raw) || exit
qemu-img create -f raw ${disk_image} 4000M

echo "Making partition table"
parted -s ${disk_image} mklabel gpt
parted -s -a optimal ${disk_image} mkpart EFI fat32 1MiB 500MiB
parted -s -a optimal ${disk_image} mkpart root ext4 500MiB 100%
parted -s ${disk_image} print


echo "Starting qemu -- to quit, hit Ctrl-A then X"
qemu-system-x86_64 \
  -m 1024 \
  -nographic \
  -serial mon:stdio \
  -drive file=${disk_image},format=raw,index=0,media=disk \
  -boot n  \
  -option-rom /usr/lib/ipxe/qemu/efi-rtl8139.rom \
  -device e1000,netdev=mynet \
  -netdev user,id=mynet,net=1.1.1.0/24,dhcpstart=1.1.1.9,tftp=${ipxe},bootfile=boot.ipxe

rm -rf ${disk_image} ${ipxe}
