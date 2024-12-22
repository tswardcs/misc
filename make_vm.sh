#!/bin/bash

#
# make_kevim_vm.sh
# Tim Ward 12/21/2024
# VSI, INC 
#
# TODO: add header
#


# usage routine 
usage() {
   echo "Program usage:"
   echo " $ make_kevim_vm [-h|-help]"
   echo " $ make_kevim_vm <-n VMNAME> <-o OPT_FILE_PATH> [-r <RAM_VAL>] [-c <NCPUS>] [-desc <description>]"
   echo "      [-d <TYPE> <SIZE>] ... [-d <TYPE> <SIZE>] (N <= 6)"
   # TODO: make this accurate
}

# check to see if display program usage (help menu)
if [ "$#" -eq 0 ] || ([ "$#" -eq 1 ] && ([ $1 = "-h" ] || [ $1 = "-help" ]));  then
   usage
   exit 0
fi

# program variables
VM_NAME=""
PROC_NAME=false
PROC_RAM_VAL=false
PROC_DISK=0
PROC_OPT=false
PROC_NCPUS=false
PROC_DESC=false
DESC_STR="New Kevim VM"
RAM_VAL=4096
NCPUS=2
disk_vals=(scsi 20 "" 0 "" 0 "" 0 "" 0 "" 0)
dindex=0
nargs=$#
ndisks=1
disks_chosen=false
OPT_FILE_PATH=""
i=0

# iterate through arguments to parse user input
for var in "$@"
    do
    #-- flags
    if [ "$var" = "-n" ]; then # Set VM_NAME flag
        if [ $PROC_NAME = true ]; then
            echo "Invalid arguments."
            usage 
            exit 1
        fi
        PROC_NAME=true
    elif [ "$var" = "-r" ]; then # set RAM flag
        if [ $PROC_RAM_VAL = true ]; then
            echo "Invalid arguments."
            usage 
            exit 1
        fi
        PROC_RAM_VAL=true
    elif [ "$var" = "-d" ]; then # add disk flag
        if [ $PROC_DISK -ne 0 ]; then
            echo "Invalid arguments."
            usage 
            exit 1
        fi
        PROC_DISK=1
    elif [ "$var" = "-desc" ]; then # add description flag
        if [ $PROC_DESC = true ]; then
            echo "Invalid arguments."
            usage 
            exit 1
        fi
        PROC_DESC=true
    elif [ "$var" = "-o" ]; then # optical/iso file location flag
        if [ $PROC_OPT = true ]; then
            echo "Invalid arguments."
            usage 
            exit 1
        fi
        PROC_OPT=true
    elif [ "$var" = "-c" ]; then # number of CPUs flag
        if [ $PROC_NCPUS = true ]; then
            echo "Invalid arguments."
            usage 
            exit 1
        fi
        PROC_NCPUS=true
    #-- values
    elif [ $PROC_NAME = true ]; then # process VM_NAME
        PROC_NAME=false
        VM_NAME=$var
    elif [ $PROC_OPT = true ]; then # process optical/iso file location
        OPT_FILE_PATH=$var
        if [ ! -f $OPT_FILE_PATH ]; then
            echo "Optical path DOES NOT EXIST."
            exit 1
        fi
        PROC_OPT=false
    elif [ $PROC_NCPUS = true ]; then # process number of CPUs
        if [[ ! $var =~ ^-?[0-9]+$ ]]; then
            echo "The argument is NOT a number."
            usage
            exit 1
        fi
        NCPUS=$var
        PROC_NCPUS=false
    elif [ $PROC_RAM_VAL = true ]; then # process RAM value
        if [[ ! $var =~ ^-?[0-9]+$ ]]; then
            echo "The argument is NOT a number."
            usage
            exit 1
        fi
        RAM_VAL=$var
        PROC_RAM_VAL=false
    elif [ $PROC_DESC = true ]; then # process description value
        DESC_STR=$var
        PROC_DESC=false
    elif [ $PROC_DISK -gt 1 ]; then # process a disk being added (size)
        if [[ ! $var =~ ^-?[0-9]+$ ]]; then
            echo "The argument is NOT a number."
            usage
            exit 1
        fi
        disk_vals[$dindex]=$var
        dindex=$((dindex + 1))
        ndisks=$((ndisks + 1))
        PROC_DISK=0
    elif [ $PROC_DISK -gt 0 ]; then # process a disk being added (type)
        disks_chosen=true
        if [ ! $var = "sata" ] && [ ! $var = "scsi" ]; then
            echo "INVALID PROCESS DISK TYPE (sata or scsi)"
            usage
            exit 1
        fi
        disk_vals[$dindex]=$var
        dindex=$((dindex + 1))
        PROC_DISK=2
    else # else it is an invalid/unknown argument supplied.
        echo "'$var' is an unrecognized command line argument."
        usage
        exit 1
    fi
    i=$((i + 1))
