# README
These are my Linux dotfiles. They get my system running the way I like. Below are some notes on my Arch installation as well as some setup and maintenance tips.

**References**
- https://wiki.archlinux.org/title/General_recommendations
- https://wiki.archlinux.org/title/System_maintenance

# Arch Installation
See the files ArchInstall-*.md

# System maintenance
Check for failed services and look for errors.
```
systemctl --failed
journalctl -b --priority=3
```

## clean journal
```
journalctl --rotate --vacuum-size=200M
```
or set a maximum size using a drop-in file with `systemctl edit systemd-journald`, adding the contents
```
[Journal]
SystemMaxUse=250M
```

## update firmware
You can check your BIOS version with `dmidecode`. In general, for updating firmware, the `fwupd` package should be the job. First run `fwupdmgr refresh`. Then survey your system's updateable devices with `fwupdmgr get-devices`. To actually update, run `fwupdmgr update`. Reboot and wait for the updates to finish. NOTE! Some UEFI systems may result in a screwed up bootloader from this process. Check Arch Wiki for details!

## manage pacnew and pacsave files
Check them out with `pacdiff -o`. Consider creating a pacman hook to notify you with `vim /etc/pacman.d/hooks/pacfiles.hook` and
```
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Checking for .pacnew and .pacsave files...
When = PostTransaction
Exec = /usr/bin/bash -c 'pacfiles=$(pacdiff -o); if [[ -n "$pacfiles" ]]; then echo -e ":: $(echo $pacfiles | wc -w) files found. See pacdiff -o."; fi'
```

## manage orphans
Check them out with `pacman -Qtdq`. Consider creating a pacman hook to notify you with `vim /etc/pacman.d/hooks/orphans.hook` and
```
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Checking for orphans...
When = PostTransaction
Exec = /usr/bin/bash -c 'orphans=$(pacman -Qtdq); if [[ -n "$orphans" ]]; then echo -e ":: $(echo $orphans | wc -w) orphan packages found. See pacman -Qtdq."; fi'
```


# More setup

## Github authentication
```
gh auth login
```

## /etc/fstab
Mount anything you need to mount. Refer to `blkid` and `lsblk -f`. 
- For removeable or optional media, add options `nofail,x-systemd.device-timeout=100ms` to prevent a missing device error from locking the system on startup.
- To get non-root filesystem devices to show up in thunar, add the option `x-gvfs-show`.

For mounting filesystems from other devices via sshfs, consider adding something like the following to your fstab. Replace <username> with the desired user, and doublecheck that the uid and gid are correct with `id -u` and `id -g`.
```
<username>@<host>:/path/to/target /path/to/mount  fuse.sshfs  noauto,x-systemd.automount,_netdev,user,idmap=user,follow_symlinks,identityfile=/home/<username>/.ssh/id_rsa,allow_other,default_permissions,uid=1000,gid=1000 0 0
```
You can then mount the directory rapidly with `mount /path/to/mount/`.

## bluetooth, automatic startup
If bluetooth doesn't start up on its own, edit `/etc/bluetooth/main.conf` and set `AutoEnable=true`.

## mute PC speaker bell
To globally disable the speaker bell, try the following. Otherwise see the [wiki](https://wiki.archlinux.org/title/PC_speaker).
```
echo -e "blacklist pcspkr\nblacklist snd_pcsp" > /etc/modprobe.d/nobell.conf
```

## pacman.conf (multilib, parallel downloads)
Enable the multilib repo in `/etc/pacman/conf` if you want packages from there (e.g. steam). Also enable parallel downloads and add pacman candy :)
```
sed -i 's/#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf ;
sed -i '/ParallelDownloads/s/^#//g' /etc/pacman.conf ;
sed -i 's/#Color/Color\nILoveCandy/g' /etc/pacman.conf ;
```
This is also where to list packages to be ignored. This may be useful to fix packages or for AUR packages that involve manual builds like matlab.
```
IgnorePkg = matlab foundryvtt
```

## kernels
Install a backup kernel like `linux-lts`
```
pacman -S linux-lts linux-lts-headers 
pacman -S nvidia-lts
```

