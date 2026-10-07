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
If you wanted to work remotely, enable `sshd`, set a password for root, and find your ip.
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
Let's assume the device is the SSD given by `/dev/nvme2n1`. If not, modify as needed. If needed, destroy any existing data structures with
```
sgdisk --zap-all /dev/nvme2n1
```
or `shred -v \dev\nvme0n1` to securely remove all data. Now create new partitions. You can use a tool like `cfdisk <device>` or a one-liner like below:
```
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI -n2:0:0 -t2:8309 -c2:linux /dev/nvme2n1 ;
partprobe -s /dev/nvme2n1
```

## setup encryption
Setup an encrypted LUKS2 container and choose a good passphrase. Then open the container, giving it a name (e.g. cryptroot).
```
cryptsetup luksFormat --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --pbkdf argon2id \
  --hash sha512 \
  /dev/nvme2n1p2

cryptsetup open /dev/nvme2n1p2 cryptroot
```

## format filesystems
```
mkfs.vfat -F32 -n EFI /dev/nvme0n1p1 ;
mkfs.btrfs -L linuxroot /dev/mapper/cryptroot
```

## setup btrfs filesystem and subvolumes
Create btrfs filesystem and subvolumes.
```
mount /dev/mapper/cryptroot /mnt
```
Create subvolumes in the btrfs filesystem. If a swapfile isn't needed, leave out the relevant line. Swap is most useful in laptops for hibernation. Note that we are not creating on for /home. In this setup we will put home on its own separate btrfs drive, just to isolate the two for sysadmin ease.
```
btrfs sub create /mnt/@
btrfs sub create /mnt/@snapshots
btrfs sub create /mnt/@var_log
btrfs sub create /mnt/@var_cache
btrfs sub create /mnt/@var_tmp
btrfs sub create /mnt/@docker
btrfs sub create /mnt/@swap
```
Disable Copy-On-Write for specific subvolumes
```
chattr +C /mnt/@var_tmp 
chattr +C /mnt/@var_cache
chattr +C /mnt/@swap 
chattr +C /mnt/@docker
```
Remount in appropriate locations.
```
umount /mnt
mount -o noatime,ssd,compress=zstd:1,space_cache=v2,subvol=@ /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{efi,.snapshots,var/log,var/cache,var/tmp,var/lib/docker,swap}
mount /dev/nvme2n1p1 /mnt/efi
mount -o noatime,ssd,compress=zstd:1,space_cache=v2,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o noatime,ssd,compress=zstd:1,space_cache=v2,subvol=@var_log /dev/mapper/cryptroot /mnt/var/log
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@var_cache /dev/mapper/cryptroot /mnt/var/cache
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@var_tmp /dev/mapper/cryptroot /mnt/var/tmp
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@docker /dev/mapper/cryptroot /mnt/var/lib/docker
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@swap /dev/mapper/cryptroot /mnt/swap
```

