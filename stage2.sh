#!/usr/bin/env bash

echo -e "\e[1m\e[46m\e[97mSTAGE 2 ACTIVATED\e[0m"


cd /host-system || exit 1

echo -e "\e[1m\e[100m\e[97mCOUNTING FILES\e[0m"
total=$(find bin etc lib lib64 sbin srv usr var 2>/dev/null | wc -l)
echo -e "\e[1m\e[100m\e[97mFOUND $total FILES\e[0m"

echo -e "\e[1m\e[41m\e[97mDESTROYING HOST SYSTEM IN 5 SECONDS\e[0m"

for i in 5 4 3 2 1; do
  printf "%s..." "$i"
  sleep 1
done
printf "\n"

echo -e "\e[1m\e[41m\e[97mDESTROYING HOST SYSTEM\e[0m"
rm -rvf bin etc lib lib64 sbin srv usr var |& { I=0; while read -r; do printf "%s files removed\r" "$((++I))"; done; echo ""; }
echo -e "\e[1m\e[41m\e[97mHOST SYSTEM DESTROYED\e[0m"

cd / 

echo -e "\e[1m\e[46m\e[97mSETING UP PACMAN\e[0m"

source /host-system/turboarch-config/config
cp /host-system/turboarch-config/mirrorlist.default /etc/pacman.d/mirrorlist

echo 'nameserver 1.1.1.1' > /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf

pacman-key --init
pacman-key --populate


if [ "$REFLECTOR" -eq 1  ]; then
  # взрыв мозга блять
  mkdir /thisroot
  mount --bind / /thisroot

  echo -e "\e[1m\e[46m\e[97mINSTALLING REFLECTOR\e[0m"
  pacstrap /thisroot reflector

  echo -e "\e[1m\e[46m\e[97mRUNNING REFLECTOR (it will take some time)\e[0m"
  reflector --country Russia,France,Netherlands --latest 12 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist
fi


echo -e "\e[1m\e[46m\e[97mINSTALLING BASE SYSTEM\e[0m"
pacstrap -K /host-system base grub neofetch sudo vim efibootmgr xfsprogs btrfs-progs dhcpcd wpa_supplicant

echo -e "\e[1m\e[46m\e[97mCOPYING FSTAB\e[0m"

cp /host-system/turboarch-config/fstab /host-system/etc/fstab
cp /host-system/turboarch-config/crypttab /host-system/etc/crypttab

chmod +x /host-system/turboarch-config/stage3.sh

if [ -f /host-system/turboarch-config/passwd_delta ]; then
  echo -e "\e[1m\e[46m\e[97mCONFIGURING USERS\e[0m"

  for word in passwd shadow group gshadow; do
    # ПРИМИТЕ МЕНЯ РАБОТАТЬ В БАМЖАРО ХРЮНИКС!!!
    jopa=$(tail -n+2 /host-system/etc/${word})
    echo -e "$(grep '^root:' /host-system/turboarch-config/${word}_delta)\n$jopa\n$(grep -v '^root:' /host-system/turboarch-config/${word}_delta)\n" | grep "\S" > /host-system/etc/${word}
  done
fi

echo -e "\e[1m\e[46m\e[97mEXECUTING CHROOT TO NEW SYSTEM\e[0m"
arch-chroot /host-system /turboarch-config/stage3.sh || echo -e "\e[1m\e[41m\e[97mOOOPS... CANNOT CHROOT TO NEW SYSTEM!\e[0m"
echo "Dropping to shell. Note that you are in chroot and your old system is destroyed."
bash