## firewall
Use `ufw` and its GUI `gufw`. Activate with `systemctl enable ufw --now`. Then run `gufw` as a superuser and toggle on. It should persist after reboot. By default ufw denies incoming for home/office profiles. Add any ufw rules you want (i.e. `ufw allow <whatever>`) or use the GUI log to append rules. VPNs may need some config changes in ufw - see the ufw arch wiki. Notably, running `ufw app list` shows preset profiles you may want to use. For example,
```
ufw allow syncthing
```
For tailscale, consider these rules
```
ufw allow in on tailscale0
ufw allow 41641/udp
```
<!-- TODO: Are these needed?
Added these rules after `# End required lines` in `/etc/ufw/before.rules`:
`-A ufw-before-forward -i wg-mullvad -j ACCEPT`
`-A ufw-before-forward -o wg-mullvad -j ACCEPT` -->


## SSH
### Host-side:
1.) `systemctl enable --now sshd`
2.) Set `PasswordAuthentication no` on host device in `/etc/ssh/sshd_config`.
3.) `ufw allow ssh` 
4.) Add ssh jail to fail2ban and enable the service.
```
echo -e "[sshd]\nenabled = true\nmaxretry = 3" > /etc/fail2ban/jail.local
systemctl enable --now fail2ban
```
### Client-side:
1.) Run `ssh-keygen` on new local device. Choose a passphrase and save for later.
2.) Install public key on remote device with `ssh-copy-id -p <port> <username>@<remotehost>`. Remember, you'll need to briefly reconfigure `/etc/ssh/sshd_config` on the host device to accept password authentication. Provide the username and password of remote user.
3.) Login via `ssh -p <username>:<remotehost>` and provide passphrase.
4.) Disable password authentication on host device in `/etc/ssh/sshd_config`.


## antivirus (clamav)
Install clamav to use `clamscan` on files. First run `freshclam` to update database, even if the systemd service is setup later. Setup checks to update virus database automatically and edit `/etc/clamav/freshclam.conf` to change the frequency from 12 a day to something else if desired.
```
systemctl enable --now clamav-freshclam.service
```
When running the daemon, use `clamdscan` instead to scan using the config file parameters. You can also use the daemonized version to run with multiple threads with
```
clamdscan --multiscan --fdpass /dir/to/scan
```

## VPNs (mullvad, tailscale)
Caution: VPN setup is straightforward if using only one. But if you're combining VPNs for simultaneous (or even toggled) use, it can get tricky. Here is information about `tailscale` and `mullvad` as well as a script with guidance on how to use them together using `nftables`.

### tailscale
```
systemctl enable tailscaled --now
sudo tailscale up
```
Follow the authentication prompt to login to Tailscale on the browser. After authenticating, consider setting the machine settings to "No expiry" so the key doesn't need to be reauthenticated after the default 180 days. You may need to open firewall ports. See the section on `ufw`.

