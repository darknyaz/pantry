#!/usr/bin/env bash

set -e

exec &> >(tee "configure.log")

print () {
    echo -e "\n\033[1m> $1\033[0m\n"
}

ask () {
    read -p "> $1 " -r
    echo
}

select_disk () {
    # Set DISK
    select ENTRY in $(ls /dev/disk/by-id/);
    do
        DISK="/dev/disk/by-id/$ENTRY"
        echo "$DISK" > /tmp/disk
        echo "Installing on $ENTRY."
        break
    done
}

wipe () {
    ask "Do you want to wipe all datas on $ENTRY?"
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        # Clear disk
        dd if=/dev/zero of="$DISK" bs=512 count=1
        wipefs -af "$DISK"
        sgdisk -Zo "$DISK"
    fi
}

partition () {
    # EFI part
    print "Creating EFI part"
    sgdisk -n1:1M:+512M -t1:EF00 "$DISK"
    EFI="$DISK-part1"
    
    # ZFS part
    print "Creating ZFS part"
    sgdisk -n2:0:0 -t2:8300 "$DISK"
    
    # Format efi part
    sleep 1 # wait for disk/by-id symlinks
    print "Format EFI part"
    mkfs.vfat "$EFI"
}

zfs_passphrase () {
    # Generate key
    print "Set ZFS passphrase"
    read -r -p "> ZFS passphrase: " -s pass
    echo "$pass" > /etc/zfs/zroot.key
    chmod 000 /etc/zfs/zroot.key
}

create_pool () {
    # ZFS part
    ZFS="$DISK-part2"
    
    # Create ZFS pool
    print "Create ZFS pool"
    zpool create -f -o ashift=12                          \
                 -o autotrim=on                           \
                 -O acltype=posixacl                      \
                 -O compression=lz4                       \
                 -O relatime=on                           \
                 -O xattr=sa                              \
                 -O dnodesize=legacy                      \
                 -O encryption=aes-256-gcm                \
                 -O keyformat=passphrase                  \
                 -O keylocation=file:///etc/zfs/zroot.key \
                 -O normalization=formD                   \
                 -O mountpoint=none                       \
                 -O canmount=off                          \
                 -O devices=off                           \
                 -R /mnt                                  \
                 zroot "$ZFS"
}

create_datasets () {
    # Slash dataset
    print "Create root dataset"
    zfs create -o mountpoint=none zroot/ROOT

    # System dataset
    ask "Name of the system dataset?"
    system_dataset_name="$REPLY"
    echo "$system_dataset_name" > /tmp/system_dataset
    
    # System dataset
    print "Create system dataset"
    zfs create -o mountpoint=/ -o canmount=noauto "zroot/ROOT/$system_dataset_name"

    # Generate zfs hostid
    print "Generate hostid"
    zgenhostid
    
    # Set bootfs 
    print "Set ZFS bootfs"
    zpool set bootfs="zroot/ROOT/$system_dataset_name" zroot

    # Home dataset
    print "Create home dataset"
    zfs create -o mountpoint=none zroot/data
    zfs create -o mountpoint=/home zroot/data/home
}

export_pool () {
    print "Export zpool"
    zpool export zroot
}

import_pool () {
    print "Import zpool"
    zpool import -d "$DISK-part2" -R /mnt zroot -N -f
    zfs load-key zroot
}

mount_system () {
    system_dataset=$(cat /tmp/system_dataset)
    
    print "Mount system dataset"
    zfs mount "zroot/ROOT/$system_dataset"
    zfs mount -a
    
    # Mount EFI part
    print "Mount EFI part"
    EFI="$DISK-part1"
    mkdir -p /mnt/efi
    mount "$EFI" /mnt/efi
}

# Main
select_disk
wipe
partition
zfs_passphrase
create_pool
create_datasets
export_pool
import_pool
mount_system

# Finish
echo -e "\e[32mAll OK"
