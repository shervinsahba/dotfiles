# Arch Linux Installation Notes
[Download the Arch Linux iso](https://archlinux.org/download/) and put it on a USB, either using Ventoy or `dd`. Pop that into your desired device, and disable Secure Boot for the time being.

If you're trying this on a VM, make sure the machine is set up for UEFI instead of BIOS. Say you're using qemu,  make sure you have the OVMF software installed (`edk2-ovmf` on Arch). Then in QEMU use the command line option `-bios /usr/share/OVMF/x64/OVMF.fd`, or in AQEMU write the same command in the Custom QEMU box under VM->Advanced.


## set a better font
```
setfont ter-132n
```

## get online
An ethernet connection should be good to go, but to use WiFi, use `iwctl` as follows.

```
iwctl
station <device, probably wlan0> connect <network name>
```

If you need to find the device or network name, you can be more elaborate with
```
device list
station <device, probably wlan0> scan
station <device, probably wlan0> get-networks
station <device> connect <network name>
station wlan0 show
exit
```

## optional: ssh from another machine
It's likely easier to work from a secondary machine. Thus, setup sshd and tunnel in. Enable `sshd`, set a password for root, and find your ip.
```
systemctl start sshd
passwd
ip addr show
```
Now you can ssh in via `ssh root@<ip-address-of-device>`.

## set time.
```
timedatectl set-ntp true
```

## setup partitions
Check partitions to BE CERTAIN YOU DO THE NEXT OPERATIONS ON THE CORRECT DEVICE.
```
lsblk -f
```

### create partitions
Let's assume the device is the primry SSD, `/dev/nvme0n1`. If not, modify as needed. If needed, destroy any existing data structures with
```
sgdisk --zap-all /dev/nvme0n1
```
or `shred -v \dev\nvme0n1` to securely remove all data. Now create new partitions. You can use a tool like `cfdisk <device>` or a one-liner like below:
```
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI -N2 -t2:8300 -c2:linux /dev/nvme0n1 ;
partprobe -s /dev/nvme0n1
```

## setup encryption
Setup an encrypted LUKS2 container and choose a good passphrase. Then open the container, giving it a name (e.g. cryptroot).
```
cryptsetup luksFormat /dev/nvme0n1p2 ;
cryptsetup luksOpen /dev/nvme0n1p2 cryptroot
```

## format filesystems
```
mkfs.vfat -F32 -n EFI /dev/nvme0n1p1 ;
mkfs.btrfs -L linuxroot /dev/mapper/cryptroot
```

## setup btrfs filesystem and subvolumes
Create btrfs filesystem and subvolumes.
```
mount /dev/mapper/cryptroot /mnt ;
```
Create subvolumes in the btrfs filesystem. If a swapfile isn't needed, leave out the relevant line. Swap is most useful in laptops for hibernation.
```
btrfs sub create /mnt/@ ;
btrfs sub create /mnt/@home ;
btrfs sub create /mnt/@snapshots ;
btrfs sub create /mnt/@var_log ;
btrfs sub create /mnt/@var_cache ;
btrfs sub create /mnt/@swap ;
```
Disable Copy-On-Write for specific subvolumes
```
chattr +C /mnt/@var* ;
chattr +C /mnt/@swap ;
```
Unmount.
```
umount /mnt
```
Remount in appropriate locations.
```
mount -o noatime,ssd,compress=zstd,subvol=@ /dev/mapper/cryptroot /mnt ;
mkdir -p /mnt/{efi, home,.snapshots,var/log,var/cache,var/tmp,swap} ;
mount /dev/nvme0n1p1 /mnt/efi ;
mount -o noatime,ssd,compress=zstd,subvol=@home /dev/mapper/cryptroot /mnt/home ;
mount -o noatime,ssd,compress=zstd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots ;
mount -o noatime,ssd,compress=zstd,subvol=@var_log /dev/mapper/cryptroot /mnt/var/log ;
mount -o noatime,ssd,compress=zstd,subvol=@var_cache /dev/mapper/cryptroot /mnt/var/cache ;
mount -o noatime,ssd,compress=none,subvol=@swap /dev/mapper/cryptroot /mnt/swap
```

## optional: swapfile, part1
Create a swap file if needed (https://wiki.archlinux.org/title/Btrfs#Swap_file) using the btrfs partition made earlier. If used for hibernation, refer to the size at `cat /sys/power/image_size`, which is about 2/5 of your RAM.
```
btrfs filesystem mkswapfile --size 20g --uuid clear /mnt/swap/swapfile ;
```

## install arch
Get up to date. Update all package databases and then clear the cache.
```
reflector --country US --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```
Pacstrap necessary and basic packages. Notes: 
 - For btrfs, we want `btrfs-progs` . For ext4, we would include `e2fsprogs` , and similarly for fat systems, `dosfstools`. 
 - For Intel CPU use `intel-ucode` instead of `amd-ucode` below.
```
pacstrap -K /mnt base base-devel linux linux-firmware btrfs-progs dosfstools amd-ucode vim nano bash-completion reflector networkmanager iwd git unzip 
```
Also consider
```
openssh grub os-prober efibootmgr
```

## generate /etc/fstab
```
genfstab -U /mnt >> /mnt/etc/fstab
```
You may want to edit `/etc/fstab` and set the EFI partition's `fmask` and `dmask` to the stricter `0077` umask value.

### optional: swapfile, part2
Turn on swap and add to /etc/fstab.
```
swapon /swap/swapfile ;
echo /swap/swapfile none swap defaults 0 0 >> /etc/fstab
```
For hibernation to work, you'll need the swapfile offset. Note the number returned by the following command for when we get to the bootloader section (e.g. 533760)
```
btrfs inspect-internal map-swapfile -r /swap/swapfile
```

## chroot into arch
Change root into arch. 
```
arch-chroot /mnt
```
Set root password and hostname. Set the timezone. Sync the hardware clock and set to utc for daylight savings adjustments.
```
echo <hostname> > /etc/hostname ;
ln -sf /usr/share/zoneinfo/US/Pacific /etc/localtime ;
hwclock --systohc --utc ;
passwd
```
Set locale. We'll uncomment `en_US.UTF-8 UTF-8` in `/etc/locale.gen` with the following. Then generate. (If you need a different keymap and font, check out `/etc/vconsole.conf`)
```
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen ;
locale-gen ;
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo KEYMAP=us > /etc/vconsole.conf
```
Edit `/etc/hosts`. See the example in `man hosts`.
```
127.0.0.1    localhost
127.0.1.1    <hostname>.localdomain    <hostname>
::1          localhost ip6-localhost ip6-loopback
```

## initramfs
Create the following files for crypttab and kernel cmdline parameters:
```
echo "cryptroot /dev/disk/by-partlabel/LINUXROOT none timeout=90,discard" > /etc/crypttab.initramfs
echo "rw root=/dev/mapper/cryptroot cryptdevice=/dev/nvme0n1p2:cryptroot:allow-discards rootflags=@,rw splash" > /etc/kernel/cmdline
```
Edit `/etc/mkinitcpio.conf`. Replace udev with systemd. Replace keymap and consolefont with sd-vconsole. Add sd-encrypt before filesystems. Also make sure the btrfs module is loaded. It should look something like this.
```
MODULES=(btrfs)
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```
Edit `/etc/mkinitcpio.d/linux.preset` to generate a Unified Kernel Image (UKI). It should look like the following when the appropriate lines are un/commented.
```
# mkinitcpio preset file to generate UKIs

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
ALL_microcode=(/boot/*-ucode.img)

PRESETS=('default' 'fallback')

#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
default_uki="/efi/EFI/Linux/arch-linux.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"

#fallback_config="/etc/mkinitcpio.conf"
#fallback_image="/boot/initramfs-linux-fallback.img"
fallback_uki="/efi/EFI/Linux/arch-linux-fallback.efi"
fallback_options="-S autodetect"
```


Finish by recreating the initram images.
```
mkinitcpio -P
```

## bootloader

```
bootctl install --esp-path=/efi
```



Install systemd boot:
```
bootctl --path=/boot install
```
If bootctl complains about a world-accessible EFI location, edit `/etc/fstab` and change the EFI partition fmask and umask to the strictor `fmask=0077,dmask=0077` settings.

Now create `/boot/loader/entries/arch.conf` and write:
```
title Arch Linux
linux /vmlinuz-linux

initrd /amd-ucode.img
initrd /initramfs-linux.img
options cryptdevice=UUID=<UUID-OF-ROOT-PARTITION>:luks:allow-discards root=/dev/mapper/luks rootflags=subvol=@ rd.luks.options=discard rw resume=/dev/mapper/luks resume_offset=<SWAP-OFFSET>
```
The swap offset was found above when discussing swapfile creation. The UUID of the root partition is given by `blkid -s UUID -o value /dev/nvme0n1p2`.

Next, edit `/boot/loader/loader.conf` and write
```
default  arch.conf
timeout  4
console-mode max
editor   no
```

## services and networking
Now that you're logged into your Arch system, proceed to setup WiFi again. If using the iwd backend with NetworkManager, don't enable the iwd service. We'll also mask off the systemd-networkd service since we're relying on NetworkManager.
```
echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf ;
systemctl enable systemd-timesyncd systemd-resolved NetworkManager
systemctl mask systemd-networkd
```

## superuser
Add a superuser and activate the wheel group to give sudo privileges.
```
useradd -G wheel -m -s /bin/bash <user> ;
passwd <user> ;
sed -i -e '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
```

## reboot
Exit chroot, unmount, and reboot.
```
sync ;
exit ;
systemctl reboot --firmware-setup
```

# system setup
Graphics? Choose one.
```
pacman -S nvidia nvidia-utils 
pacman -S xf86-video-intel
pacman -S xf86-video-amdgpu
```
Wayland?
```
pacman -S wayland sway waybar xdg-desktop-portal-wlr
```
or X11?
```
pacman -S xorg-server xorg-xinit xorg-xrandr autorandr i3-wm polybar picom lxappearance python-pywal xdg-desktop-portal-gtk
echo -e "# for dunst\nsystemctl --user import-environment DISPLAY XAUTHORITY"> ~/.xinitrc
echo "exec i3" > ~/.xinitrc
```
In either case, you need packages.
```
pacman -S rofi dunst feh starship batsignal
pacman -S noto-sans otf-firamono-nerd ttf-iosevka-nerd ttf-roboto-mono-nerd
pacman -S pipewire pipewire-jack wireplumber
pacman -S bluez bluez-utils blueman
pacman -S kitty firefox ranger thunar yadm bitwarden tealdeer
pacman -S bat wget curl htop plocate ripgrep fzf neofetch lshw
pacman -S network-manager-applet udiskie
pacamn -S fail2ban ufw gufw
pacman -S github-cli
pacman -S xdg-utils xdg-user-dirs
xdg-user-dirs-update
systemctl enable bluetooth
```

Get AUR acess with `yay`.
```
cd $(mktemp -d)
git clone https://aur.archlinux.org/yay-bin
cd yay-bin
makepkg -si PKGBUILD
```
Dotfiles and my favored packages
```
yadm clone https://github.com/<user>/dotfiles
yadm pull
pacman --needed -S $(<~/.pkglists/pkg_base)
pacman --needed -S $(<~/.pkglists/pkg_main)
pacman --needed -S $(<~/.pkglists/aur_main)
```
My scripts. Notably, this includes a `startup` script to launch startup programs.
```
git clone https://github.com/shervinsahba/scripts src/scripts
src/scripts/startup theme
```
Github authentication
```
gh auth login
```

## setup plocate
For `plocate`, edit `/etc/updatedb.conf` to  add the following. Chiefly, you don't want to prune bind mounts for btrfs. You probably do want to prune paths used for backups like /.snapshots or /timeshift as well as directories like ipynb_checkpoints and pycache.
```
PRUNE_BIND_MOUNTS = "no"
PRUNENAMES = "... .ipynb_checkpoints __pycache__"
PRUNEPATHS = "... /.snapshots /timeshift /swap"
```

## systemd timers
```
systemctl enable --now plocate-updatedb.timer reflector.timer fstrim.timer btrfs-scrub@-.timer paccache.timer
```
Note: For the btrfs (monthly) scrub timer, you can check on it with `journalctl -u btrfs-scrub@-.service` and `btrfs scrub status /`. This is for a mountpoint at `/` by the way. For other mount points, replace the `@-` with the volume name.

## power management
```
pacman -S tlp
systemctl enable tlp
systemctl mask systemd-rfkill.service systemd-rfkill.socket
```
 - Deactivate USB_AUTOSUSPEND by setting it to 0 in `/etc/tlp.conf`.
 - Run `tlp-stat` and read through to see if any warnings or recommendations

```
systemctl --user enable batsignal --now
```

```
pacman -S brightnessctl
```



# old
```
pacman -S pipewire-pulse
pacman -S terminus-font ttf-dejavu 
pacman -S noto-fonts-cjk noto-fonts-emoji papirus-icon-theme
pacman -S grub-btrfs
pacman -S xorg-xdm dmenu lightdm lightdm-slick-greeter picom
```
Security
```
echo -e "[sshd]\nenabled = true\nmaxretry = 3" > /etc/fail2ban/jail.local
systemctl enable --now fail2ban
```
```
systemctl enable lightdm
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

# backup luks headers
Backup your luks headers somewhere secure that is outside your encrypted drive.
```
cryptsetup luksHeaderBackup /dev/sdX2 --header-backup-file luksHeaderBackup-$HOSTNAME-sdX2
```