### mullvad
To setup the service, you need to login with your account number:
```
mullvad account login
```
To have a persistant VPN,
```
systemctl enable --now mullvad-dameon
```
Setup [DNS over Https with the instructions here](https://mullvad.net/en/help/dns-over-https-and-dns-over-tls/) on your system. If that's not an option, consider Mullvad's DNS servers, which can be set with options like:
```
mullvad dns set default --block-ads --block-malware --block-trackers
```
### mullvad AND tailscale
If you want to use Mullvad contemporaneously with Tailscale, see this [mullvad-tailscale](https://github.com/r3nor/mullvad-tailscale) script. I have a private fork that I maintain with my devices on a separate branch.


## backups and system recovery
### netboot
Download the [UEFI netboot image](https://archlinux.org/releng/netboot/). It's unnecessary to update this by the way, since it pulls updates from the net. Now move the file over to the EFI partition, and create a boot entry.
```
mkdir /efi/EFI/arch_netboot
mv ~/Downloads/ipxe-arch.*.efi /efi/EFI/arch_netboot/arch_netboot.efi
efibootmgr --create --disk /dev/<EFI partition> --part 1 --loader /EFI/arch_netboot/arch_netboot.efi --label "Arch Linux Netboot" --verbose
```

### borg
For borgmatic, consider optional dependency `pacman -S --asdeps python-llfuse`.

If using borgbase or online repo, create a dedicated ssh key for automation. Go online and create a new repo. Add this ssh key (and any others) to the repo. On the machine, store the borg repo passphrase for automated backups to access with `secret-tool`,
```
secret-tool store --label='borg' borg-repo <repo-name>
```
Use `borgmatic` and its config to initialize and process the borg backup. 

Before you can use borgmatic, you need to initialize a repository.
```
borg init -e repokey-blake2 <path/to/repo>
borgmatic create
```
Or with borgmatic, a config file, and a provided encryption pass, you can try
```
borgmatic rcreate --encryption repokey-blake2
```
After creating the repo, copy the repokey (it is stored within the repo, but do it in case of an issue).
```
borg key export <path/to/repo>
```
Setup a borgmatic.service and borgmatic.timer to automate. [See the docs](https://torsion.org/borgmatic/docs/how-to/set-up-backups/#systemd) for example scripts, or see if you have a template saved as a dotfile.  If running the timer as a user, you may need to disable the security features from the template on torsion.org and change the last line to something simple like ExecStart=borgmatic. Copy files to `~/.config/systemd/user` and run 
```
systemctl --user enable borgmatic.timer --now
```

### snapper
Create snapper configs with
```
snapper -c <config name> create-config /path/to/subvolume
```
Note: You may need to `umount /.snapshots && rmdir /.snapshots` before running the above. This may  also create a superfluous subvolume `.snapshots` that you can delete with `btrfs sub del /.snapshots`.

Consider editting each snapper config in `/etc/snapper/configs/<config>` to have TIMELINE parameters that differ from the default that keeps 10 hourly, 10 daily, 0 weekly, 10 monthly, and 10 yearly snapshots. Consider something like 5,7,4,3,1.

Setup hourly snapshot timers and cleanup. Note that if you have an active cron daemon, like cronie, then snapper will automatically run through it. This may lead to double the snapshots if you also use systemd!
```
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer
```
To change the timer from hourly to every 4 hours, run
```
sudo systemctl edit --full snapper-timeline.timer
```
and make these changes
```
[Timer]
OnCalendar=*-*-* 00/4:00:00
RandomizedDelaySec=120
```


## file browsers (ranger, thunar)
### ranger
Get some [Ranger plugins](https://github.com/ranger/ranger/wiki/Plugins).
```
mkdir -p ~/.config/ranger/plugins
cd ~/.config/ranger/plugins
git clone https://github.com/alexanderjeurissen/ranger_devicons
git clone https://github.com/SL-RU/ranger_udisk_menu
git clone https://github.com/ask1234560/ranger-zjumper.git
```
Click through the links and add their instructions to ranger's config files if your dotfiles don't already contain said instructions.

### thunar
A great browser with a GUI. There are several plugins worth looking at, but I particularly think `gvfs` with `thunar-volman` is a must to mount removeable devices simply. Mounting your phone or mobile device is typically done with the MTP protocol, which would need `gvfs-mtp` as well. For thumbnails of pictures and video, you need `tumbler` and `ffmpegthumbnailer` respectively. Note that there is `raw-thumbnailer` if RAW files are in your portfolio as well.

### yazi
Looks promising.


## web browser (firefox)
You can copy over the `.mozilla` profiles folder from a previous installation to clone your setup. Reauthenticate (log off and back on) Firefox account on both devices so sync is properly setup. Rename device in Firefox sync settings.

If Firefox CSS stylesheets are not in place already done, symbolic link `userChrome.css` and `userContent.css` by copying over `.config/firefox/chrome/chrome` to the `.mozilla/<profile>` directory. Enable css in `about:config` by toggling `toolkit.legacyUserProfileCustomization.stylesheets = true`.

If using css to auto-collapse Sidebery, set the add-on's prefix/preface symbol to the one chosen in userChrome.css (e.g. ⧌).

## HiDPI Issues 
Refer to https://wiki.archlinux.org/title/HiDPI.
### firefox
Enter `about:config` and set `ui.textScaleFactor` between 100 and 150. Possibly change the default zoom under Firefox settings as well.


## sync and cloud (syncthing)
For a user service that runs on login:
```
systemctl --user enable --now syncthing
```
For a system-wide server, start the service inserting the actual syncthing username as seen here:
```
systemctl enable --now syncthing@<username>.service
```
Consider installing `syncthingtray` from the AUR to get a tray icon with info. Check the AUR to install the dependencies first! When installed, right-click the tray icon and try to auto-detect the local instance's settings. Turn on all notifications, disable Web View, and set Qt settings (importing a palette if you have one. See dotfiles.)


## printing (cups)
Install `cups` and `nss-mdns` for Avahi local hostname resolution, then
```
systemctl enable --now cups
systemctl enable --now avahi-daemon
```
Edit `/etc/nsswitch.conf` and put `mdns_minimal [NOTFOUND=return]` before `resolve` under `hosts`. Then `systemctl restart cups`.


## nvidia
[See the wiki.](https://wiki.archlinux.org/title/NVIDIA#Installation)
Something like these will probably be what you want.
```
pacman -S nvidia nvidia-settings nvidia-utils lib32-nvidia-utils lib32-opencl-nvidia opencl-nvidia libvdpau libxnvctrl vulkan-icd-loader lib32-vulkan-icd-loader
```
Add a pacman hook to make sure initramfs is rebuilt after a nvidia update. Create `/etc/pacman.d/hooks/nvidia.hook` with
```
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia
Target=linux
# Change the linux part above if a different kernel is used

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
```

## gaming (steam, lutris)
### steam
Can't find it? Steam requires the multilib repo. See the section on multilib in this doc. When installing, be mindful of selecting the appropriate graphics package.

### lutris
Lutris has WINE dependencies. #TODO - do I need to install these or can I just install `lutris`? Check the Lutris github, but the most recent deps are given by
```
sudo pacman -S --needed wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls \
mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error \
lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo \
sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libgcrypt libgcrypt lib32-libxinerama \
ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 \
lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader
```

### gamemode
For a nice optimized gaming on Linux reference, see [this guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1787799592). Otherwise, continue reading.

Install `gamemode` and `lib32-gamemode`. Then activate the daemon with

```
systemctl --user enable gamemoded && systemctl --user start gamemoded
```
Now you can use `gamemoderun <command>` from command line or `gamemoderun %command%` as a Steam launch option. You may also want to run `gamemoded -t` on a new system to see if all aspects of gamemode are operational.

### libstrangle
`libstrangle` lets you control framerates and vsync settings. It may be worth setting up, too.

### vkbasalt and reshade
The `vkbasalt` and `reshade-shaders-git` packages can be used to sharpen textures (e.g. Contrast Adaptive Sharpening) and alter shaders to enhance graphics. Use with `ENABLE_VKBASALT=1 <command>` or `ENABLE_VKBASALT=1 %command%` in Steam. The environment parameter can be entered before `gamemoderun` to use them together.

### mangohud
Mangohud can be used to track in-game performance. Launch with `mangohud <command>` or `mangohud %command%` with Steam. When used with gamemode, run `gamemoderun mangohud <command>`.


## thinkorswim
Get the [desktop installer from the TDAmeritrade website](https://www.tdameritrade.com/tools-and-platforms/thinkorswim/desktop.html). For the Java dependency, `pacman -S jre11-openjdk` works fine.

## matlab
Use the [AUR package](https://aur.archlinux.org/packages/matlab) but note that MATLAB requires a manual package installation for EULA reasons. Refer to the README file in the package's git repository for installation instructions. You may need to add the libcrypt.so.1 library as well as remove MATLAB's included freetype library so that you rely on your system libraries: 
```
pacman -S --asdeps libxcrypt-compat
rm ./matlab/bin/glnxa64/libfreetype.so.6*
```
In the `PKGBUILD` set your desired modules in the product array. For example:
```
_products=(
  "MATLAB"
  "Simulink"
  "Computer_Vision_Toolbox"
  "Curve_Fitting_Toolbox"
  "Deep_Learning_Toolbox"
  "Deep_Learning_HDL_Toolbox"
  "Global_Optimization_Toolbox"
  "Image_Processing_Toolbox"
  "Optimization_Toolbox"
  "Partial_Differential_Equation_Toolbox"
  "Reinforcement_Learning_Toolbox"
  "Signal_Processing_Toolbox"
  "Statistics_and_Machine_Learning_Toolbox"
  "Symbolic_Math_Toolbox"
  "Wavelet_Toolbox"
)
```
You'll need the matlab-meta package to handle dependencies. After downloading it and following the steps in the README, you can build the matlab package.
```
yay -S --asdeps matlab-meta
makepkg -sri
```

## Python / Conda / Mamba
Install [miniforge](https://mamba.readthedocs.io), the newest iteration of mambaforge. You can also use [miniconda](https://docs.conda.io/en/latest/miniconda.html#installing), but mamba is a much nicer package manager and comes coupled with conda. Here is some basic setup, as well as a reminder to get running with jupyter notebooks and a machine learning environment:

Deactivate auto-base.
```
conda config --set auto_activate_base false
```
Prioritize conda-forge (this is set by default on miniforge).
```
conda config --add channel conda-forge
```
In base, setup Jupyter stuff.
```
mamba install jupyterlab nb_conda_kernels ipykernel ipywidgets
```
Create a ML environment 
```
mamba create -n ml numpy scipy matplotlib pandas scikit-learn seaborn ipykernel ipywidgets hdf5 tqdm
```
Add torch using the command off [PyTorch's site](https://pytorch.org/).

Alternatively, if you have a yaml file to generate a conda environment, you can update or create your environment using
```
mamba env create -f <env>.yml
```




# Old ideas 

## prevent systemd from clearing boot messages on tty1
Create a drop-in file to prevent systemd getty service from clearing boot messages.
```
mkdir -p /etc/systemd/system/getty@tty1.service.d/
echo '[Service]
TTYVTDisallocate=no' > /etc/systemd/system/getty@tty1.service.d/noclear.conf
```

## Usenet
You need at least three things to use usenet: a usenet provider (e.g. Frugal), an NZB indexer (e.g. Geek), and a usenet client (e.g. NZBGet). Then supplementary programs like sonarr can automate the usenet client's processes.

### provider and indexer
These are typically subscription services. See the wiki on reddit.com/r/usenet for examples. I have used subscriptions for frugalusenet.com and nzbgeek.info for my provider and indexer respectively.

### usenet client (nzbget)
You'll need a usenet client. I use `nzbget`. As a preliminary step, I like to create a system user with no login shell access to run the service:
```
useradd -r -s /usr/bin/nologin -U nzbget
mkdir /var/lib/nzbget
chown -R nzbget:nzbget /var/lib/nzbget
usermod -d /var/lib/nzbget -m nzbget
```
And add your own user to the nzbget group.
```
useradd -a -G nzbget <username>
```
Back to nzbget config, first copy its config to edit it.
```
cp /usr/share/nzbget/nzbget.conf /var/lib/nzbget/.nzbget
chown -R nzbget:nzbget /var/lib/nzbget
```
Then edit it with
```
MainDir=/home/<username>/Downloads/NZBGet
DestDir=${MainDir}/complete
InterDir=${MainDir}/intermediate
ScriptDir=/usr/share/nzbget/scripts
LockFile=/var/lib/nzbget/nzbget.lock
DaemonUsername=nzbget
UMask=0002
```
Create a download directory and set permissions.
```
mkdir /home/<username>/Downloads/NZBGet
chown -R nzbget:nzbget /home/<username>/Downloads/NZBGet
chmod 775 /home/<username/Downloads/NZBGet
```
Note that you'll need at least 711 permissions on `/home/<username/` for the nzbget user to traverse the directory You can now launch the daemon.
```
sudo -u nzbget /usr/bin/nzbget -c /var/lib/nzbget/.nzbget -D
```
You can now log into the nzbget web UI at `localhost:6789`. Make sure the settings look alright (update the paths and password if needed). Then add a category for sonarr. Add your usenet provider servers under settings->news-servers.

Consider getting the `nzbget-systemd` AUR package to setup the daemon with `systemctl enable --now nzbget`.

### sonarr, lidarr, radarr
Reference: https://wiki.servarr.com/

Install `sonarr` and start the service with
```
systemctl enable --now sonarr
```
You can log into the web UI at `localhost:8989`. Note that sonarr is probably running as its own user with group sonarr. Add a root folder (under settings->media management), you'll need a folder with appropriate permissions. Here is one way to handle that:
```
mkdir /path/to/sonarr_root
chown -R sonarr:sonarr /path/to/sonarr_root
```
Adding your own user and the nzbget user to the the sonarr group and giving priviledges to access the directory is a good move too. Note that your groups may not load until a restart, unless you force them to reload in the shell with something like `su <user>` (check your groups with `id`).
```
usermod -a -G sonarr <user>
usermod -a -G sonarr nzbget
chmod 775 /path/to/sonarr_root
```
Adding sonarr to nzbget's group may be needed to access the nzbget download directory too.
```
usermod -a -G nzbget sonarr
```
After finishing adding the root folder, set up the indexer under settings->indexer (e.g. NZBGeek) with your subscribed API key. Then establish the client under settings->download clients, adding NZBGet as a client using your nzbget user and control password along with the sonarr category you just set.

Repeat the process for `lidarr`, `radarr`, etc. These are served on `localhost:XXXX` ports `8686` and `7878` respectively.
