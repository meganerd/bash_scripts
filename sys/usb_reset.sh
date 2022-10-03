#!/bin/bash

# USB drivers
rmmod xhci_pci
rmmod ehci_pci

# uncomment if you have firewire
#rmmod ohci_pci

modprobe xhci_pci
modprobe ehci_pci

# uncomment if you have firewire
#modprobe ohci_pci
