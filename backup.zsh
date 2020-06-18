#!/usr/bin/env zsh


function create_backup_string () {

  full_prefix="full_"
  incr_prefix="incr_"
  backup_root="backup_"
  date_format="+%d.%m.%Y-%T"

  time_stamp=$(date $date_format)

  echo "$backup_root$time_stamp"
  #echo "$full_prefix$backup_root$time_stamp"
  #echo "$incr_prefix$backup_root$time_stamp"
}

backupSource="/Users/ehereth/Downloads"
backupDest="/tmp/backups/"

# Check for existence of backup directories.
[[ ( -d $backupSource ) ]] && echo "backup source directory <$backupSource> exists" || print -P "%B%F{red}backup source directory <$backupSource> does not exist%f%b"
[[ ( -d $backupDest ) ]] && echo "backup destination directory <$backupDest> exists" || print -P "%B%F{red}backup destination directory <$backupDest> does not exist%f%b"

backupDir=$(create_backup_string)

# Zsh colors are tricky.
# I failed to get them to work with echo so I am using print -P.
# https://wiki.archlinux.org/index.php/zsh#Colors
# https://scriptingosx.com/2019/07/moving-to-zsh-06-customizing-the-zsh-prompt/
print -nP "%B%F{green}Creating backup directory: <$backupDir>%f%b"

mkdir $backupDest$backupDir && print -P "\t%B%F{green}-> Success!!!%f%b" || print -P "\n\t%B%F{red}Failed to create <$backupDir> ... exiting!!!%f%b"; exit