## optional: swapfile, part1
Create a swap file if needed (https://wiki.archlinux.org/title/Btrfs#Swap_file) using the btrfs partition made earlier. If used for hibernation, refer to the size at `cat /sys/power/image_size`, which is about 2/5 of your RAM.
```
btrfs filesystem mkswapfile --size 20g --uuid clear /mnt/swap/swapfile 
```

## install arch
Get up to date. Update all package databases and then clear the cache.
```
reflector --country US --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```
Pacstrap necessary and basic packages. Notes: 
 - For btrfs, we want `btrfs-progs` . For ext4, we would include `e2fsprogs` , and similarly for fat systems, `dosfstools`. 
 - For Intel CPU use `intel-ucode` instead of `amd-ucode` below.
 - We are doing a systemd-boot + UKI approach, otherwise consider `grub` and `efibootmgr`.
 - If you're doing dual-boot or multi-OS add on `os-prober`.
```
reflector --country US --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacstrap -K /mnt base base-devel amd-ucode linux linux-firmware btrfs-progs dosfstools cryptsetup vim nano bash-completion reflector networkmanager iwd git unzip efibootmgr
```

## generate /etc/fstab
```
genfstab -U /mnt >> /mnt/etc/fstab
```
You may want to edit `/etc/fstab` and set the EFI partition's `fmask` and `dmask` to the stricter `0077` umask value. This removes the ability to read (as well as write) for unprivileged users.

## chroot into arch
Change root into arch. 
```
arch-chroot /mnt
```

### setup arch
Set root password and hostname. Set the timezone. Sync the hardware clock and set to utc for daylight savings adjustments. (Note for a dual boot system with Windows, the hwclock option probably should be different)
```
echo <hostname> > /etc/hostname
ln -sf /usr/share/zoneinfo/America/Los_angeles /etc/localtime
hwclock --systohc --utc
passwd
```
Set locale. We'll uncomment `en_US.UTF-8 UTF-8` in `/etc/locale.gen` with the following. Then generate. (If you need a different keymap and font, check out `/etc/vconsole.conf`)
```
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen 
locale-gen 
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo KEYMAP=us > /etc/vconsole.conf
```
Edit `/etc/hosts`. See the example in `man hosts`.
```
127.0.0.1    localhost
127.0.1.1    <hostname>.localdomain <hostname>
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
```

### swapfile, part2
Turn on swap and add to /etc/fstab.
```
swapon /swap/swapfile
echo /swap/swapfile none swap defaults 0 0 >> /etc/fstab
```
For hibernation to work, you'll need the swapfile offset. Note the number (e.g. 533760). We'll use this momentarily to set the resume offset.
```
my_offset=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)
echo $my_offset
```

### /etc/kernel/cmdline and /etc/crypttab
Create the following files for crypttab and kernel cmdline parameters. 
```
my_uuid=$(blkid /dev/nvme2n1p2 | cut -f2 -d ' ' | cut -f2 -d\")
echo "cryptroot UUID=$my_uuid none timeout=900,discard,x-initrd.attach" >> /etc/crypttab
echo "rw root=/dev/mapper/cryptroot cryptdevice=UUID=$my_uuid:cryptroot:allow-discards rootflags=subvol=@ rd.luks.options=discard splash resume=/dev/mapper/cryptroot resume_offset=$my_offset" > /etc/kernel/cmdline
```

### /etc/mkinitcpio.conf
Edit `/etc/mkinitcpio.conf`. For the current setup, include the following in MODULES and HOOKS:
```
MODULES=(btrfs)
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)
```

### /etc/mkinitcpio.d/linux.preset
Edit `/etc/mkinitcpio.d/linux.preset` to generate a Unified Kernel Image (UKI). It should look like the following when the appropriate lines are un/commented.
```
# mkinitcpio preset file to generate UKIs
```
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
#ALL_kerneldest="/boot/vmlinuz-linux"

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

### create the UKI via building the initram
```
mkdir -p /efi/EFI/Linux
mkinitcpio -P
```

## bootloader
Install systemd boot.
```
bootctl install --esp-path=/efi
```
If bootctl complains about a world-accessible EFI location, realize that the live boot is not using the updated `/etc/fstab` with stricter `fmask=0077,dmask=0077` settings. It should be fine.

Edit `/efi/loader/loader.conf` to include:
```
default arch-linux.efi
timeout 4
console-mode max
editor no
```

### boot order
Check `efivars` to see if the new boot entry was added. Use `efivars -o <number1>,<number2><etc>` to reorder boot entries. If no entry was added, create one with something like:
```
efibootmgr --create --disk /dev/nvme2n1 --part 1 --label "Arch-NewRoot" --loader '\EFI\systemd\systemd-bootx64.efi'
```

## services and networking
Now we set up our network services. We are using the iwd backend with NetworkManager, so we will pass this information along but not enable the iwd service directly. We'll also mask off the systemd-networkd service since we're relying on NetworkManager.
```
echo -e "[device]\nwifi.backend=iwd" > /etc/NetworkManager/conf.d/wifi_backend.conf ;
systemctl enable systemd-timesyncd systemd-resolved NetworkManager
systemctl mask systemd-networkd
```

For resolved DNS to work also add:
```
cat >> /etc/NetworkManager/NetworkManager.conf << 'EOF'
[main]
dns=systemd-resolved
EOF
```

## superuser
Add a superuser and activate the wheel group to give sudo privileges. Here we choose the uid to be 1000, but leave blank if not necessary.
```
useradd -m -G wheel -u 1000 -s /bin/bash <user>
passwd <user>
sed -i -e '/^# %wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
```




## reboot
```
sync ; exit; umount -R /mnt; systemctl reboot
```
Check to see if EFI boot order is correct. It may need to be set in BIOS.

## sanity checks
Work through these to check your system.
```
findmnt /
findmnt -t btrfs
lsattr -d /var/cache /var/tmp /var/lib/docker /swap
swapon --show
free -h
cryptsetup status cryptroot
systemctl --failed
journalctl -b -p err
nmcli device status
nmcli connection show
ping -c 3 archlinux.org
resolvectl status
resolvectl query archlinux.org
rfkill list
```


## mount multiple LUKS drives: cryptroot and crypthome
If you have multiple encrypted drives (like one for linux root and another for /home), sharing a keyfile between them makes for efficient unlocks. We'll do that and then mount the /home drive. The unencrypted drives will be referred to as cryptroot and crypthome. We'll assume the /home drive is also btrfs with the subvol named @home.
```
mkdir -p /etc/cryptsetup-keys.d
dd if=/dev/urandom of=/etc/cryptsetup-keys.d/shared.key bs=512 count=4
chmod 600 /etc/cryptsetup-keys.d/shared.key
cryptsetup open /dev/nvme0n1p2 crypthome
cryptsetup luksAddKey /dev/nvme0n1p2 /etc/cryptsetup-keys.d/shared.key
echo "crypthome UUID=<old-drive-luks-uuid> /etc/cryptsetup-keys.d/shared.key luks,nofail,discard" >> /etc/crypttab
mkinitcpio -P
mkdir -p /home
mount -o noatime,ssd,compress=zstd:1,space_cache=v2,subvol=@home /dev/mapper/crypthome /home
```

Confirm it looks okay and add to fstab
```
ls /home
echo "UUID=<crypthome-uuid> /home btrfs noatime,ssd,compress=zstd:1,space_cache=v2,subvol=/@home,nofail 0 0" >> /etc/fstab
```


## pacman.conf (multilib, parallel downloads)
Enable the multilib repo in `/etc/pacman/conf` if you want packages from there (e.g. steam). Also enable parallel downloads and add pacman candy :)
```
sed -i 's/#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf ;
sed -i '/ParallelDownloaas/s/^#//g' /etc/pacman.conf ;
sed -i 's/#Color/Color\nILoveCandy/g' /etc/pacman.conf ;
pacman -Syu
```



