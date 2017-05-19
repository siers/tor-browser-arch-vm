set -eux

exec &> >(tee /dev/tty1)

packages() {
    pacman -S --noconfirm xorg xorg-xinit openbox rxvt-unicode \
        git iptables tor

    sed -i 's/#ControlPort/ControlPort/' /etc/tor/torrc

    systemctl enable tor
    systemctl start tor
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

firewall-reset() {
    iptables -F
    iptables -X
    iptables -F -t nat
    iptables -X -t nat

    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
}

firewall() {
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT

    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

    iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    # tor-browser starts its own tor daemon, but because the process
    # doesn't have the tor uid, it gets proxied
    iptables -t nat -A OUTPUT -p tcp --dport 9150 -j REDIRECT --to-port 9050
    iptables -t nat -A OUTPUT -p tcp --dport 9151 -j REDIRECT --to-port 9051
    iptables -A OUTPUT -o lo -p tcp --dport 9050 -j ACCEPT
    iptables -A OUTPUT -o lo -p tcp --dport 9051 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner 43 -j ACCEPT

    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP

    # getent group tor = tor:x:43

    iptables-save > /etc/iptables/iptables.rules

    systemctl enable iptables
    systemctl start iptables
}

# setup

firewall-reset

[ -e /root/syu ] || (pacman -Syu --noconfirm && touch /root/syu)
pacman -Q openbox || packages
xlogin
tor

firewall

# init

install -o vagrant -g vagrant \
    <(echo 'cd tor-browser_en-US; ./start-tor-browser.desktop; xrandr -s 1280x768; exec openbox-session') \
    ~vagrant/.xinitrc

systemctl enable xlogin@vagrant
systemctl start xlogin@vagrant
