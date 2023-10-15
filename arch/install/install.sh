#!/usr/bin/env bash

set -e

exec &> >(tee "install.log")

print () {
    echo -e "\n\033[1m> $1\033[0m\n"
}

install_aur () {
    arch-chroot /mnt /bin/bash -xe <<EOF
su $user
git clone --depth=1 https://aur.archlinux.org/$1.git /home/$user/$1
cd /home/$user/$1
if ! [[ -z "$2" ]]
then
    sed -i "s/$2/$3/g" PKGBUILD
fi
makepkg -s --noconfirm
for pkg in \$(find . -maxdepth 1 -name '*.zst' | sed -e 's/^.\///g')
do
    echo "Installing \$pkg"
    sudo pacman -U --noconfirm \$pkg
done
exit
EOF
}

# Root dataset
system_dataset=$(cat /tmp/system_dataset)

# Install
print "Install Arch Linux"
pacstrap /mnt       \
  base              \
  base-devel        \
  linux-lts         \
  linux-lts-headers \
  linux-firmware    \
  efibootmgr        \
  git               \
  less              \
  neovim             

# Generate fstab excluding ZFS entries
print "Generate fstab excluding ZFS entries"
genfstab -U /mnt | grep -v "zroot" | tr -s '\n' | sed 's/\/mnt//'  > /mnt/etc/fstab

# Set hostname
read -r -p 'Please enter hostname : ' hostname
echo "$hostname" > /mnt/etc/hostname

# Configure /etc/hosts
print "Configure hosts file"
cat > /mnt/etc/hosts <<EOF
#<ip-address>	<hostname.domain.org>	<hostname>
127.0.0.1	    localhost   	        $hostname
::1   		    localhost              	$hostname
EOF

# Prepare locales and keymap
print "Prepare locales and keymap"
echo "KEYMAP=en" > /mnt/etc/vconsole.conf
sed -i 's/#\(en_US.UTF-8\)/\1/' /mnt/etc/locale.gen
echo 'LANG="en_US.UTF-8"' > /mnt/etc/locale.conf

# Prepare initramfs
print "Prepare initramfs"
cat > /mnt/etc/mkinitcpio.conf <<"EOF"
MODULES=(i915 intel_agp)
BINARIES=()
FILES=(/etc/zfs/zroot.key)
HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)
COMPRESSION="lz4"
EOF

cat > /mnt/etc/mkinitcpio.d/linux-lts.preset <<"EOF"
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-lts"
PRESETS=('default')
default_image="/boot/initramfs-linux-lts.img"
EOF

print "Copy ZFS files"
cp /etc/hostid /mnt/etc/hostid
mkdir -p /mnt/etc/zfs
zpool set cachefile=/etc/zfs/zpool.cache zroot
cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache
cp /etc/zfs/zroot.key /mnt/etc/zfs/zroot.key

### Configure username
print 'Set your username'
read -r -p "Username: " user

# Chroot and configure
print "Chroot and configure system"

arch-chroot /mnt /bin/bash -xe <<EOF

  ### Reinit keyring
  # As keyring is initialized at boot, and copied to the install dir with pacstrap, and ntp is running
  # Time changed after keyring initialization, it leads to malfunction
  # Keyring needs to be reinitialised properly to be able to sign archzfs key.
  rm -Rf /etc/pacman.d/gnupg
  pacman-key --init
  pacman-key --populate archlinux
  pacman-key --recv-keys DDF7DB817396A49B2A2723F7403BD972F75D9D76
  pacman-key --lsign-key DDF7DB817396A49B2A2723F7403BD972F75D9D76
  pacman -S archlinux-keyring --noconfirm
  cat >> /etc/pacman.conf <<"EOSF"
[archzfs]
Server = http://archzfs.com/archzfs/x86_64
EOSF
  pacman -Syu --noconfirm zfs-utils

  # Sync clock
  hwclock --systohc

  # Generate locale
  locale-gen
  source /etc/locale.conf

  # Create user
  mkdir /home/$user
  useradd -d /home/$user $user
  chown -R $user:users /home/$user
EOF

# Set root passwd
print "Set root password"
arch-chroot /mnt /bin/passwd

# Set user passwd
print "Set user password"
arch-chroot /mnt /bin/passwd "$user"

# Configure sudo
print "Configure sudo"
cat > /mnt/etc/sudoers <<EOF
$user ALL=(ALL) ALL
EOF

# Install ZFS
install_aur "zfs-linux-lts" "6\.1\.55-1" "6\.1\.56-1"

# Install ZFSBootMenu
install_aur "zfsbootmenu-efi-bin" "efimounts=.*" "efimounts='\/efi'"

arch-chroot /mnt /bin/bash -xe <<EOF
  # Generate Initramfs
  mkinitcpio -P
EOF

# Activate zfs
print "Configure ZFS"
systemctl enable zfs-import-cache --root=/mnt
systemctl enable zfs-mount --root=/mnt
systemctl enable zfs-import.target --root=/mnt
systemctl enable zfs.target --root=/mnt

# Configure zfsbootmenu
cp -r "/mnt/home/$user/zfsbootmenu-efi-bin/pkg/zfsbootmenu-efi-bin/efi/EFI" /mnt/efi

# Set cmdline
zfs set org.zfsbootmenu:commandline="rw" "zroot/ROOT/$system_dataset"

# Set DISK
if [[ -f /tmp/disk ]]
then
  DISK=$(cat /tmp/disk)
else
  print 'Select the disk you installed on:'
  select ENTRY in $(ls /dev/disk/by-id/);
  do
      DISK="/dev/disk/by-id/$ENTRY"
      echo "Creating boot entries on $ENTRY."
      break
  done
fi

# Create UEFI entries
print 'Create efi boot entries'
if ! efibootmgr | grep ZFSBootMenu
then
    efibootmgr --disk "$DISK" \
      --part 1 \
      --create \
      --label "ZFSBootMenu Recovery" \
      --loader "\EFI\ZBM\zfsbootmenu-recovery-vmlinuz-x86_64.EFI" \
      --verbose
    efibootmgr --disk "$DISK" \
      --part 1 \
      --create \
      --label "ZFSBootMenu" \
      --loader "\EFI\ZBM\zfsbootmenu-release-vmlinuz-x86_64.EFI" \
      --verbose
else
    print 'Boot entries already created'
fi

# Umount all parts
print "Umount all parts"
umount -n -R /mnt

# Export zpool
print "Export zpool"
zpool export zroot

# Finish
echo -e "\e[32mAll OK"
