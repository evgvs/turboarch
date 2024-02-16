#!/usr/bin/env bash

echo -e "\e[1m\e[46m\e[97mSTAGE 3 ACTIVATED\e[0m"

if [ -f /turboarch-config/wheel_users ]; then
  while IFS="" read -r p || [ -n "$p" ]
  do
    echo -e "\e[1m\e[46m\e[97mADD USER $p TO GROUP wheel\e[0m"
    usermod -a -G wheel "$p"
  done < /turboarch-config/wheel_users

  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00_wheel
fi

if [ -f /turboarch-config/passwd_delta ]; then
  while IFS="" read -r p || [ -n "$p" ]
  do
    IFS=':' read -r -a arr <<< "$p"
    echo -e "\e[1m\e[46m\e[97mCHOWN HOME DIRECTORY ${arr[5]} FOR USER ${arr[0]}\e[0m"
    chown -R "${arr[0]}:${arr[0]}" "${arr[5]}" 
  done < /turboarch-config/passwd_delta
fi

source /turboarch-config/config

echo -e "\e[1m\e[46m\e[97mPERFORMING BASIC CONFIGURATION\e[0m"
ln -sf "/usr/share/zoneinfo/$LOCALTIME" /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$NEWHOSTNAME" > /etc/hostname

if [ "$SET_SPACE_PASSWORD" -eq 1  ]; then
     echo "root: " | chpasswd
fi

rm -rf /boot/*


# установить ЕБУЧИЙ СРАКУТ и хрюки пекмена для него
if [ "$SRAKUT" -eq 1  ]; then
  echo -e "\e[1m\e[40m\e[93mINSTALLING DRACUT AND LVM2\e[0m"
  pacman --noconfirm -Sy lvm2 mdadm dracut

  echo -e "\e[1m\e[40m\e[93mINSTALL DRACUT HOOKS\e[0m"

  install -Dm644 /turboarch-config/90-dracut-install.hook /usr/share/libalpm/hooks/90-dracut-install.hook
  install -Dm644 /turboarch-config/60-dracut-remove.hook /usr/share/libalpm/hooks/60-dracut-remove.hook
  install -Dm755 /turboarch-config/dracut-install /usr/share/libalpm/scripts/dracut-install
  install -Dm755 /turboarch-config/dracut-remove /usr/share/libalpm/scripts/dracut-remove
  
  echo -e "\e[1m\e[40m\e[93mINSTALL KERNEL AND RUN DRACUT HOOKS\e[0m"
  pacman --noconfirm -Rns mkinitcpio
fi

pacman --noconfirm -Sy linux linux-firmware


if [ "$GNOME" -eq 1  ]; then
  echo -e "\e[1m\e[46m\e[97mINSTALLING GNOME\e[0m"
  pacman --noconfirm -Sy gnome gnome-tweaks
  systemctl enable gdm
fi

if [ "$NETWORKMANAGER" -eq 1  ]; then
  echo -e "\e[1m\e[46m\e[97mINSTALLING NETWORKMANAGER\e[0m"
  pacman --noconfirm -Sy networkmanager
  systemctl enable NetworkManager
fi

echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

if [ -d /sys/firmware/efi ]; then
  echo -e "\e[1m\e[46m\e[97mINSTALLING GRUB (UEFI)\e[0m"
  env -i grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCHGRUB || env -i grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARCHGRUB
else
  dev=$(findmnt -n -o SOURCE /boot | sed 's/ .*//;s/\/dev\///;s/\[.*//') 
  if [ -z "$dev" ]; then
    dev=$(findmnt -n -o SOURCE / | sed 's/ .*//;s/\/dev\///;s/\[.*//') 
  fi
  target=$(basename "$(readlink -f "/sys/class/block/$dev/..")")

  if [ -z "$target" ]; then
    echo -e "\e[1m\e[40m\e[93mCANNOT FIND DEVICE ON / FOR SOME REASON\e[0m"
    lsblk
    read -p "Enter drive for GRUB installation (e.g. sda or nvme0n1): " -r target

  fi
  #echo -e "\e[1m\e[46m\e[97mWIPING MBR FROM TARGET DRIVE: \e[0m" 
  #dd if=/dev/zero of=/dev/sdx bs=446 count=1

  echo -e "\e[1m\e[46m\e[97mINSTALLING GRUB (BIOS) ON $target\e[0m" 
  env -i grub-install --target=i386-pc "/dev/$target"
  cp -r /usr/lib/grub/i386-pc /boot/grub
fi

echo -e "\e[1m\e[46m\e[97mCREATING GRUB CONFIG\e[0m"
env -i grub-mkconfig -o /boot/grub/grub.cfg

sync

if [[ "$FORCE_REBOOT_AFTER_INSTALLATION" != "1" ]]; then
  echo -e "\e[1m\e[46m\e[97mSTARTING BASH TO PERFORM MANUAL POST-INSTALL CONFIGURATION\e[0m"
  echo -e "EXIT TO REBOOT"
  bash
fi

echo -e "\e[1m\e[46m\e[97mREBOOTING SYSTEM NOW\e[0m"
sleep 2

sync
echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
