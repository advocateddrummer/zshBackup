#!/usr/bin/env zsh

zmodload zsh/zutil

setopt extendedglob nullglob

# This associative array holds the default parameters.
declare -A defaultParameters

defaultParameters=( freqMin  30 # run minutely backups every 30 minutes; should be in increments of 5 minutes
                    freqHour 2  # run hourly backups every 2 hours
                    freqDay  1  # run daily backups every day (once a day)
                    freqWeek 1  # run weekly backups once a week
                    freqMon  1  # run monthly backups once a month
                    keepMin  4  # keep 4 minutely backups
                    keepHour 24 # keep 24 hourly backups
                    keepDay  7  # keep 7 daily backups
                    keepWeek 5  # keep 5 weekly backups
                    keepMon  12 # keep 12 monthly backups
                  )

# This associative array holds the runtime parameters. It starts out as a copy
# of the default parameters and may be modified using the backup config file.
declare -A backupParameters
backupParameters=( ${(kv)defaultParameters} )

function parseConfig () {
  # This logic was pretty much stolen from:
  # https://zdharma.org/Zsh-100-Commits-Club/Zsh-Native-Scripting-Handbook.html#parsing-ini-file
  # TODO: make this a function.
  __out_hash='backupParameters'

  while read -r -t 1 line; do
    # Skip any lines that begin with either a # or ; character.
    if [[ "$line" = [[:blank:]]#(\;|\#)* ]]; then
      #echo "skipping $line..."
          continue
          # Match "[Section]" line.
        elif [[ "$line" = (#b)[[:blank:]]#\[([^\]]##)\][[:blank:]]# ]]; then
          __cur_section="${match[1]}"
          #echo "found section: $__cur_section"
          # Match "string:string" line and overwrite the default value found in the
          # 'backupParameters' associative array.
        elif
          # TODO: validate key before inserting into backupParameters.
          [[ "$line" = (#b)[[:blank:]]#([^[:blank:]=]##)[[:blank:]]#[:][[:blank:]]#(*) ]]; then
          match[2]="${match[2]%"${match[2]##*[! $'\t']}"}" # severe trick - remove trailing whitespace
          __access_string="${__out_hash}[${match[1]}]"
          : "${(P)__access_string::=${match[2]}}"
          #echo "found key:value pair: ${match[1]}:${match[2]}"
    fi

  done < '/Users/ehereth/Codes/rsync_backup/backup.conf'

  # Fix input errors; freqMin needs to be a factor of five for now.
  if (( $backupParameters[freqMin] % 5 != 0)); then
    #print -P "%B%F{red}Nope%b%f: freqMin must be a factor of five minutes..."
    (( backupParameters[freqMin] = (((backupParameters[freqMin] + 2)/5) * 5 ) ))
    #print -P "%B%F{red}Fixed%b%f: freqMin = $backupParameters[freqMin]"
  fi

  #for key value in ${(kv)backupParameters}; do
  #  echo "$key -> $value"
  #done
}
echo "Full command line: $@"

zparseopts -D -E -F - \
           a:=rsyncExtraArgs -args:=rsyncExtraArgs \
           h=help -help=help \
	         s=setup -setup=setup || exit 1

# remove first -- or -
end_opts=$@[(i)(--|-)]
set -- "${@[0,end_opts-1]}" "${@[end_opts+1,-1]}"

echo "Command line after zparseopts: $@"


echo "before: ${(kv)backupParameters}"

# TODO: support remote backup targets/destinations.
parseConfig

echo "after: ${(kv)backupParameters}"

function create_backup_string () {

  # Extract first argument which specifies the type of backup string to be
  # created; options are minutely, hourly, daily, weekly, monthly.
  success=0
  [[ $1 = 'minutely' || $1 = 'hourly' || $1 = 'daily' || $1 = 'weekly' || $1 = 'monthly' ]] || { print -P "%B%F{red}ERROR:%b%f incorrect use of $0"; success=-1 }
  # This still doesn't fix the issue, the ERROR print statement above never
  # gets printed in the event this test fails and the function returns. I
  # cannot figure out why.
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

backupSource="/Users/ehereth/Downloads"
backupDestRoot="/tmp/backups/"

# This function is meant to determine what sort of backup job should be run. I
# intend this to be run using cron and it is difficult to set up cron such that
# a daily backup does not run when a 'higher order' backup, i.e., weekly or
# monthly, is running.
function get_backup_type () {
  # Get list of 'backup_schedule.xxxxx' files which are created by cron. The
  # (:t) filter results in just the file name, not the entire path.
  backupShedules=($1'backup_schedule'*(:t))
  #echo "There are $#backupShedules schedule files:"
  #print -P "${backupShedules[@]}"
  if (( $backupShedules[(I)backup_schedule.monthly] )); then
    echo 'monthly'
  elif (( $backupShedules[(I)backup_schedule.weekly] )); then
    echo 'weekly'
  elif (( $backupShedules[(I)backup_schedule.daily] )); then
    echo 'daily'
  elif (( $backupShedules[(I)backup_schedule.hourly] )); then
    echo 'hourly'
  elif (( $backupShedules[(I)backup_schedule.minutely] )); then
    echo 'minutely'
  else
    echo "NOPE"
  fi

  #for s ($backupShedules) {
  #  ext=$s:t:e
  #  echo "$s has extention $ext"
  #}
}

backupType=$(get_backup_type $backupDestRoot)
#echo "backupType = $backupType"

# Skip the backup being run if it does not match the type obtained by
# get_backup_type above. This can happen when this script is being used with
# cron and when a scheduled daily backup is being run when a scheduled hourly
# backup is also scheduled. This script will cancel all 'lower' order backups
# scheduled at the same time in favor of the 'highest' order backup.
[[ $1 = $backupType ]] || { print -P "%B%F{red}Skipping $1 backup%b%f"; exit }

# Clean up cron generated 'schedule' files.
for f ($backupDestRoot'backup_schedule'*) {
  rm -rf $f
}
#[[ $1 = 'minutely' || $1 = 'hourly' || $1 = 'daily' || $1 = 'weekly' || $1 = 'monthly' ]] && backupType=$1 || { print -P "%B%F{red}ERROR:%b%f incorrect backup type specifed"; exit }

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

previousBackup=''

#case $backupType in
#  'minutely')
#    print -P "Performing a %B%F{green}$backupType%b%f backup"
#    previousBackup=$minutelyBackups[1]
#    print -P "\tPrevious $backupType backup is $minutelyBackups[1]"
#    ;;
#  'hourly')
#    print -P "Performing a %B%F{green}$backupType%b%f backup"
#    previousBackup=$hourlyBackups[1]
#    print -P "\tPrevious $backupType backup is $hourlyBackups[1]"
#    ;;
#  'daily')
#    print -P "Performing a %B%F{green}$backupType%b%f backup"
#    previousBackup=$dailyBackups[1]
#    print -P "\tPrevious $backupType backup is $dailyBackups[1]"
#    ;;
#  'weekly')
#    print -P "Performing a %B%F{green}$backupType%b%f backup"
#    previousBackup=$weeklyBackups[1]
#    print -P "\tPrevious $backupType backup is $weeklyBackups[1]"
#    ;;
#  'monthly')
#    print -P "Performing a %B%F{green}$backupType%b%f backup"
#    previousBackup=$monthlyBackups[1]
#    print -P "\tPrevious $backupType backup is $monthlyBackups[1]"
#    ;;
#  *)
#    print -P "%B%F{red}ERROR%f%b Nope"
#    exit
#    ;;
#esac

# Get the most recent backup, which will be marked by a symbolic link named
# 'latestBackup'. The (:A) option expands the symbolic link to the actual name
# of the parent directory and the (N) option allows this to succeed even if the
# symbolic link does not exist. This will be used below as the `--link-dest`
# option to rsync.
#
# NOTE: This requires that nullglob be set (setopt nullglob) which may not be
# desirable. Perhaps attempt to figure out a different way to do this?
previousBackup=($backupDestRoot'latestBackup'(:AN))

# This is not particularly portable, MacOS supports readlink without the -f
# argument, however, Linux requires the -f, I'll have to figure out how to do
# this portably in the future.
#previousBackup=$(readlink $previousBackup)

echo "previousBackup is $previousBackup..."
# Perform the rsync backup.
echo "Performing $backupType backup using rsync..."
echo "##########################################################################################"

# This works even if '--link-dest' is empty.
/usr/bin/rsync --verbose --archive --delete --link-dest=$previousBackup $backupSource $backupDest

# Move the latestBackup symbolic to the backup just created.
#unlink $backupDestRoot'latestBackup'
ln -sfn $backupDest $backupDestRoot'latestBackup'

echo "##########################################################################################"
print -P "%B%F{green}Backup Complete%f%b"
