# debian-zfs-installer
A install script for installing a debian system on zfs

The script is all based off instructions found on the OpenZFS [wiki](https://github.com/openzfs/zfs/wiki/Debian-Buster-Root-on-ZFS)


# How to use it

First download my Debian ISO
[here](https://stuff.gregf.org/live-image-amd64.hybrid.iso) that includes zfs
support.

Alternatively you can install zfs support manually from one of the official
Debian Live CDs, but this extends the process.


Once you have booted up and have zfs loaded (nothing to do here with my cd)
you'll want to fetch the install script and run it.

wget
https://raw.githubusercontent.com/gregf/debian-zfs-installer/master/install.sh
chmod +x install.sh

Next you'll need to locate your hard disk you want to install on. This script
creates a single disk stripe.

ls /dev/disk/by-id/

Find your drive it should look something like this.

ata-KINGSTON_SA400S37480G_50026B7782EE112D

Next you'll need to export this information for the script.

export DISK=/dev/disk/by-id/ata-KINGSTON_SA400S37480G_50026B7782EE112D

Do not add -part1 or any other partition information to the end.

The last step is to run the script.

*WARNING:* This will destroy all data on the selected disk. Only run this if you
are fine with loosing all the data on the disk. All partitions will be wiped!
You have been warned.


./install.sh

You'll get a few prompts during the install process, but most of it is
automated.

Once done just reboot. You should be in a working debian 10 buster system with zfs.


# Work in progress

This script should not be used in production, it's very much a work in progress
and very opinionated at this time. I'm hoping to make it more user friendly as I
go. I will happily accept patches.
