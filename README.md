# Migrate-VM-with-temp-disk

Migrating a VM (ie Ds2_V3 to Ds2_V5) is not feasible in some conditions, either from image disk generation or for temporary disk. There is an official doc for that
[How do I migrate from a VM size with local temp disk to a VM size with no local temp disk?](https://docs.microsoft.com/en-us/azure/virtual-machines/azure-vms-no-temp-disk#how-do-i-migrate-from-a-vm-size-with-local-temp-disk-to-a-vm-size-with-no-local-temp-disk---) but no script to do it automatically.

This repo is an attempt to automate the migration

## Behavior

The script must:

- Attach a data disk
- On the VM, move the pagefile, from D (temp disk) to C (OS)
- Reboot the VM
- Change disk letters. D decomes T and the new data disk should become D
- Reboot the VM
- On the VM, move the pagefile from C (OS) to D (data disk)
- Reboot the VM
- Create a snapshot of the OS disk ([doc](https://docs.microsoft.com/en-us/azure/virtual-machines/snapshot-copy-managed-disk?tabs=cli))
- Create a new diskless VM using the snapshot ([doc](https://docs.microsoft.com/en-us/previous-versions/azure/virtual-machines/scripts/virtual-machines-linux-cli-sample-create-vm-from-snapshot))

## Lets do it

Log to Azure

``` cmd
az login
```

Turn on the VM

```cmd
az vm start -g MyResourceGroup -n MyVm
```

Execute remotely a command (can be done with Invoke-Command or VM extension) : 

```cmd
az vm run-command invoke -g MyResourceGroup -n MyVm --command-id RunShellScript --scripts 'New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name PagingFiles -Value "C:\Pagefile.sys 0 0" –Force' --parameters hello world
```
On the VM, the command should move the pagefile.sys. It can be done by changing the regkey and reboot the VM

``` powershell
 New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name PagingFiles -Value "C:\Pagefile.sys 0 0" –Force
```

Restart the VM

``` powershell
az vm restart -g MyResourceGroup -n MyVm
```

Change disk letter

``` powershell
Get-Partition -DriveLetter D| Set-Partition -NewDriveLetter T
```


Restart the VM

``` powershell
az vm restart -g MyResourceGroup -n MyVm
```


Change back the pagefile.sys to D:

```
az vm run-command invoke -g MyResourceGroup -n MyVm --command-id RunShellScript --scripts 'New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name PagingFiles -Value "D:\Pagefile.sys 0 0" –Force' --parameters hello world
```
