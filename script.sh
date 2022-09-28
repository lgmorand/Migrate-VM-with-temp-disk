#
# This script is meant to migrate an Azure VM V3 to a V4 or V5 version
#
# Author: Louis-Guillaume MORAND
# Github: https://github.com/lgmorand/Migrate-VM-with-temp-disk 
#
# Behavior:
# The script must: 
# STEP 1: On the VM, move the pagefile, from D (temp disk) to C (OS)
# Step 2: Reboot the VM
# Step 3: Create a snapshot of the OS disk ([doc](https://docs.microsoft.com/en-us/azure/virtual-machines/snapshot-copy-managed-disk?tabs=cli))
# Step 4: Create a new diskless VM using the snapshot ([doc](https://docs.microsoft.com/en-us/previous-versions/azure/virtual-machines/scripts/virtual-machines-linux-cli-sample-create-vm-from-snapshot))
# Step 5: Retrieve the private IP from the first VM to migrate it to the second one


###  VARIABLES ###

# Name of the RG containing the VM
export RESOURCE_GROUP=rg-test

# Name of the old VM
export VM_NAME=myVM

# Name of the new VM
export NEW_VM_NAME=myNewVM

# Name of the OS disk backup (optional)
export BACKUP_NAME=osDisk-backup

# Name of the new disk name
export OSDISK_NAME=osDisk_MyVm


# STEP 1: On the VM, move the pagefile, from D (temp disk) to C (OS)

az login

# the VM must be started to execute the remote command
az vm start -g $RESOURCE_GROUP -n $VM_NAME

# move the pagefile from D to C
az vm run-command invoke -g $RESOURCE_GROUP -n $VM_NAME --command-id RunShellScript --scripts 'New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name PagingFiles -Value "C:\Pagefile.sys 0 0" –Force'


# STEP 2: restart the VM

# restart the VM
az vm restart -g $RESOURCE_GROUP -n $VM_NAME

# STEP 3: Create a snapshot of the OS disk

OSDISK_ID=$(az vm show \
   -g $RESOURCE_GROUP \
   -n $VM_NAME \
   --query "storageProfile.osDisk.managedDisk.id" \
   -o tsv)
OSDISK_SIZE=$(az vm show \
   -g $RESOURCE_GROUP \
   -n $VM_NAME \
   --query "storageProfile.osDisk.diskSizeGb" \
   -o tsv)
OSDISK_SKU=$(az vm show \
   -g $RESOURCE_GROUP \
   -n $VM_NAME \
   --query "storageProfile.osDisk.managedDisk.storageAccountType" \
   -o tsv)

OSDISK_SYSTEMOS=$(az vm show \
   -g $RESOURCE_GROUP \
   -n $VM_NAME \
   --query "storageProfile.osDisk.osType" \
   -o tsv)


SNAPSHOT_ID=$(az snapshot create \
    -g $RESOURCE_GROUP \
	--source "$OSDISK_ID" \
	--name $BACKUP_NAME \
   --query "id" \
   -o tsv)


# STEP 4: Create a new diskless VM using the snapshot

#Create a new Managed Disks using the snapshot Id
az disk create --resource-group $RESOURCE_GROUP --name $OSDISK_NAME --sku $OSDISK_SKU --size-gb $OSDISK_SIZE --source $SNAPSHOT_ID 

#Create VM by attaching created managed disks as OS
az vm create --name $NEW_VM_NAME --resource-group $RESOURCE_GROUP --attach-os-disk $OSDISK_NAME --os-type $OSDISK_SYSTEMOS


# Step 5: Retrieve the private IP from the first VM to migrate it to the second one


