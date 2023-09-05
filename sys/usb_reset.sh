#!/bin/bash

# USB drivers
sudo rmmod xhci_pci
sudo rmmod ehci_pci

# uncomment if you have firewire
#rmmod ohci_pci

sudo modprobe xhci_pci
sudo modprobe ehci_pci

# uncomment if you have firewire
#modprobe ohci_pci
