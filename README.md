# Zsh Backup Script

This is a fairly naive zsh backup script which is meant to perform and track
any of minutely, hourly, daily, weekly, and monthly backups in a clever manner
(using `rsync`'s `--link-dest` option) to drastically reduce backup disk space
requirements. This script is meant to be run by the `cron` utility and a sample
`cron` configuration is given below; `cron` must create a 'backup_schedule'
file with an extension indicating the type of backup scheduled to be run, i.e.,
backup_schedule.{minutely, hourly, daily, weekly, monthly} and the script takes
care of determining which backup actually gets run. This is to handle the
complexity of not running 'lower' order backups that are normally scheduled
when 'higher' order backups are also scheduled. E.g., if a weekly backup is set
to run at the same time as the 'lower' order daily, hourly, or minutely,
backups, the script skips the 'lower' order backups and only runs the 'higher'
order weekly backup.

```
*/5 * * * *  touch /tmp/backups/backup_schedule.minutely && sleep 5 && zsh /Users/ehereth/Codes/rsync_backup/backup.zsh minutely >> /tmp/backups/backup.log 2>&1
*/10 * * * * touch /tmp/backups/backup_schedule.hourly && sleep 6 && zsh /Users/ehereth/Codes/rsync_backup/backup.zsh hourly >> /tmp/backups/backup.log 2>&1
*/15 * * * * touch /tmp/backups/backup_schedule.daily && sleep 7 && zsh /Users/ehereth/Codes/rsync_backup/backup.zsh daily >> /tmp/backups/backup.log 2>&1
*/30 * * * * touch /tmp/backups/backup_schedule.weekly && sleep 8 && zsh /Users/ehereth/Codes/rsync_backup/backup.zsh weekly >> /tmp/backups/backup.log 2>&1
0 * * * *    touch /tmp/backups/backup_schedule.monthly && sleep 9 && zsh /Users/ehereth/Codes/rsync_backup/backup.zsh monthly >> /tmp/backups/backup.log 2>&1
```
