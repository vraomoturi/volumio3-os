#!/bin/sh


IMG_FILE="Volumio.img"
 
echo "Creating Image Bed"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=1048
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 0 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 65 1048
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -a "${LOOP_DEV}"
 
BOOT_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
if [ ! -b "$BOOT_PART" ]
then
	echo "$BOOT_PART doesn't exist"
	exit 1
fi

echo "Creating filesystems"
sudo mkfs.vfat "${BOOT_PART}" -n boot
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${SYS_PART}" -L volumio
sync
 


 
echo "Copying Volumio RootFs"
sudo mkdir /mnt
sudo mkdir /mnt/volumio
sudo mount -t ext4 "${SYS_PART}" /mnt/volumio
sudo rm -rf /mnt/volumio/*
sudo mkdir /mnt/volumio/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/boot
sudo cp -r build/root/* /mnt/volumio
sync

echo "Entering Chroot Environment"

cp scripts/raspberryconfig.sh /mnt/volumio
mount /dev /mnt/volumio/dev -o bind
mount /proc /mnt/volumio/proc -t proc
mount /sys /mnt/volumio/sys -t sysfs
chroot /mnt/volumio /bin/bash -x <<'EOF'
su -
./raspberryconfig.sh
EOF

echo "Base System Installed"
#rm /mnt/volumio/raspberryconfig.sh
echo "Unmounting Temp devices"
umount -l /mnt/volumio/dev 
umount -l /mnt/volumio/proc 
umount -l /mnt/volumio/sys 



echo "Copying Firmwares"
sudo cp -r platforms/udoo/lib/modules /mnt/volumio/lib/modules
sudo cp -r platforms/udoo/firmware /mnt/volumio/lib/firmware
sync
  
ls -al /mnt/volumio/
 
sudo umount /mnt/volumio/
 
echo
echo Umount
echo
sudo losetup -d ${LOOP_DEV}
