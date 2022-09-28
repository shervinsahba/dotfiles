# README
These are my Linux dotfiles. They get my system running the way I like.

References
- https://wiki.archlinux.org/title/General_recommendations

## update firmware
After installing the `fwupd` package, run `sudo fwupdmgr refresh`. Then survey your system's updateable devices with `fwupdmgr get-devices`. To actually update, run `fwupdmgr update`. Reboot and wait for the updates to finish. NOTE! Some UEFI systems may result in a screwed up bootloader from this process. Check Arch Wiki for details!


## /etc/fstab
Mount anything you need to mount. Refer to `blkid` and `lsblk -f`. 
- For removeable or optional media, add options `nofail,x-systemd.device-timeout=100ms` to prevent a missing device error from locking the system on startup.
- To get non-root filesystem devices to show up in thunar, add the option `x-gvfs-show`.


## mute PC speaker bell
Edit `/etc/inputrc` and uncomment or append `set bell-style none`. Also maybe
```
echo blacklist pcspkr > /etc/modprobe.d/nobell.conf
```

## multilib
Enable the multilib repo in `/etc/pacman/conf` if you want packages from there (e.g. steam).
```sed -i 's/#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf```


## kernels
Install packages for other kernels besides `linux` like `linux-zen` or `linux-lts` if desired. You may want to edit `/etc/default/grub` to set `GRUB_DEFAULT=saved`, `GRUB_SAVEDEFAULT=true`. Then `sudo grub-mkconfig -o /boot/grub/grub.cfg` and `reboot`.


## systemd timers
Setup a system timer with `systemctl enable <timer> --now`. For user-scoped timers, add the `--user` flag. Here are some timers to use, some of which are discussed in their own sections elsewhere in this document:
- `fstrim.timer`
- `paccache.timer`
- `plocate-updatedb.timer`
- `reflector.timer`
- `man-db.timer` (should be active if `man-db` is installed.)
- `btrfs-scrub@-.timer` (for mountpoint at /. Repeat for other mounts)


## power management
systemd handles power management pretty well. For a laptop, consider these changes. Edit `/etc/systemd/logind.conf` and 
`/etc/systemd/sleep.conf` to respectively set
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
HibernateDelaySec=30min
```
Note that without a DE, the system may not be able to handle the IdleAction appropriately. So consider this before setting the above.

For a desktop that should keep its uptime going, consider
```
[Login]
HandlePowerKey=ignore
HandlePowerKeyLongpress=poweroff
```

### tlp
For advanced power managment, install `tlp`. Then run
```
systemctl enable tlp.service
systemctl mask systemd-rfkill.service
systemctl mask systemd-rfkill.socket
```
Consider deactivating the USB_AUTOSUSPEND by setting it to 0 in `/etc/tlp.conf`. Run `tlp-stat` and read through to see if any warnings or recommendations pop up. The AUR package `tlpui` is a nice GUI to set options too. Optionally, if you want to control radio devices (wifi, bluetooth, etc...) on certain triggers, install `tlp-rdw` and make sure `NetworkManager-dispatcher.service` is enabled.


### battery notifications
Use `batsignal` to send out notifications for battery status. Turn on the daemon with
`systemctl --user enable batsignal.service --now`
and (customize a config file)[https://github.com/electrickite/batsignal] if you want.


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
4.) Create or edit `/etc/fail2ban/jail.local` and add ssh jail:
```
[sshd]
enabled = true
maxretry = 3
```
3.) `systemctl enable --now fail2ban`


### Client-side:
1.) Run `ssh-keygen` on new local device. Choose a passphrase and save for later.
2.) Install public key on remote device with `ssh-copy-id -p <port> <username>@<remotehost>`. Remember, you'll need to briefly reconfigure `/etc/ssh/sshd_config` on the host device to accept password authentication. Provide the username and password of remote user.
3.) Login via `ssh -p <username>:<remotehost>` and provide passphrase.
4.) Disable password authentication on host device in `/etc/ssh/sshd_config`.


## git and github
Use Type the following and follow through to the browser prompts. Type the following and follow through to the browser prompts.
```
gh auth login
```


## VPNs (mullvad, tailscale)

Caution: VPN setup is straightforward if using only one. But if you're combining VPNs for simultaneous (or even toggled) use, it can get tricky. Here is information about `tailscale` and `mullvad` as well as a script with guidance on how to use them together using `nftables`.

### tailscale
```
systemctl enable tailscaled
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

### borg backups
For borgmatic, consider optional dependency `pacman -S --asdeps python-llfuse`.

