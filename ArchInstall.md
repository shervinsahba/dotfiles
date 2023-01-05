# preliminary setup

This is a guide on how to setup my Arch Linux system on top of a btrfs filesystem with LUKS1 encryption on everything except the EFI partition and GRUB as the bootloader. 

A note on bootloaders and encryption:
LUKS2 is not as simply supported with GRUB as of 2022/09. You can achieve it, but the install process isn't friendly. LUKS1 is fine for all but the most paranoid. Instead of GRUB, you can also setup rEFInd as the bootloader, but I just so happened to use GRUB here out of familiarity. I'm unsure if systemd-boot or a booting via a unified kernel image supports decryption of LUKS partitions.

To get started, [download the arch iso](https://archlinux.org/download/)!

If you're trying this on a VM, make sure the machine is set up for UEFI instead of BIOS. Say you're using qemu,  make sure you have the OVMF software installed (`edk2-ovmf` on Arch). Then in QEMU use the command line option `-bios /usr/share/OVMF/x64/OVMF.fd`, or in AQEMU write the same command in the Custom QEMU box under VM->Advanced.

# begin arch installation

Make the font fit the terminal better with
```
setfont ter-132n
```

## internet connectivity

Check internet connectivity. Should be good to go if on Ethernet, but will need `iwctl` followed by `device` commands for WiFi (look it up).
```
ip a
ping 8.8.8.8
```

### wifi
```
iwctl
device list
station <device, probably wlan0> scan
station <device, probably wlan0> get-networks
station <device> connect <network name>
<provide password>
station wlan0 show
exit
```


Update all package databases and then clear the cache.
```
pacman -Syy
pacman -S archlinux-keyring
pacman -Scc
```

Optionally, get mirrors up to speed:
```
reflector --country US --latest 10 --verbose --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```

Optionally, load a keyboard map if you need it. You can browse layout names with `localectl list-keymaps` and load with
```
load keys <layout>
```


# start installation
Set time.
```
timedatectl set-ntp true
```

Check partitions to BE CERTAIN YOU DO THE NEXT OPERATIONS ON THE CORRECT DEVICE.
```
lsblk -f
```

Optional: Totally wipe partition. This can be time consuming!
```
cryptsetup open --type plain -d /dev/random /dev/sdX to_be_wiped
dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
cryptsetup close to_be_wiped
```

Create partitions. 
```
cfdisk /dev/sdX
```
Delete any existing partitions if needed. Then make 
 - a 256M or 512M EDI System partition (512M if you want rescue images or many kernels)
 - a Linux filesystem partition using the remaining space that will utilize btrfs. 
 Write and quit.

Format the EFI partition to fat32.
```
mkfs.vfat -F 32 /dev/sdX1
```

Encryption. Remember to reply YES in all caps to the luksFormat command for it to run.
```
cryptsetup luksFormat -s 512 -h sha512 --use-random --pbkdf pbkdf2 --type luks1 /dev/sdX2

cryptsetup luksOpen /dev/sdX2 cryptroot
```
Note: In the future, the pbkdf should be changed to argon2i when Grub gets better support for LUKS2.

Create btrfs filesystem and mount it.
```
pacman -S btrfs-progs

mkfs.btrfs -L root /dev/mapper/cryptroot
mount -t btrfs /dev/mapper/cryptroot /mnt
```

Create subvolumes in the btrfs filesystem.
```
btrfs sub create /mnt/@
btrfs sub create /mnt/@home
btrfs sub create /mnt/@snapshots
btrfs sub create /mnt/@log
btrfs sub create /mnt/@pkg
```

Disable Copy-On-Write for specific subvolumes
```
chattr +C /mnt/@log
chattr +C /mnt/@pkg
```

Remount in appropriate locations.
```
umount /mnt


mount -o defaults,noatime,ssd,compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt


mkdir -p /mnt/{efi,home,.snapshots,var/log,var/cache/pacman}


mount -o defaults,noatime,ssd,compress=zstd,subvol=@home /dev/mapper/cryptroot /mnt/home

mount -o defaults,noatime,ssd,compress=zstd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots

mount -o defaults,noatime,ssd,compress=zstd,subvol=@log /dev/mapper/cryptroot /mnt/var/log

mount -o defaults,noatime,ssd,compress=zstd,subvol=@pkg /dev/mapper/cryptroot /mnt/var/cache/pacman

mount /dev/sdX1 /mnt/efi
```

Check this over with `lsblk -f` before proceeding.

Pacstrap necessary and basic packages. 
Notes: 
 - For btrfs, we want `btrfs-progs` . For ext4, we would include `e2fsprogs` , and similarly for fat systems, `dosfstools`. 
 - For Intel CPU use `intel-ucode` instead of `amd-ucode` below.
```
pacstrap /mnt base linux linux-firmware base-devel btrfs-progs e2fsprogs dosfstools amd-ucode man-db man-pages vim bash-completion reflector
```


```
genfstab -U /mnt >> /mnt/etc/fstab
```

# chroot and continue setup

chroot into your system and set the root password.
```
arch-chroot /mnt /bin/bash

pacman -Syy
pacman -S archlinux-keyring
reflector -c US -a 6 --sort rate --save /etc/pacman.d/mirrorlist

passwd
```

Set the timezone and hardware clock to utc.
```
ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime

hwclock --systohc --utc
```

Set locale with  `/etc/locale.gen`. Uncomment `en_US.UTF-8 UTF-8` and whatever else you need using vim or the first line below, then run the rest
```
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen

locale-gen

	echo LANG=en_US.UTF-8 > /etc/locale.conf
```

If you use a different keymap, add `KEYMAP=<keymap>` to `/etc/vconsole.conf`.

Create a hostname.
```
echo <hostname> > /etc/hostname
```

Edit the hosts file with `vim /etc/hosts` and append
```
127.0.0.1    localhost
::1          localhost
127.0.1.1    <hostname>.localdomain    <hostname>
```

## swap
Create a swap subvolume. Disable copy on write. Create a swapfile, and check to see if CoW is disabled (if not, disable it on the file manually).
```
btrfs sub create /swap
chattr +C /swap
touch /swap/swapfile && lsattr /swap/swapfile
```

Expand swapfile to desired size. Note: 4G = 4096, 8G = 8192, 16G = 16384. If you want hibernation, you must make your swapfile large enough to hold your RAM! For example, for a 16GB system, I just put down a 17000 count to be sure it fits.
```
dd if=/dev/zero of=/swap/swapfile bs=1024K count=17000
```

Set permissions and format. Turn on swap and add to fstab.
```
chmod 600 /swap/swapfile
mkswap /swap/swapfile
swapon /swap/swapfile
echo /swap/swapfile none swap defaults 0 0 >> /etc/fstab
```

To get hibernation to work, you'll need to find the offset to add into kernel parameters later. 

Normally, for a swapfile, you'd find the offset as the first physical_offset given if we run `filefrag`. However for btrfs, the `filefrag` utility is not correct. Instead [refer to the wiki](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file_on_Btrfs) and follow the instructions, using the mentioned `btrfs_map_physical` script, finding the physical offset, and then dividing by the pagesize (probably 4096, found via `getconf PAGESIZE`).

Make a note of this for later.


## faster unlock

Generate a keyfile so grub doesn't ask for a password a second time on boot. Note: `crypto_keyfile.bin` is the default name that kernel will guess, so don't rename it unless you want to add a kernel parameter.
```
dd bs=512 count=4 iflag=fullblock if=/dev/random of=/crypto_keyfile.bin   
chmod 600 /crypto_keyfile.bin  
chmod 600 /boot/initramfs-linux*  
cryptsetup luksAddKey /dev/sdX2 /crypto_keyfile.bin  
```
As an optional parameter to `luksAddKey`, consider setting `--iter-time` to tradeoff processing time versus security. For example, `luksAddKey --iter-time 1000` corresponds to a second. Use `lukDump <device>` and `luksKillSlot <device> <slot>` to view and delete keys if needed.


## modules

Edit initrams with `vim /etc/mkinitcpio.conf` and make these edits:
```
MODULES=(btrfs)
FILES=(/crypto_keyfile.bin) 
HOOKS=(... keyboard encrypt filesystems ...)
```
If you use a non-US keymap, also add `keymap` after `keyboard`. If there is no `udev` hook, then add a `btrfs` hook as well right after `encrypt`.  

(Arch Wiki notes that if you'd like the ability to run `btrfs check`, which has known issues as of 08/2022, on a mounted file system, add in `BINARIES=(btrfs)`. I haven't done so.)

Finish by recreating the initram images. Maybe wait until the next few steps if you 
```
mkinitcpio -P
```


## bootloader

If you haven't already, get grub and efi.
```
pacman -S grub efibootmgr os-prober
```
Note: If you're using the argon2i key derivation for LUKS2, you'll need to revamp your grub install afterwards or use an alternate like `grub-improved-luks2-git` from the AUR. Check the Arch Wiki.

 Edit `/etc/default/grub` to make changes to support your encryption:
- add a kernel parameter to unlock the LUKS encrypted partition
```
GRUB_CMDLINE_LINUX_DEFAULT="resume=/dev/mapper/cryptroot resume_offset=<swap_offset_from_earlier>"

GRUB_CMDLINE_LINUX="cryptdevice=/dev/sdX2:cryptroot:allow-discards"

GRUB_ENABLE_CRYPTODISK=y
```

Note that the cryptdevice can also be set with UUIDs, which has its pros/cons. The allow-discards param is only for SSDs to allow trim to work with encryption on.
```
GRUB_CMDLINE_LINUX="cryptdevice=UUID=<device-UUID>:cryptroot:allow-discards"
```

Optional configs:
```
GRUB_TIMEOUT=10
GRUB_TIMEOUT_STYLE="menu"
```

Now install grub.
```
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB  

grub-mkconfig -o /boot/grub/grub.cfg  
```


## packages!
These should get you up and running. You may not need to install all of them right now, but they're a good start.

Graphic card driver. Choose one of the following.
```Graphics
pacman -S nvidia nvidia-utils 
pacman -S xf86-video-intel
pacman -S xf86-video-amdGPU
```

```Network
pacman -S networkmanager network-manager-applet openssh
```

```Audio
pacman -S pipewire pipewire-pulse pipewire-jack
```

```Bluetooth
pacman -S bluez bluez-utils blueman
```

```Fonts and icons
pacman -S terminus-font ttf-dejavu 
pacman -S noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme
```

```Utilities
pacman -S git wget curl htop plocate ripgrep fzf neofetch grub-btrfs lshw udiskie
```

```Desktop-Environment
pacman -S i3-wm xorg xorg-xdm dmenu lightdm lightdm-slick-greeter polybar dunst picom python-pywal starship lxappearance feh rofi

pacman -S kitty firefox ranger thunar yadm
```


These can be done later.
```Security
pacman -S fail2ban ufw gufw

echo -e "[sshd]\nenabled = true\nmaxretry = 3" > /etc/fail2ban/jail.local
```


## systemd
```
systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable --now bluetooth
systemctl enable --now fail2ban
```

## bluetooth
Edit `/etc/bluetooth/main.conf` and set `AutoEnable=true` to have bluetooth on at startup.


## display manager
In `/etc/lightdm/lightdm.conf`, set
```
logind-check-graphical=true
greeter-session=lightdm-slick-greeter
```
The former ensures lightdm starts after the graphics have had time to boot. Be sure you set these in the appropriate location (i.e. not under the instructional portion of the config file).


# superuser
```
useradd -m -G wheel -s /bin/bash <user> && passwd <user>
```

Activate wheel superuser group by uncommenting the wheel group line after the following command:
```
visudo
```

Now become the superuser with 
```
su <username>
```

Set XDG directories
```
pacman -S xdg-utils xdg-user-dirs
xdg-user-dirs-update
```

Now do
```
echo "exec start" > ~/.xinitrc
```

## AUR
Then
```
git clone https://aur.archlinux.org/yay-bin
cd yay-bin
makepkg -si PKGBUILD
cd -
rm -rf yay-bin
```

## dotfiles
At this point, you probably want to get your dotfiles onto the system. Here I clone them from my github repo with `yadm`.
```
yadm clone https://github.com/<user>/dotfiles
```

If you have a list of packages saved in your dotfiles, you can install now. For example, form my dotfiles, I can typically run

```
pacman --needed -S $(<~/.pkglists/pkg_base)
pacman --needed -S $(<~/.pkglists/pkg_main)
pacman --needed -S $(<~/.pkglists/aur_main)
```

and then follow up with any other specific packages I may want.


# leave chroot
If you're still the added user, then `exit`. Now exit chroot and go back into the ISO, unmount, and reboot into grub.
```
exit
umount -a
cryptsetup close cryptroot
reboot
```

# upon boot

If all goes according to plan, you should be prompted for the luks passphrase. After it decrypts, you'll end up in GRUB if that's the bootloader that was chosen. Log in.

## setup plocate
For `plocate`, edit `/etc/updatedb.conf` to  add the following. Chiefly, you don't want to prune bind mounts for btrfs. You probably do want to prune paths used for backups like /.snapshots or /timeshift as well as directories like ipynb_checkpoints and pycache.
```
PRUNE_BIND_MOUNTS = "no"
PRUNENAMES = "... .ipynb_checkpoints __pycache__"
PRUNEPATHS = "... /.snapshots /timeshift"
```


## systemd timers
Start timers.
```
systemctl enable --now plocate-updatedb.timer
systemctl enable --now reflector.timer
systemctl enable --now fstrim.timer
systemctl enable --now btrfs-scrub@-.timer
```

Note: For the btrfs (monthly) scrub timer, you can check on it with `journalctl -u btrfs-scrub@-.service` and `btrfs scrub status /`. This is for a mountpoint at `/` by the way. For other mount points, replace the `@-` with the volume name.


# Other ideas
These are other ideas not included in this setup guide, but perhaps worth exploring later.
 
## non-GRUB boot methods

### refind
Refind is a themeable bootloader with some nice features.

### UEFI boot
Don't want to use a bootloader? Want a backup in case your bootloader breaks? Add a UEFI entry of your image directly! [source](https://old.reddit.com/r/archlinux/comments/x26n6h/why_use_a_bootloader_just_boot_directly_into_a/)
```
mkinitcpio --uefi /efi/EFI/Linux/archlinux.efi

efibootmgr --create -d /dev/nvme0n1p1 -p 1 --label "ArchLinux" --loader 'EFI/Linux/archlinux.efi'
```
Add these to `/etc/mkinitcpio.d/linux.preset`:
``` 
ALL_microcode="/boot/intel-ucode.img"
default_efi_image="/efi/EFI/Linux/archlinux.efi"
```
