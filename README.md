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

## Lets do it

Log to Azure

``` cmd
az login
```

Turn on the VM

```cmd
az vm start -g MyResourceGroup -n MyVm
```

Execute remotely a command (can be done with Invoke-Command (powershell) or VM extension) : 

On the VM, the command should move the pagefile.sys. It can be done by changing the regkey 

```cmd
az vm run-command invoke -g MyResourceGroup -n MyVm --command-id RunShellScript --scripts 'New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name PagingFiles -Value "C:\Pagefile.sys 0 0" –Force' --parameters hello world
```


Restart the VM

``` powershell
az vm restart -g MyResourceGroup -n MyVm
```

Create snapshot from the VM
```
osDiskId=$(az vm show \
   -g myResourceGroup \
   -n myVM \
   --query "storageProfile.osDisk.managedDisk.id" \
   -o tsv)
az snapshot create \
    -g myResourceGroup \
	--source "$osDiskId" \
	--name osDisk-backup
```

Create a diskless VM from snapshot

```
#Get the snapshot Id 
snapshotId=$(az snapshot show --name $snapshotName --resource-group $resourceGroupName --query [id] -o tsv)

#Create a new Managed Disks using the snapshot Id
az disk create --resource-group $resourceGroupName --name $osDiskName --sku $storageType --size-gb $diskSize --source $snapshotId 

#Create VM by attaching created managed disks as OS
az vm create --name $virtualMachineName --resource-group $resourceGroupName --attach-os-disk $osDiskName --os-type $osType
```


Transfer the private IP
```
# Get the IP and store it

# set a temp private ip on the old VM

az network nic ip-config update \
    --name ipconfigmyVM \
    --resource-group myResourceGroup \
    --nic-name myVMVMNic \
    --private-ip-address 10.0.0.99

# set the IP to the second VM
az network nic ip-config update \
    --name ipconfigmyVM2 \
    --resource-group myResourceGroup \
    --nic-name myVMVMNic \
    --private-ip-address 10.0.0.4

```
