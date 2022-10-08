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
export RESOURCE_GROUP=rg-vm

# Name of the old VM
export VM_NAME=myVM

# Name of the new VM
export NEW_VM_NAME=myNewVM

# SKY of the new VM
export NEW_VM_SKU='Standard_D2S_v5'

# Name of the OS disk backup (optional)
export BACKUP_NAME=osDisk_backup

# Name of the new disk name
export OSDISK_NAME=osDisk_MyNewVm


# STEP 1: On the VM, move the pagefile, from D (temp disk) to C (OS)

az login

# the VM must be started to execute the remote command
echo -e '\e[32mStarting the VM'
az vm start -g $RESOURCE_GROUP -n $VM_NAME

# move the pagefile from D to C
# /!\ RunPowerShellScript or RunShellScript depending on the OS
echo -e '\e[32mRunning a command to update registry'
az vm run-command invoke -g $RESOURCE_GROUP -n $VM_NAME --command-id RunPowerShellScript --scripts 'New-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name PagingFiles -Value "C:\Pagefile.sys 0 0" -Force'

# STEP 2: restart the VM

# restart the VM in order to change the pagefile location
echo -e '\e[32mRebooting the VM'
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

OSDISK_GENERATION=$(az vm get-instance-view \
   -g $RESOURCE_GROUP \
   -n $VM_NAME \
   --query instanceView.hyperVGeneration \
   -o tsv)

echo -e '\e[32mCreating a snapshot of the OS disk'
SNAPSHOT_ID=$(az snapshot create \
    -g $RESOURCE_GROUP \
	--source "$OSDISK_ID" \
   --hyper-v-generation $OSDISK_GENERATION \
	--name $BACKUP_NAME \
   --query "id" \
   -o tsv)


# stop the VM, because you can't have both VM with the same computer name
az vm stop -g $RESOURCE_GROUP -n $VM_NAME

# STEP 4: Create a new diskless VM using the snapshot

# Create a new Managed Disks using the snapshot Id
echo -e '\e[32mCreating a disk using the snapshot'
az disk create --resource-group $RESOURCE_GROUP --name $OSDISK_NAME --sku $OSDISK_SKU --size-gb $OSDISK_SIZE --source $SNAPSHOT_ID --hyper-v-generation $OSDISK_GENERATION

#Create VM by attaching created managed disks as OS
echo -e '\e[32mCreating a new VM using the disk'
az vm create --name $NEW_VM_NAME --resource-group $RESOURCE_GROUP --attach-os-disk $OSDISK_NAME --os-type $OSDISK_SYSTEMOS --size $NEW_VM_SKU --public-ip-sku Standard


# Step 5: Retrieve the private IP from the first VM to migrate it to the second one