done
  
# error check to make sure the arguments were completed (values added to flags)
if [ $PROC_DISK -ne 0 ] || [ $PROC_NAME = true ] || [ $PROC_RAM_VAL = true ] || 
    [ $PROC_OPT = true ] || [ $PROC_NCPUS = true ] || [ $PROC_DESC = true ]; then
    echo "Invalid arguments"
    usage
    exit 1
fi

# make sure the VM_NAME was supplied.
if [ -z "$VM_NAME" ]; then
    echo "ERROR: VM NAME not specified."
    usage
    exit 1
fi

# make sure the OPTICAL/ISO disk path was supplied.
if [ -z "$OPT_FILE_PATH" ]; then
    echo "ERROR: Optical file path not specified."
    usage
    exit 1
fi

# if the user added disk arguments, adjust the count (one-off)
if [ $disks_chosen = true ]; then
    ndisks=$((ndisks - 1))
fi

# make sure the user didn't supply more than MAX (6) disks
if [ $ndisks -gt 6 ]; then
    echo "ERROR: maximum of 6 disks allowed."
    usage
    exit 1
fi

HOME_DIR=/home/admin
VM_DIR=$HOME_DIR/$VM_NAME

# if the VM directory already exists this is an error (VM already created)
if [ -d $VM_DIR ]; then
    echo "ERROR: $VM_DIR ALREADY EXISTS."
    exit 1
fi

# display the configuration and make sure the user is ok with it.
echo "~=~=~=~=~=~=~=~=~=~="
echo "VM NAME=$VM_NAME"
echo "HOME_DIR=$HOME_DIR"
echo "VM_DIR=$VM_DIR"
echo "OPTICAL/ISO FILE PATH=$OPT_FILE_PATH"
echo "Description=\""$DESC_STR"\""
echo "RAM=$RAM_VAL"
echo "NCPUS=$NCPUS"
echo "NDISKS=$ndisks"
#-
i=0
j=0
dindex=0
disks_str=""
tmp_disk_type=""

# iterate through the array of disk information, display relevant info
# and gather text for the install string.
for disk_val in "${disk_vals[@]}"; do
    if [ $((i % 2)) -eq 0 ]; then
        if [ $dindex -eq $ndisks ]; then
            break
        fi
        disks_str="${disks_str} --disk 'path="$VM_DIR"/"$VM_NAME"_$dindex.qcow2,"
        echo "Disk $dindex"
        dindex=$((dindex + 1))
        j=0
    fi
    j=$((j + 1))
    if [ $j -eq 1 ]; then 
        tmp_disk_type=$disk_val
        echo "  Disk type=$tmp_disk_type"
    else
        boot_order=$((dindex + 1))
        disks_str="${disks_str}size=$disk_val,bus=$tmp_disk_type,boot_order=$boot_order,cache=writeback'"
        echo "  Disk size=$disk_val GB"
    fi
    i=$((i + 1))
    done
echo "~=~=~=~=~=~=~=~=~=~="

# make sure the user is ok with the configuration before proceeding.
response=""
echo "Are you sure you want to create $VM_NAME with the current configuration? Typing y/yes will proceed with the installation. Any other input will abort."
echo " (any other response will abort)"
read response
if ([ ! $response = "y" ] && [ ! $response = "yes" ]) || [ -z "$response" ]; then
    echo "Aborting creation of VM $VM_NAME"
    exit 0
fi

# create the directory for the new VM
sudo mkdir $VM_DIR

echo "Creating VM $VM_NAME..."

# the virt-install string which is a combination of default and/or 
# user specified values
vinst_str="sudo virt-install \
--name="$VM_NAME" \
--description=\""$DESC_STR"\" \
--ram="$RAM_VAL" \
--vcpus="$NCPUS" \
--disk 'device=cdrom,path="$OPT_FILE_PATH",bus=sata,boot_order=1' "$disks_str" --network default \
--graphics=none \
--os-type generic --os-variant generic \
--machine q35 \
--boot loader=/usr/share/OVMF/OVMF_CODE.secboot.fd,loader.readonly=yes,loader.type=pflash,loader_secure=yes \
--features vmport.state=off,smm.state=on \
--serial pty \
--noreboot"

#echo "VIRT INST STRING"
#echo \"$vinst_str\"
#exit 1
#echo "RUNNING VINST_STR"

# run the command that is the result of the virt-install string.
eval $vinst_str

echo "EXITING (success)"

