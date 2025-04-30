
# show linux bridge

bridge link

nmcli connection show --active

# maybe need to:
nmcli connection up br0
nmcli connection up br0-slave