# Packages!

## graphics NVIDIA and Wayland 
This depends on your card and needs. With an NVIDIA 4070Ti and the expectation that we will run 32bit apps (i.e. Steam games):
```
pacman -S linux-headers
pacman -S nvidia-open-dkms nvidia-utils nvidia-settings egl-wayland opencl-nvidia
```

You may need [extra requirements with Wayland and NVIDIA](https://wiki.archlinux.org/title/Wayland#Requirements) Create `/etc/modprobe.d/nvidia.conf` with contents
```
options nvidia-drm modeset=1
options nvidia-drm fbdev=1
```
and add `nvidia_modeset nvidia_uvm nvidia_drm` to `MODULES=()` in `/etc/mkinitcpio.conf`. Then `mkinitcpio -P`.


## GNOME desktop environment
For the desktop environment, we'll go with GNOME.
```
pacman -S gnome gnome-tweaks gdm
systemctl enable gdm
```
During the install, you'll be prompted with gnome group packages. Use ^<number> to deselect anything you don't want (e.g. epiphany, gnome-tour, yelp).

## bluetooth
```
pacman -S bluez blues-utils
systemctl enable bluetooth
```

## fonts
```
pacman -S ttf-noto-nerd, noto-fonts-cjk, noto-fonts-extra, noto-fonts-emoji, noto-fonts otf-latin-modern otf-latinmodern-math ttf-firacode-nerd ttf-0xproto-nerd
```

## printing
```
pacman -S cups
systemctl enable cups
```

## snapper
Snap-pac will create snapshots before and after each pacman install.
```
pacman -S snapper snap-pac
```
Create snapper configs with `snapper -c <config name> create-config /path/to/subvolume`. Note that you may need to `umount /.snapshots && rmdir /.snapshots` before running the above. This may  also create a superfluous subvolume `.snapshots` that you can delete with `btrfs sub del /.snapshots`. So it'll look like:
```
umount /.snapshots
rmdir /.snapshots
snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount -o noatime,ssd,compress=zstd:1,space_cache=v2,subvol=@snapshots /dev/mapper/cryptroot /.snapshots
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
```


## other packages
```
pacman -S bitwarden borg borgmatic chromium clamav docker docker-compose fail2ban fastfetch ffmpeg firefox flatpak gdu github-cli gparted gufw htop jq kitty krita lshw man-db mpv neovim obsidian obs-studio pacman-contrib peek plocate qbittorrent signal-desktop starship syncthing tailscale tealdeer tree ufw yadm zip zsh
```

## other essential services and timers
```
systemctl enable --now systemd-oomd 
systemctl enable --now reflector.timer fstrim.timer paccache.timer btrfs-scrub@-.timer btrfs-scrub@home.timer
```
Note: For the btrfs (monthly) scrub timer, you can check on it with `journalctl -u btrfs-scrub@-.service` and `btrfs scrub status /`. This is for a mountpoint at `/` by the way. For other mount points, replace the `@-` with the volume name, like @home for /home.

### plocate 
For `plocate`, edit `/etc/updatedb.conf` to  add the following. Chiefly, you don't want to prune bind mounts for btrfs. You probably do want to prune paths used for backups like /.snapshots or /timeshift as well as directories like python checkpoints and cache.
```
RUNE_BIND_MOUNTS = "no"
RUNENAMES = "... .ipynb_checkpoints __pycache__ node_modules"
RUNEPATHS = "... /.snapshots /timeshift /swap /var/lib/docker"
```
Now
```
systemctl enable --now plocate-updatedb.timer
```

### reflector mirrorlist
Edit `/etc/xdg/reflector/reflector.conf` to use something like
```
--protocol https
--country US
--latest 15
--sort rate
```

## AUR
Get AUR acess with `yay` or `paru`.
```
cd $(mktemp -d)
git clone https://aur.archlinux.org/yay-bin
cd yay-bin
makepkg -si PKGBUILD
```

## ufw firewall
Use `ufw` and its GUI `gufw`:
```
systemctl enable ufw --now
```
Then run `gufw` as a superuser and toggle on. It should persist after reboot. By default ufw denies incoming for home/office profiles. Add any ufw rules you want (i.e. `ufw allow <whatever>`) or use the GUI log to append rules. VPNs may need some config changes in ufw - see the ufw arch wiki. Notably, running `ufw app list` shows preset profiles you may want to use. For example,
```
ufw allow syncthing
```
For tailscale, consider these rules
```
ufw allow in on tailscale0
ufw allow 41641/udp
```

## SMART drive health
```
pacman -S smartmontools
systemctl enable --now smartd
```
Setup some notifications via a https://ntfy.sh topic. Create a script and let smartd's config know about it.
```
vim /usr/local/bin/ntfy-smartd.sh
```
```
#!/bin/bash
curl -s \
  -H "Title: SMART Alert" \
  -H "Priority: urgent" \
  -d "$SMARTD_MESSAGE" \
  https://ntfy.sh/<ntfy.sh topic>
```
```
chmod +x /usr/local/bin/ntfy-smartd.sh
```
Now in `/etc/smartd.conf` append the following directive to the end of DEVICESCAN:
```
DEVICESCAN -m root -M exec /usr/local/bin/ntfy-smartd.sh
```
Now 
```
systemctl restart smartd
```

## SSH
### Host-side:
1.) `systemctl enable --now sshd`
2.) Set `PasswordAuthentication no` on host device in `/etc/ssh/sshd_config`. Also consider `KbdInteractiveAuthentication no` and `UsePAM yes`.
3.) `ufw allow ssh` 
4.) Add ssh jail to fail2ban and enable the service.
```
echo -e "[sshd]\nenabled = true\nmaxretry = 5" > /etc/fail2ban/jail.local
systemctl enable --now fail2ban
```
### Client-side:
1.) Run `ssh-keygen` on new local device. Choose a passphrase and save for later. 
2.) Install public key on remote device with `ssh-copy-id -p <port> <username>@<remotehost>`. Remember, you'll need to briefly reconfigure `/etc/ssh/sshd_config` on the host device to accept password authentication. Provide the username and password of remote user.
3.) Login via `ssh -p <username>:<remotehost>` and provide passphrase.
4.) Disable password authentication on host device in `/etc/ssh/sshd_config`.




