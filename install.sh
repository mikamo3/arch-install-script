#!/usr/bin/env bash
set -xe
# params
INSTALL_TARGET_PATH=
TARGET_BOOT_PARTITION=
ENABLE_MAKE_BOOT_PARTITION=""

#edit
ROOT_PARTITION_LABEL_NAME="arch"
BOOT_PARTITION_SIZE="512M"
ROOT_PARTITION_SIZE=
TIMEZONE="Asia/Tokyo"
LOCALES=("en_US.UTF-8 UTF-8" "ja_JP.UTF-8 UTF-8")
LOCALE_LANG="ja_JP.UTF-8 UTF-8"
UCODE="intel"
create_partition() {
  echo "Partition Layout"
  read -n1 -r -p "do you want to create boot partition? (y/N): " ENABLE_MAKE_BOOT_PARTITION
  lsblk -pno NAME,SIZE,TYPE,MODEL \
    | grep ^/
  read -r -p "input device path:" INSTALL_TARGET_PATH

  [[ -z $INSTALL_TARGET_PATH ]] && {
    echo "abort"
    return 1
  }

  if [[ ! $ENABLE_MAKE_BOOT_PARTITION =~ ^[yY] ]]; then
    blkid \
      | awk '{sub(/:$/,"",$1);print $1}'

    read -r -p "input boot partition" TARGET_BOOT_PARTITION

    [[ -z $TARGET_BOOT_PARTITION ]] && {
      echo "abort"
      return 1
    }
  fi

  if [[ $ENABLE_MAKE_BOOT_PARTITION =~ ^[yY] ]]; then
    if [[ $(lsblk "$INSTALL_TARGET_PATH" -pnlo NAME | grep -cE "^$INSTALL_TARGET_PATH.+") -gt 0 ]]; then
      echo -n "$INSTALL_TARGET_PATH contains data. Do you want to format? (y/N) : "
      read -r
      [[ $REPLY =~ ^[Yy]$ ]] || {
        echo "abort"
        return 1
      }
    fi

    sgdisk -Z "$INSTALL_TARGET_PATH"
    sgdisk -n "0::$BOOT_PARTITION_SIZE" -t "0:ef00" "$INSTALL_TARGET_PATH"
    mkfs.vfat -F32 "$(lsblk "$INSTALL_TARGET_PATH" -pnlo NAME | grep -E "^$INSTALL_TARGET_PATH.+" | sed -n 1p)"
  fi
  sgdisk -n "0::$ROOT_PARTITION_SIZE" -t "0:8300" "$INSTALL_TARGET_PATH" -c 0:"$ROOT_PARTITION_LABEL_NAME"
  mkfs.btrfs "$(lsblk "$INSTALL_TARGET_PATH" -pnlo NAME | grep -E "^$INSTALL_TARGET_PATH.+" | sed -n 2p)"
}

make_subvolumes() {
  echo "make subvolumes"
  root_path="$(lsblk "$INSTALL_TARGET_PATH" -pnlo NAME | grep -E "^$INSTALL_TARGET_PATH.+" | sed -n 2p)"
  mount "$root_path" /mnt
  cd /mnt
  btrfs subvolume create @
  btrfs subvolume create @home
  btrfs subvolume create @var
  cd /
  umount /mnt
}

mount_partition() {
  echo "mount partition"
  boot_path="$(lsblk "$INSTALL_TARGET_PATH" -pnlo NAME | grep -E "^$INSTALL_TARGET_PATH.+" | sed -n 1p)"
  mount -o defaults,relatime,ssd,compress=zstd,subvol=@ "$root_path" /mnt
  mkdir /mnt/{home,var}
  mount -o defaults,relatime,ssd,compress=zstd,subvol=@home "$root_path" /mnt/home
  mount -o defaults,relatime,ssd,compress=zstd,subvol=@var "$root_path" /mnt/var
  mkdir -p /mnt/boot
  if [[ $ENABLE_MAKE_BOOT_PARTITION =~ ^[Yy] ]]; then
    root_path="$(lsblk "$INSTALL_TARGET_PATH" -pnlo NAME | grep -E "^$INSTALL_TARGET_PATH.+" | sed -n 2p)"
    mount "$boot_path" /mnt/boot
  else
    mount "$TARGET_BOOT_PARTITION" /mnt/boot
  fi
}

install_base_package() {
  echo "install base package"
  timedatectl set-ntp true
  pacstrap /mnt base linux linux-firmware openssh ${UCODE}-ucode btrfs-progs networkmanager sudo ansible
}

create_fstab() {
  echo "generate fstab"
  genfstab -U /mnt >/mnt/etc/fstab
}

set_root_password() {
  echo "set root password"
  arch-chroot /mnt passwd
}

set_timezone() {
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
  arch-chroot /mnt hwclock --systohc
}

set_locale() {
  echo "" >/mnt/etc/locale.gen
  for locale in "${LOCALES[@]}"; do
    echo "$locale" >>/mnt/etc/locale.gen
  done
  arch-chroot /mnt locale-gen
  echo "LANG=$LOCALE_LANG" >/etc/locale.conf
}

create_users() {
  # for exec ansible
  arch-chroot /mnt useradd -m -u 2000 -s /bin/bash ansible
  arch-chroot /mnt usermod -aG wheel ansible
  echo "set ansible password"
  arch-chroot /mnt passwd ansible
  echo "ansible   ALL=(ALL) ALL" >> /mnt/etc/sudoers
}

set_bootloader() {
  arch-chroot /mnt mkinitcpio -P
  arch-chroot /mnt bootctl install
  cat <<EOF > /mnt/boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /${UCODE}-ucode.img
initrd  /initramfs-linux.img
options root=PARTLABEL=arch rootflags=subvol=@ rw
EOF
  cat <<EOF >/mnt/boot/loader/loader.conf
default arch
timeout 4
editor no
EOF
}

enable_service() {
  arch-chroot /mnt systemctl enable NetworkManager
  arch-chroot /mnt systemctl enable sshd
}
create_partition
make_subvolumes
mount_partition
install_base_package
set_root_password
create_fstab
set_timezone
set_locale
create_users
set_bootloader
enable_service

echo "DONE"
