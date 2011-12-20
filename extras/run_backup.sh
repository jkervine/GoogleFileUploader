#!/bin/bash
#
# Simple server backup including a mysqldump for database backup. GoogleFileUploader example script
# This program is open source. Licenced under Apache Licence v2.0: http://www.apache.org/licenses/LICENSE-2.0.txt
# author: Juha Kervinen, http://joker.iki.fi  
#
# Configuration variables:
# 
# Write logging events here:

LOGFILE=/var/log/backup.log

# Directories used for dumping the Mysql data in plaintext and the archive. Make sure it's not readable by anyone else except privileged users.
DUMPDIR=/root/dbdumps

#Credentials which will be used to DUMP the mysql data from the databases
MYSQL_USER=root
MYSQL_PASS=secret

#Credentials used to perform backup to the google cloud
GOOGLE_USER=my.account@google.com
GOOGLE_PASS

#If backup set is above this size (in megabytes), cancel upload 
SIZE_WARNING=50 

#If you want to make a local copy of the file (for example to local RAID device, NFS mount or something), enter 1 here. Otherwise, enter 0.
MAKE_LOCAL_COPY=1

#The directory to place the temporary files in - *** make sure it's only readable by privileged accounts! ***

#The location to make the local copy of the backup  tarball in:
HDBACKUP=/mnt/fileserver/backup

#The directories to backup. The DIRS variable defines what's *included* in the backup.  
#EXCLUDE parameter defines those patters which are to be excluded from the backup set. See bsdtar(1) or tar(1) --exclude option for exact definition."
DIRS="/home /root /var/www /etc"
EXCLUDE="var/www/docs/*"

#Location of the Google File Uploader binary.
# *** MAKE IT executable only by root or other trusted account! ***
GFU_CMD=/root/gfu.py

#Below this line, script internals - so modify with care.
#--------------------------------------------------------
#--------------------------------------------------------
#TODO: check that enough diskspace is available in needed places
SIZEFILE=/root/backupsetsize.txt
SIZE_IN_BYTES=$((50*1024*1024))
TIME=`date`
#Currently no effect
PRESERVE_DAYS=2
DELTIMEEXT=`date -d "$PRESERVE_DAYS days ago" +%Y%m%d`
TIMEEXT=`date +%Y%m%d`
DUMPMYSQL=$DUMPDIR/mysql_data.dump.sql
TAR="/tmp/backup_$TIMEEXT.tar.bz2"
DEL="/tmp/backup_$DELTIMEEXT.tar.bz2"

echo "---- Starting backup at $TIME ---- "
echo "Cleaning $DUMPDIR..."
if [ -d $DUMPDIR ]
then 
    rm -f $DUMPDIR/*
    echo "Cleaned."
else
    mkdir $DUMPDIR
    echo "$DUMPDIR did not exist. Created."
fi
echo "Dumping mysql databases to $DUMPMYSQL"
mysqldump --all-databases -u $MYSQL_USER -p$MYSQL_PASS > $DUMPMYSQL
echo "OK.";
if [ -f $TAR ] ; then
    rm -f $TAR
    echo "Old backup set deleted..."
else
    echo "No old backup set..."
fi
echo "TARring..."
tar -cjvp --exclude $EXCLUDE -f $TAR $DIRS
echo "Done."
if [ $MAKE_LOCAL_COPY -eq 1 ] ; then
    echo "Making a local copy..."
    cp $TAR $HDBACKUP
fi
echo "Deleting backup created $PRESERVE_DAYS days ago..."
if [ -f $DEL ] ; then 
    rm -f $DEL
    echo "Delete $DEL"
else
    echo "Old backup archive $DEL deleted..."
fi
echo "Getting size..."
ls -s $TAR > $SIZEFILE
size_bytes=`cat $SIZEFILE`
if [ $size_bytes -gt $SIZE_IN_BYTES ] ; then
    echo "Size exceeds the configured limit!"
    exit 1
fi
echo "Encrypting..."
openssl enc -aes-256-cbc -salt -in $TAR -out $TAR.enc
echo "Uploading offsite..."
$(GFU_CMD) -u $GOOGLE_USER -p $GOOGLE_PASS -lf $TAR.enc
echo "Deleting encrypted archive..."
rm $TAR.enc
echo "Done."
