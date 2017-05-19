set -eux

exec &> >(tee /dev/tty1)

packages() {
    pacman -S --noconfirm xorg xorg-xinit openbox git rxvt-unicode
}

xlogin() {
    pacman -Qs xlogin | grep xlogin -q || sudo -iu vagrant <<-VAGRANT
        [ -e xlogin-git ] || git clone https://aur.archlinux.org/xlogin-git.git
        cd xlogin-git
        makepkg -si --noconfirm
	VAGRANT

    systemctl set-default -f graphical.target
}

tor() {
    file="tor-browser-linux64-6.5.2_en-US.tar.xz"

    sudo -iu vagrant <<-VAGRANT
        [ -e "$file" ] && exit

        wget "https://www.torproject.org/dist/torbrowser/6.5.2/$file"
        tar -xJf "$file"
	VAGRANT
}

# setup

[ -e /root/syu ] || (pacman -Syu --noconfirm && touch /root/syu)
pacman -Q openbox || packages
xlogin
tor

# init

install -o vagrant -g vagrant \
    <(echo 'cd tor-browser_en-US; ./start-tor-browser.desktop; xrandr -s 1280x768; exec openbox-session') \
    ~vagrant/.xinitrc

systemctl enable xlogin@vagrant
systemctl start xlogin@vagrant
