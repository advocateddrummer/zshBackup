#!/usr/bin/env zsh

function create_backup_string () {

  # Extract first argument which specifies the type of backup string to be
  # created; options are minutely, hourly, daily, weekly, monthly.
  success=0
  [[ $1 = 'minutely' || $1 = 'hourly' || $1 = 'daily' || $1 = 'weekly' || $1 = 'monthly' ]] || { print -P "%B%F{red}ERROR:%b%f incorrect use of $0"; success=-1 }
  # This still doesn't fix th issue, the ERROR print statement above never gets
  # printed in the event this test fails and the function returns. I cannot
  # figure out why.
  [[ $success != '0' ]] && return -1

  prefix="$1_"
  full_prefix="full_"
  incr_prefix="incr_"
  backup_root="backup_"
  date_format="+%d.%m.%Y-%T"

  time_stamp=$(date $date_format)

  echo "$prefix$backup_root$time_stamp"
  #echo "$full_prefix$backup_root$time_stamp"
  #echo "$incr_prefix$backup_root$time_stamp"
  return 0
}

backupType=""
[[ $1 = 'minutely' || $1 = 'hourly' || $1 = 'daily' || $1 = 'weekly' || $1 = 'monthly' ]] && backupType=$1 || { print -P "%B%F{red}ERROR:%b%f incorrect backup type specifed"; exit }
backupSource="/Users/ehereth/Downloads"
backupDestRoot="/tmp/backups/"

# Check for existence of backup directories.
[[ ( -d $backupSource ) ]] && echo "backup source directory <$backupSource> exists" || print -P "%B%F{red}backup source directory <$backupSource> does not exist%f%b"
[[ ( -d $backupDestRoot ) ]] && echo "backup destination directory <$backupDestRoot> exists" || print -P "%B%F{red}backup destination directory <$backupDestRoot> does not exist%f%b"

backupDir=$(create_backup_string $backupType)
# Somehow, create_backup_string failed; do not proceed.
[[ $? != 0 ]] && exit
backupDest=$backupDestRoot$backupDir

# Inventory old backups; the glob options (om) sort the results by modification
# time, newest directories first while the (N) option causes this not to fail
# if the array is empty.
minutelyBackups=($backupDestRoot'minutely'*/(Nom))
hourlyBackups=($backupDestRoot'hourly'*/(Nom))
dailyBackups=($backupDestRoot'daily'*/(Nom))
weeklyBackups=($backupDestRoot'weekly'*/(Nom))
monthlyBackups=($backupDestRoot'monthly'*/(Nom))
echo "There are $#minutelyBackups minutely backups"
echo "There are $#hourlyBackups hourly backups:"
echo "There are $#dailyBackups daily backups:"
echo "There are $#weeklyBackups weekly backups:"
echo "There are $#monthlyBackups monthly backups:"
echo
print -P "%B%F{green}${minutelyBackups[1,4]}%f%b %B%F{red}${minutelyBackups[5,-1]}%b%f"
echo
print -P "%B%F{green}${hourlyBackups[1,6]}%f%b %B%F{red}${hourlyBackups[7,-1]}%b%f"
echo
print -P "%B%F{green}${dailyBackups[1,7]}%f%b %B%F{red}${dailyBackups[8,-1]}%b%f"
echo
print -P "%B%F{green}${weeklyBackups[1,4]}%f%b %B%F{red}${weeklyBackups[5,-1]}%b%f"
echo
print -P "%B%F{green}${monthlyBackups[1,12]}%f%b %B%F{red}${monthlyBackups[13,-1]}%b%f"
echo

# Remove backups that are too old.
for b (${minutelyBackups[5,-1]}) {
  print -P "%B%F{red}Removing minutely backup $b%f%b"
  rm -rf $b
}
for b (${hourlyBackups[7,-1]}) {
  print -P "%B%F{red}Removing hourly backup $b%f%b"
  rm -rf $b
}
for b (${dailyBackups[8,-1]}) {
  print -P "%B%F{red}Removing daily backup $b%f%b"
  rm -rf $b
}
for b (${weeklyBackups[5,-1]}) {
  print -P "%B%F{red}Removing weekly backup $b%f%b"
  rm -rf $b
}
for b (${monthlyBackups[12,-1]}) {
  print -P "%B%F{red}Removing monthly backup $b%f%b"
  rm -rf $b
}

echo

# Zsh colors are tricky.
# I failed to get them to work with echo so I am using print -P.
# https://wiki.archlinux.org/index.php/zsh#Colors
# https://scriptingosx.com/2019/07/moving-to-zsh-06-customizing-the-zsh-prompt/
#print -nP "%B%F{green}Creating backup directory: <$backupDest>%f%b"
print -P "Creating backup directory: <$backupDest>"

mkdir $backupDest && print -P "\t%B%F{green}Success!!!%f%b" || { print -P "\t%B%F{red}Failed to create <$backupDir> ... exiting!!!%f%b"; exit }

# Perform the rsync backup.

echo "Performing $backupType backup using rsync..."
previousBackup=''
case $backupType in
  'minutely')
    print -P "Performing a %B%F{green}$backupType%b%f backup"
    previousBackup=$minutelyBackups[1]
    print -P "\tPrevious $backupType backup is $minutelyBackups[1]"
    ;;
  'hourly')
    print -P "Performing a %B%F{green}$backupType%b%f backup"
    previousBackup=$hourlyBackups[1]
    print -P "\tPrevious $backupType backup is $hourlyBackups[1]"
    ;;
  'daily')
    print -P "Performing a %B%F{green}$backupType%b%f backup"
    previousBackup=$dailyBackups[1]
    print -P "\tPrevious $backupType backup is $dailyBackups[1]"
    ;;
  'weekly')
    print -P "Performing a %B%F{green}$backupType%b%f backup"
    previousBackup=$weeklyBackups[1]
    print -P "\tPrevious $backupType backup is $weeklyBackups[1]"
    ;;
  'monthly')
    print -P "Performing a %B%F{green}$backupType%b%f backup"
    previousBackup=$monthlyBackups[1]
    print -P "\tPrevious $backupType backup is $monthlyBackups[1]"
    ;;
  *)
    print -P "%B%F{red}ERROR%f%b Nope"
    exit
    ;;
esac

# This works even if '--link-dest' is empty.
/usr/bin/rsync --verbose --archive --delete --link-dest=$previousBackup $backupSource $backupDest

print -P "%B%F{green}Done%f%b"