If using borgbase or online repo, create a dedicated ssh key for automation. Go online and create a new repo. Add this ssh key (and any others) to the repo. On the machine, store the borg repo passphrase for automated backups to access with `secret-tool`,
```
secret-tool store --label='borg' borg-repo <repo-name>
```
Use `borgmatic` and its config to initialize and process the borg backup. For the first run, use `borgmatic create` and not just `borgmatic` to specify that there is nothing to prune:
```
borgmatic init -e repokey-blake2
borgmatic create
```
After creating the repo, copy the repokey (it is stored within the repo, but do it in case of an issue).
```
borg key export <path/to/borg/repo>
```

Setup a borgmatic.service and borgmatic.timer to automate. [See the docs](https://torsion.org/borgmatic/docs/how-to/set-up-backups/#systemd) for example scripts, or see if you have a template saved as a dotfile.  If running the timer as a user, you may need to disable the security features from the template on torsion.org and change the last line to something simple like ExecStart=borgmatic. Copy files to `~/.config/systemd/user` and run 
```
systemctl --user enable borgmatic.timer --now
```


### snapper backup
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
While ranger is my favorite file browser to date, thunar is favorite GUI file browser and a great backup. There are several plugins worth looking at, but I particularly think `gvfs` with `thunar-volman` is a must to mount removeable devices simply. Mounting your phone or mobile device is typically done with the MTP protocol, which would need `gvfs-mtp` as well. For thumbnails of pictures and video, you need `tumbler` and `ffmpegthumbnailer` respectively. Note that there is `raw-thumbnailer` if RAW files are in your portfolio as well.


## music (mpd)
```
systemctl enable --user mpd.service --now
systemctl enable --user mpd-notification.service --now
```
Now edit the service to set the Music directory for album art:
```
systemctl --user edit --full mpd-notification.service
```
making this change to the ExecStart line
```
ExecStart=/usr/bin/mpd-notification --music-dir %h/Music
```


## firefox
You can copy over the `.mozilla` profiles folder from a previous installation to clone your setup. Reauthenticate (log off and back on) Firefox account on both devices so sync is properly setup. Rename device in Firefox sync settings.

If Firefox CSS stylesheets are not in place already done, symbolic link `userChrome.css` and `userContent.css` by copying over `.config/firefox/chrome/chrome` to the `.mozilla/<profile>` directory. Enable css in `about:config` by toggling `toolkit.legacyUserProfileCustomization.stylesheets = true`.


## sync, cloud
### syncthing
For a user service that runs on login:
```
systemctl --user enable --now syncthing
```
For a system-wide server, start the service inserting the actual syncthing username as seen here:
```
systemctl enable --now syncthing@<username>.service
```

Consider installing `syncthingtray` from the AUR to get a very nice tray icon for monitoring your syncs. Check the AUR to install the dependencies first! You should be able to install dependencies with
```
yay -S --asdeps c++utilities qtutilities qtforkawesome
yay -S syncthingtray
```
Then right-click the tray icon and try to auto-detect the local instance's settings. Turn on all notifications, disable Web View, and set Qt settings (importing a palette if you have one. See dotfiles.)


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


## thinkorswim
Get the [desktop installer from the TDAmeritrade website](https://www.tdameritrade.com/tools-and-platforms/thinkorswim/desktop.html). For the Java dependency, `pacman -S jre11-openjdk` works fine.


## matlab
Consider using the [AUR package](https://aur.archlinux.org/packages/matlab), but note that MATLAB requires a manual package installation for EULA reasons. Refer to the README file in the package's git repository for installation instructions.

You may need to add the libcrypt.so.1 library as well as remove MATLAB's included freetype library so that you rely on your system libraries: 
```
pacman -S --asdeps libxcrypt-compat
rm ./matlab/bin/glnxa64/libfreetype.so.6*
```
In the `PKGBUILD` set your desired modules in the product array. I chose these:
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

You'll need the matlab-meta package to handle dependencies. After downloading it and following the steps in the README, you can build the matlab package.
```
yay -S --asdeps matlab-meta
makepkg -sri
```


## Python / Conda / Mamba
First, install [mambaforge](https://mamba.readthedocs.io/en/latest/installation.html). You can also use [miniconda](https://docs.conda.io/en/latest/miniconda.html#installing), but mamba is a much nicer package manager and comes coupled with conda.

Deactivate auto-base.
```
conda config --set auto_activate_base false
```
Prioritize conda-forge.
```
conda config --add channel conda-forge
```
In base, setup Jupyter stuff:
```
mamba install jupyterlab nb_conda_kernels ipykernel ipywidgets
```
Create a ML environment 
```
mamba create -n ml numpy scipy matplotlib pandas scikit-learn seaborn ipykernel ipywidgets hdf5 tqdm
```
Add torch using the command off [PyTorch's site](https://pytorch.org/). Just replace the `conda` part of the command with `mamba`.

Alternatively, if you have a yaml file to generate a conda environment, you can update or create your environment using one of the below:
```
mamba env update -f <env>.yml --prune
```
or
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

