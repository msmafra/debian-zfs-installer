#!/usr/bin/env bash

# Exit on error
set -o errexit -o errtrace

export LANG=C

function deb-chroot() {
 chroot /mnt /usr/bin/env DISK=$DISK $@
}

function background() {
    chroot /mnt /bin/bash -cl builtin coproc $@
}

if [ -z $DISK ]; then
   echo "Please export DISK first"
   exit 1
fi

sgdisk --zap-all $DISK
sgdisk -a1 -n1:24K:+1000K -t1:EF02 $DISK
sgdisk     -n3:0:+1G      -t3:BF01 $DISK
sgdisk     -n4:0:0        -t4:BF01 $DISK

sleep 3

zpool create -o ashift=12 -d \
    -o feature@lz4_compress=enabled \
    -o feature@multi_vdev_crash_dump=disabled \
    -o feature@large_dnode=disabled \
    -o feature@sha512=disabled \
    -o feature@skein=disabled \
    -o feature@edonr=disabled \
    -o feature@userobj_accounting=disabled \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O normalization=formD -O relatime=on -O xattr=sa \
    -O mountpoint=/ -R /mnt bpool "${DISK}-part3"

zpool create -o ashift=12 \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
    -O mountpoint=/ -R /mnt rpool "${DISK}-part4"

zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/debian
zfs mount rpool/ROOT/debian

zfs create -o canmount=noauto -o mountpoint=/boot bpool/BOOT/debian
zfs mount bpool/BOOT/debian

zfs create                                 rpool/home
zfs create -o mountpoint=/root             rpool/home/root
zfs create -o canmount=off                 rpool/var
zfs create -o canmount=off                 rpool/var/lib
zfs create                                 rpool/var/log
zfs create                                 rpool/var/spool

zfs create -o com.sun:auto-snapshot=false  rpool/var/cache
zfs create -o com.sun:auto-snapshot=false  rpool/var/tmp
chmod 1777 /mnt/var/tmp

zfs create                                 rpool/opt
zfs create -o canmount=off                 rpool/usr
zfs create                                 rpool/usr/local

zfs create                                 rpool/var/games
zfs create                                 rpool/var/mail
zfs create                                 rpool/var/lib/AccountsService

zfs create -o com.sun:auto-snapshot=false  rpool/var/lib/docker
zfs create -o com.sun:auto-snapshot=false  rpool/var/lib/nfs
zfs create -o com.sun:auto-snapshot=false  rpool/tmp
chmod 1777 /mnt/tmp

debootstrap buster /mnt
zfs set devices=off rpool

echo fluffy.local > /mnt/etc/hostname

touch /mnt/etc/network/interfaces.d/enp9s0
cat >> /mnt/etc/network/interfaces.d/enp9s0<< EOF
auto enp9s0
iface enp9s0 inet dhcp
EOF

touch /mnt/etc/apt/sources.list
cat >> /mnt/etc/apt/sources.list<< EOF
deb http://deb.debian.org/debian buster main contrib non-free
EOF

touch /mnt/etc/apt/sources.list.d/buster-backports.list
cat >> /mnt/etc/apt/sources.list.d/buster-backports.list<< EOF
deb http://deb.debian.org/debian buster-backports main contrib non-free
EOF

touch /mnt/etc/apt/preferences.d/90_zfs
cat >> /mnt/etc/apt/preferences.d/90_zfs<< EOF
Package: libnvpair1linux libuutil1linux libzfs2linux libzfslinux-dev libzpool2linux python3-pyzfs pyzfs-doc spl spl-dkms zfs-dkms zfs-dracut zfs-initramfs zfs-test zfsutils-linux zfsutils-linux-dev zfs-zed
Pin: release n=buster-backports
Pin-Priority: 990
EOF

touch /mnt/etc/systemd/system/zfs-import-bpool.service
cat >> /mnt/etc/systemd/system/zfs-import-bpool.service<< EOF
[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none bpool

[Install]
WantedBy=zfs-import.target
EOF

touch /mnt/etc/default/grub
cat >> /mnt/etc/default/grub<<EOF
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX="root=ZFS=rpool/ROOT/debian"

# Uncomment to enable BadRAM filtering, modify to suit your needs
# This works with Linux (no patch required) and with any kernel that obtains
# the memory map information from GRUB (GNU Mach, kernel of FreeBSD ...)
#GRUB_BADRAM="0x01234567,0xfefefefe,0x89abcdef,0xefefefef"

# Uncomment to disable graphical terminal (grub-pc only)
GRUB_TERMINAL=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command vbeinfo
#GRUB_GFXMODE=640x480

# Uncomment if you don't want GRUB to pass "root=UUID=xxx" parameter to Linux
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
GRUB_DISABLE_RECOVERY="false"

# Uncomment to get a beep at grub start
#GRUB_INIT_TUNE="480 440 1"
EOF

mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys

deb-chroot ln -s /proc/self/mounts /etc/mtab
deb-chroot apt update
deb-chroot apt install --yes locales
deb-chroot dpkg-reconfigure locales
deb-chroot dpkg-reconfigure tzdata
deb-chroot apt install --yes dpkg-dev linux-headers-amd64 linux-image-amd64 console-setup
deb-chroot apt install --yes zfs-initramfs

deb-chroot apt install --yes grub-pc
deb-chroot passwd
deb-chroot systemctl enable zfs-import-bpool.service
deb-chroot cp /usr/share/systemd/tmp.mount /etc/systemd/system/
deb-chroot systemctl enable tmp.mount

deb-chroot update-initramfs -u -k all
deb-chroot update-grub
deb-chroot grub-install $DISK
deb-chroot zfs set mountpoint=legacy bpool/BOOT/debian

echo bpool/BOOT/debian /boot zfs \
    nodev,relatime,x-systemd.requires=zfs-import-bpool.service 0 0 >> /mnt/etc/fstab

deb-chroot mkdir /etc/zfs/zfs-list.cache
deb-chroot touch /etc/zfs/zfs-list.cache/rpool
deb-chroot ln -s /usr/lib/zfs-linux/zed.d/history_event-zfs-list-cacher.sh /etc/zfs/zed.d
background zed -F

if test -s /mnt/etc/zfs/zfs-list.cache/rpool; then
   deb-chroot sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/rpool
else
    killall zed; sleep 1; killall zed; sleep 1
    deb-chroot zfs set canmount=noauto rpool/ROOT/debian
    background zed -F
    deb-chroot sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/rpool
fi

deb-chroot zfs snapshot bpool/BOOT/debian@install
deb-chroot zfs snapshot rpool/ROOT/debian@install
