# Arch Linux Installation Notes
[Download the Arch Linux iso](https://archlinux.org/download/) and put it on a USB, either using Ventoy or `dd`. Pop that into your desired device, and disable Secure Boot for the time being.

If you're trying this on a VM, make sure the machine is set up for UEFI instead of BIOS. Say you're using qemu,  make sure you have the OVMF software installed (`edk2-ovmf` on Arch). Then in QEMU use the command line option `-bios /usr/share/OVMF/x64/OVMF.fd`, or in AQEMU write the same command in the Custom QEMU box under VM->Advanced.


# ACT1: Creating an Arch system
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
If you need to work remotely, enable `sshd`, set a password for root, and find your ip.
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

## drive partitions
Check partitions to BE CERTAIN YOU DO THE NEXT OPERATIONS ON THE CORRECT DEVICE.
```
lsblk -f
```
Let's assume the device is the SSD given by `/dev/nvme2n1`. If not, modify as needed. If needed, destroy any existing data structures with
```
sgdisk --zap-all /dev/nvme2n1
```
or `shred -v \dev\nvme0n1` to securely remove all data. Now create new partitions. You can use a tool like `cfdisk <device>` or a one-liner like below:
```
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI -n2:0:0 -t2:8309 -c2:linux /dev/nvme2n1 ;
partprobe -s /dev/nvme2n1
```

## drive encryption
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

## drive filesystems - btrfs
```
mkfs.vfat -F32 -n EFI /dev/nvme2n1p1 ;
mkfs.btrfs -L linuxroot /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
```
Now we begin to form the btrfs subvolume architecture. The idea is segment directories that either should not be snapshotted or should not have copy-on-write. Note: we are not creating a subvolume for /home just yet. In this setup we will put home on its a separate btrfs drive, just to isolate the two for sysadmin ease. If you have a single drive system, add in a subvolume for /home as needed.
```
btrfs sub create /mnt/@
btrfs sub create /mnt/@snapshots
btrfs sub create /mnt/@var_log
btrfs sub create /mnt/@var_cache
btrfs sub create /mnt/@var_tmp
btrfs sub create /mnt/@docker
btrfs sub create /mnt/@flatpak
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
mkdir -p /mnt/{efi,.snapshots,var/log,var/cache,var/tmp,var/lib/docker,var/lib/flatpak,swap}
mount /dev/nvme2n1p1 /mnt/efi
mount -o noatime,ssd,compress=zstd:1,space_cache=v2,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o noatime,ssd,compress=zstd:1,space_cache=v2,subvol=@var_log /dev/mapper/cryptroot /mnt/var/log
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@var_cache /dev/mapper/cryptroot /mnt/var/cache
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@var_tmp /dev/mapper/cryptroot /mnt/var/tmp
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@docker /dev/mapper/cryptroot /mnt/var/lib/docker
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@flatpak /dev/mapper/cryptroot /mnt/var/lib/flatpak
mount -o noatime,ssd,space_cache=v2,nodatacow,subvol=@swap /dev/mapper/cryptroot /mnt/swap
```

## swapfile, part1
Create a swap file (https://wiki.archlinux.org/title/Btrfs#Swap_file) using the btrfs partition made earlier. If used for hibernation, refer to the size at `cat /sys/power/image_size`, which is about 2/5 of your RAM.
```
btrfs filesystem mkswapfile --size 20g --uuid clear /mnt/swap/swapfile 
```

## install arch
Update package mirrorlists.
```
reflector --country US --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
```
Pacstrap basic packages to begin the Arch system. Notes: 
 - For btrfs, we want `btrfs-progs` . For ext4, we would include `e2fsprogs` , and similarly for fat systems, `dosfstools`. 
 - For Intel CPU use `intel-ucode` instead of `amd-ucode` below.
 - We are doing a systemd-boot + UKI approach, otherwise consider `grub` and `efibootmgr`.
 - If you're doing dual-boot or multi-OS add on `os-prober`.
```
reflector --country US --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacstrap -K /mnt base base-devel amd-ucode linux linux-firmware btrfs-progs dosfstools cryptsetup vim nano bash-completion reflector networkmanager iwd git efibootmgr
```

## generate /etc/fstab
```
genfstab -U /mnt >> /mnt/etc/fstab
```
You may want to edit `/etc/fstab` and set the EFI partition's `fmask` and `dmask` to the stricter `0077` umask value. This removes the ability to read (as well as write) for unprivileged users.

## chroot into arch
Change root into arch. Set root password and hostname. Set the timezone. Sync the hardware clock and set to utc for daylight savings adjustments. (Note for a dual boot system with Windows, the hwclock option probably should be different)
```
arch-chroot /mnt
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
Create the following files for crypttab and kernel cmdline parameters. We'll need the drive's UUID as well as the swap offset.
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
Edit `/etc/mkinitcpio.d/linux.preset` to generate a Unified Kernel Image (UKI). It should look like the following when the appropriate lines are un/commented. If EFI is small, comment out the fallbacks and remove it from PRESETS.
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
If bootctl warns about a world-accessible EFI location, realize that the live boot is not using the updated `/etc/fstab` with stricter `fmask=0077,dmask=0077` settings. It should be fine.

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

## crypthome - mount an additional LUKS drive for /home
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

## reboot and login as user
```
sync ; exit; umount -R /mnt; systemctl reboot
```
Check to see if EFI boot order is correct. It may need to be set in BIOS. Once you're set up, log in as your user.

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



# ACT2: Graphics and Desktop Environment

## pacman.conf (multilib, parallel downloads)
Let's first config pacman for parallel downloads. Also enable the multilib repo in `/etc/pacman/conf` if you want packages from there (e.g. steam). Adding some candy is fun, too.
```
sed -i 's/#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf ;
sed -i '/ParallelDownloaas/s/^#//g' /etc/pacman.conf ;
sed -i 's/#Color/Color\nILoveCandy/g' /etc/pacman.conf ;
pacman -Syu
```

## graphics NVIDIA and Wayland 
This depends on your card and needs. With an NVIDIA 4070Ti and the expectation that we will run 32bit apps (i.e. Steam games):
```
pacman -S linux-headers
pacman -S nvidia-open-dkms nvidia-utils nvidia-settings egl-wayland opencl-nvidia
pacman -S lib32-nvidia-utils lib32-opencl-nvidia
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
pacman -S gnome gnome-extensions-app gnome-tweaks gdm nautilus-python nautilus-image-converter
systemctl enable gdm
```
During the install, you'll be prompted with gnome group packages. Use ^<number> to deselect anything you don't want (e.g. epiphany, gnome-tour, yelp).


## terminal
Install your desired terminal emulators. GNOME at the moment has no ability to set the default terminal. That's where `xdg-terminal-exec comes` into play. By listing the preferred terminals in order, it should open those when needed, like when launching TUIs.
```
pacman -S kitty xdg-terminal-exec
echo "kitty.desktop" > ~/.config/xdg-terminals.list
```

## audio
GNOME should have handled pipewire. Otherwise check to see if the following is installed and enabled. If not, download the packages and enable --now.
```
pacman -Q pipewire pipewire-pulse pipewire-jack wireplumber 2>&1
systemctl --user status pipewire pipewire-pulse wireplumber
```

## bluetooth
```
pacman -S bluez blues-utils
systemctl enable --now bluetooth
```

## fonts
```
pacman -S ttf-noto-nerd, noto-fonts-cjk, noto-fonts-extra, noto-fonts-emoji, noto-fonts otf-latin-modern otf-latinmodern-math ttf-firacode-nerd ttf-0xproto-nerd
```

## reboot: log into your desktop environment
```
sync
systemctl reboot
```

## backup luks headers
Store these headers outside of the luks device itself in case of header corruption.
```
cryptsetup luksHeaderBackup /dev/nvme2n1p2 --header-backup-file luks-header-$HOSTNAME-root
cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file luks-header-$HOSTNAME-home
```



# Act3: Packages! Round 2.
We should have a working system by now. Next we need a functional system.

## miscellanous packages
This isn't everything. These are simply those packages for which we don't go into detailed notes, often utilities or standalone applications. Not included are those listed separately below.
```
pacman -S android-udev bitwarden chromium docker docker-compose f3d fail2ban fastfetch fd ffmpeg firefox flatpak fwupd fzf gdu github-cli gocryptfs gparted htop jq krita libreoffice-fresh lsd lshw man-db mpv neovim obsidian obs-studio pacman-contrib peek perl-image-exiftool plocate qbittorrent ripgrep signal-desktop starship syncthing tailscale tealdeer tree unarchiver unzip wget wl-clipboard yadm yazi yt-dlp zip zoxide zsh
```

## ufw firewall
```
pacman -S ufw gufw
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

## backups

### borg backups
Install and set these up.
```
pacman -S borg borgmatic vorta
```

### snapper snapshots
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

## clamav virus/malware detection
```
pacman -S clamav inotify-tools
freshclam
systemctl enable --now clamav-freshclam.service clamav-daemon.service
```
With the daemon running, you can use `clamdscan --multiscan --fdpass <dir>` to run a multi-threaded scan using the parameters in the config file. But we want to automate that.

Put these in `/etc/clamav/clamd.conf` in their appropriate places:
```
VirusEvent /usr/local/bin/clamav-alert.sh
ExcludePath ^/proc/
ExcludePath ^/sys/
ExcludePath ^/dev/
ExcludePath ^/run/
ExcludePath ^/swap/
ExcludePath ^/\.snapshots/
ExcludePath ^/home/\.snapshots/
ExcludePath ^/var/lib/docker/
ExcludePath ^/mnt/
ExcludePath ^/home/[^/]+/\.local/share/Trash/
ExcludePath ^/home/[^/]+/\.local/share/Steam/
```
The aforementioned `clamav-alert.sh` script can be made with something like:
```
sudo tee /usr/local/bin/clamav-alert.sh << 'EOF'
#!/bin/bash
PATH=/usr/bin
ALERT_TITLE="Virus found!"
ALERT="clamav detects: $CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME"

logger -t clamav-alert "$ALERT"

# Push + email via ntfy (ntfy-send reads root-only files, hence sudo)
sudo -n /usr/local/bin/ntfy-send "$ALERT_TITLE" "$ALERT" urgent

# Desktop notification for every logged-in graphical user
for ADDRESS in /run/user/*; do
    USERID=${ADDRESS#/run/user/}
    sudo -n -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" \
        notify-send -u critical -i dialog-warning "$ALERT_TITLE" "$ALERT"
done
EOF
sudo chmod +x /usr/local/bin/clamav-alert.sh
```
In order for the clamav user to process the sudo commands (and only these commands) we need to set up some permissions. Create `/etc/sudoers.d/clamav` if it doesn't exist and add
```
clamav ALL = (ALL) NOPASSWD: SETENV: /usr/bin/notify-send
clamav ALL = (root) NOPASSWD: /usr/local/bin/ntfy-send
```

Let's also setup a script that can watch directories for new files to scan.
```
sudo tee /usr/local/bin/clamscan-watch.sh << 'EOF'
#!/bin/bash
WATCH_DIR="$1"
inotifywait -m -r -q -e close_write -e moved_to --format '%w%f' "$WATCH_DIR" |
while IFS= read -r path; do
    clamdscan --fdpass --no-summary "$path"
done
EOF
sudo chmod +x /usr/local/bin/clamscan-watch.sh
```
We'll make it a user service, and point it to watch our ~/Downloads directory.
```
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/clamscan-watch.service << 'EOF'
[Unit]
Description=ClamAV scan of new files in Downloads

[Service]
ExecStart=/usr/local/bin/clamscan-watch.sh %h/Downloads
Restart=on-failure

[Install]
WantedBy=default.target
EOF
```

Add your user to the clamav group and enable the service.
```
sudo usermod -aG clamav $USER
systemctl --user enable --now clamscan-watch.service
```

Let's also make a service and timer to run scheduled scans of the home directory:
```
# clamscan.service
[Unit]
Description=ClamAV scan of home directory

[Service]
Type=oneshot
ExecStartPre=/usr/bin/clamdscan --ping 60:2
ExecStart=/usr/bin/clamdscan --multiscan --fdpass --infected %h
```
and
```
# clamscan.timer
[Unit]
Description=Weekly ClamAV scan

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=3600

[Install]
WantedBy=timers.target
```
Then enable them with:
```
systemctl --user daemon-reload
systemctl --user enable --now clamscan.timer
```


## printing
```
pacman -S cups
systemctl enable cups
```
Check for drivers for your desired printer. This could be via `gutenprint` and `foomatic-db-gutenprint-ppds` (note: these require running `cups-genppdupdate` after updates) or via a specific driver found on AUR or a manufacturer site. See https://wiki.archlinux.org/title/CUPS#Printer_suuport for ideas. Set up at http://localhost:631


## nfs mounts
If using nfs mounts, like sharing TrueNAS storage across a network.
```
pacman -S nfs-utils
systemctl enable --now rpcbind.service
systemctl enable --now rpcbind.socket
```

## more services and timers
```
systemctl enable --now systemd-oomd 
systemctl enable --now reflector.timer 
systemctl enable --now fstrim.timer
systemctl enable --now paccache.timer 
systemctl enable --now btrfs-scrub@-.timer btrfs-scrub@home.timer
```
Note: For the btrfs (monthly) scrub timer, you can check on it with `journalctl -u btrfs-scrub@-.service` and `btrfs scrub status /`. This is for a mountpoint at `/` by the way. For other mount points, replace the `@-` with the volume name, like @home for /home.

### plocate 
For `plocate`, edit `/etc/updatedb.conf` to  add the following. Chiefly, you don't want to prune bind mounts for btrfs. You probably do want to prune paths used for backups like /.snapshots or /timeshift as well as directories like python checkpoints and cache.
```
PRUNE_BIND_MOUNTS = "no"
PRUNENAMES = "... .ipynb_checkpoints __pycache__ node_modules"
PRUNEPATHS = "... /.snapshots /timeshift /swap /var/lib/docker"
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

## btrfs notification - via ntfy.sh
Let's set up a notification system for btrfs, SMART, and whatever else may need to communicater with the user. Create a https://ntfy.sh topic. Then use said topic and an email address to make
```
echo "https://ntfy.sh/<your-topic>" | sudo tee /etc/ntfy-url
chmod 600 /etc/ntfy-url
echo "you@example.com" | sudo tee /etc/ntfy-email
chmod 600 /etc/ntfy-email
```
Copy an access token from ntfy.sh and paste it in `/etc/ntfy-token` via
```
sudoedit /etc/ntfy-token
sudo chmod 600 /etc/ntfy-token
```
Now create a script for notifications:
```
tee /usr/local/bin/ntfy-send << 'EOF'
#!/bin/bash
# usage: ntfy-send "Title" "Message" [priority]
curl -fsS --max-time 15 \
  -H "Title: $1" -H "Priority: ${3:-high}" \
  -H "Tags: warning" \
  -H "Authorization: Bearer $(cat /etc/ntfy-token)" \
  -H "X-Email: $(cat /etc/ntfy-email)" \
  -d "$2" "$(cat /etc/ntfy-url)"
EOF
chmod +x /usr/local/bin/ntfy-send
```

To have btrfs scrub alert when it finds an issue:
```
tee /usr/local/bin/btrfs-scrub-notify << 'EOF'
#!/bin/bash
# $1 = mountpoint; systemd provides SERVICE_RESULT and EXIT_STATUS to ExecStopPost
[ "$SERVICE_RESULT" = "success" ] && exit 0
status=$(btrfs scrub status "$1" 2>&1 | tail -n 12)
/usr/local/bin/ntfy-send "btrfs scrub problem on $1" "Result: $SERVICE_RESULT (exit $EXIT_STATUS)
$status"
EOF

chmod +x /usr/local/bin/btrfs-scrub-notify
```
Then `systemctl edit btrfs-scrub@.service` and add
```
[Service]
ExecStopPost=/usr/local/bin/btrfs-scrub-notify %f
```

To have daily btrfs stat checks:
```
tee /usr/local/bin/btrfs-stats-check << 'EOF'
#!/bin/bash
for mnt in / /home; do
  out=$(btrfs device stats --check "$mnt" 2>&1) || \
    /usr/local/bin/ntfy-send "btrfs error counters on $mnt" "$out"
done
EOF
chmod +x /usr/local/bin/btrfs-stats-check

tee /etc/systemd/system/btrfs-stats-check.service << 'EOF'
[Unit]
Description=Check btrfs device error counters

[Service]
Type=oneshot
ExecStart=/usr/local/bin/btrfs-stats-check
EOF

tee /etc/systemd/system/btrfs-stats-check.timer << 'EOF'
[Unit]
Description=Daily btrfs device stats check

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl enable --now btrfs-stats-check.timer
```

## SMART drive health notifications - via ntfy.sh
```
pacman -S smartmontools
systemctl enable --now smartd
```
Create a ntfy.sh script and let smartd's config know about it.
```
tee /usr/local/bin/ntfy-smartd << 'EOF'
#!/bin/bash
curl -fsS --max-time 15 \
  -H "Title: SMART Alert" \
  -H "Priority: urgent" \
  -H "Authorization: Bearer $(cat /etc/ntfy-token)" \
  -H "X-Email: $(cat /etc/ntfy-email)" \
  -d "$SMARTD_MESSAGE" \
  "$(cat /etc/ntfy-url)"
EOF

chmod +x /usr/local/bin/ntfy-smartd
```
Now in `/etc/smartd.conf` append the following directive to the end of DEVICESCAN:
```
DEVICESCAN -m root -M exec /usr/local/bin/ntfy-smartd.sh
```
Finally 
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


## AUR
Get AUR acess with `yay` or `paru`.
```
cd $(mktemp -d)
git clone https://aur.archlinux.org/yay-bin
cd yay-bin
makepkg -si PKGBUILD
```

## gaming
```
pacman -S steam gamemode lib32-gamemode mangohud lib32-mangohud
systemctl --user enable --now gamemoded
```
Consider vkbasalt as well, which is a vulkan layer that can be used via `ENABLE_VKBASALT=1 %command%` on steam.
```
yay -S vkbasalt
```

# USER STUFF
## syncthing
```
systemctl --user enable --now syncthing.service
```
## dotfiles
```
yadm clone https://github.com/<user>/dotfiles
yadm pull
```


















# OLD

## packages
See the section on dotfiles for how to import packages from a file.
```
pacman -S thunar thunar-volman tumbler ffmpegthumbnailer
pacman -S github-cli
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

## battery notification (batsignal)
```
systemctl --user enable batsignal --now
```

# user setup
```
My scripts. Notably, this includes a `startup` script to launch startup programs.
```
git clone https://github.com/shervinsahba/scripts src/scripts
```

## btrfs subvolumes
Consider making more subvolumes, especially for directories you do not want to snapshot that are listed under subvolumes you do want to snapshot. Examples:
- /home/$USER/.cache
- /home/$USER/.local/share/Steam/