# USER STUFF
## syncthing
```
systemctl --user enable --now syncthing.service
```





# OLD

## packages
See the section on dotfiles for how to import packages from a file.
```
pacman -S rofi dunst feh starship batsignal pacman-contrib
pacman -S noto-sans ttf-noto-nerd tf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common ttf-nerd-fonts-symbols-mono ttf-iosevka-nerd ttf-firacode-nerd otf-firamono-nerd ttf-mplus-nerd
pacman -S pipewire pipewire-jack wireplumber
pacman -S bluez bluez-utils blueman
pacman -S kitty firefox yadm bitwarden tealdeer
pacman -S thunar gvfs gvfs-mtp thunar-volman tumbler ffmpegthumbnailer ranger
pacman -S bat wget curl htop plocate ripgrep fzf neofetch lshw
pacman -S network-manager-applet udiskie
pacamn -S fail2ban ufw gufw
pacman -S github-cli
pacman -S xdg-utils xdg-user-dirs
xdg-user-dirs-update
```


## power management
```
pacman -S tlp
systemctl enable tlp
systemctl mask systemd-rfkill.service systemd-rfkill.socket
```
Now in `/etc/tlp.conf` consider these settings.
 - WIFI_PWR_ON_BAT=off to prevent disconnects
 - USB_AUTOSUSPEND=0 to prevent device disconnects
 - USB_EXCLUDE_<DEVICE> to 1 for certain devices if not deactivating autosuspend
 - Run `tlp-stat` and read through to see if any warnings or recommendations

