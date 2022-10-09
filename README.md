# Migrate-VM-with-temp-disk

Migrating a VM (ie Ds2_V3 to Ds2_V5) is not feasible in some conditions, either from image disk generation or for temporary disk. There is an official doc for that
[How do I migrate from a VM size with local temp disk to a VM size with no local temp disk?](https://docs.microsoft.com/en-us/azure/virtual-machines/azure-vms-no-temp-disk#how-do-i-migrate-from-a-vm-size-with-local-temp-disk-to-a-vm-size-with-no-local-temp-disk---) but no script to do it automatically.

This repo is an attempt to automate the migration

## Behavior

The script must:

- On the VM, move the pagefile, from D (temp disk) to C (OS)
- Reboot the VM
- Create a snapshot of the OS disk ([doc](https://docs.microsoft.com/en-us/azure/virtual-machines/snapshot-copy-managed-disk?tabs=cli))
- Create a new diskless VM using the snapshot ([doc](https://docs.microsoft.com/en-us/previous-versions/azure/virtual-machines/scripts/virtual-machines-linux-cli-sample-create-vm-from-snapshot))
- Retrieve the private IP from the first VM to migrate it to the second one

## Improvments

The script must be adapted depending on your need. if you want to batch a lot of VMs, if they have several disks or constraints like extension but this script is a good start.