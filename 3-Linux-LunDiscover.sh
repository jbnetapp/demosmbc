#!/bin/bash
# echo Discover LUN
/usr/bin/rescan-scsi-bus.sh
multipath -ll
sanlun lun show -p