If power profiles daemon (PPD) has been used instead of TLP for power management, you'll need to stop, disable, and mask PPD so it doesn't conflict with TLP.
```
systemctl stop power-profiles-daemon
systemctl disable power-profiles-daemon
systemctl mask power-profiles-daemon
```

### backlight
(See my scripts for using brightnessctl efficiently with i3/sway)
```
pacman -S brightnessctl
```

### powerkey, lid, and idle actions
Edit `/etc/systemd/logind.conf` and `/etc/systemd/sleep.conf`. (Or, more appropriately, create drop-in files at `/etc/systemd/logind.conf.d/override.conf` and `/etc/systemd/sleep.conf.d/override.conf`. See dotfiles.). 

For a laptop that hibernates consider something like.
```
[Login]
HandlePowerKey=hibernate
HandlePowerKeyLongPress=poweroff
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend
IdleAction=suspend-then-hibernate
```
and
```
[Sleep]
HibernateDelaySec=5min
```
For a desktop, if you want to prevent accidental power key bumps consider:
```
[Login]
HandlePowerKey=ignore
HandlePowerKeyLongpress=poweroff
```

## backup luks headers
Store these headers outside of the luks device itself in case of header corruption.
```
cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file luksHeaderBackup-$HOSTNAME-nvme0n1p2
```

## optional: mount btrfs root
You can edit `/etc/fstab` to also add a mount for the btrfs filesystem root itself. To mount it once, 
```
mkdir /mnt/btrfs-root/ ;
mount -o noatime,ssd,compress=zstd,subvol=/ /dev/mapper/cryptroot /mnt/btrfs-root/
```
This just lets you access the filesystem at the highest level if you need.

## battery notification (batsignal)
```
systemctl --user enable batsignal --now
```

# user setup
## dotfiles and packages
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

## btrfs subvolumes
Consider making more subvolumes, especially for directories you do not want to snapshot that are listed under subvolumes you do want to snapshot. Examples:
- /home/$USER/.cache
- /home/$USER/.local/share/Steam/
- /var/lib/docker
- /var/lib/flatpak

