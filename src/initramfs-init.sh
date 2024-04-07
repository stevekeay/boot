#!/bin/busybox sh

cmdline() {
    local value
    value=" $(cat /proc/cmdline) "
    value="${value##* ${1}=}"
    value="${value%% *}"
    [ "${value}" != "" ] && echo "${value}"
}

rescue_shell() {
    echo "Something went wrong. Dropping to a shell."
    export PS1="(initramfs) "
    exec sh
}

/bin/busybox --install -s

echo "$0 is now initramfs-init.sh"
mount -t devtmpfs none /dev || rescue_shell
mount -t proc none /proc || rescue_shell
mount -t sysfs none /sys || rescue_shell

echo "$0: existing partitions:"
fdisk -l

echo "$0: -- Installing example linux distrolet on target disk sda --"

echo "$0: creating target filesystems on /dev/sda1 for /boot"
mkdosfs /dev/sda1 || rescue_shell

echo "$0: creating target filesystems on /dev/sda2 for /"
mke2fs /dev/sda2 || rescue_shell

echo "$0: populating target root filesystem"
mount /dev/sda2 /newroot || rescue_shell
mkdir /newroot/bin
mkdir /newroot/boot
mkdir /newroot/dev
mkdir /newroot/etc /newroot/etc/init.d
mkdir /newroot/home
mkdir /newroot/lib
mkdir /newroot/lib64
mkdir /newroot/mnt
mkdir /newroot/opt
mkdir /newroot/proc
mkdir /newroot/root
mkdir /newroot/run
mkdir /newroot/sbin
mkdir /newroot/srv
mkdir /newroot/sys
mkdir /newroot/tmp
mkdir /newroot/usr /newroot/usr/bin /newroot/usr/sbin
mkdir /newroot/var

cp /bin/busybox /newroot/bin || rescue_shell
chmod 755 /newroot/bin/busybox || rescue_shell
ln -s /bin/busybox newroot/sbin/init || rescue_shell
ln -s /bin/busybox newroot/bin/sh || rescue_shell

cp -a /root/rcS newroot/etc/init.d/rcS || rescue_shell

echo "$0: complete, now change root and exec /sbin/init:"
umount /proc
umount /sys
umount /dev
exec switch_root /newroot /sbin/init
