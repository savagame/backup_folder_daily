# Bash script for backup folder 

this is a tight mini-project: a bash backup script that snapshots a folder into a private github repo daily via cron, with locking, excludes and retention.
backup.sh is tight, disciplined, production-grade, i think.

## How to use

### Prepare
```bash
sudo apt update
sudo apt install -y git util-linux
ssh -T git@github.com || echo "Add your SSH key to GitHub first."
```
### Project layout
```bash
mkdir -p ~/myworks/backup_folder_daily/{scripts,logs,excludes}
printf "# Backups repo\n" > README.md
echo "*.tmp" > .gitignore
git add .
git commit -m "chore: init backups repo"
git push -u origin main
```
### Test backup.sh once(manual)
```bash
# EXAMPLE: back up ~/projects/important
mkdir -p ~/projects/important && echo "demo $(date)" > ~/projects/important/hello.txt
~/myworks/backup_folder_daily/scripts/backup.sh "$HOME/projects/important"
ls -1 ~/myworks/backup_folder_daily/archives/$(hostname -s)/*/*/*.tar.gz | tail -n 3
```
### Cron schedule (daily at 01:30)
```bash
crontab -l 2>/dev/null > /tmp/mycron.$$ || true
cat >> /tmp/mycron.$$ <<'CRON'

# Daily GitHub backup (01:30)
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
30 1 * * *  "$HOME/myworks/backup_folder_daily/scripts/backup.sh" "$HOME/projects/important" >> "$HOME/backup-git/logs/cron.out" 2>&1
CRON
crontab /tmp/mycron.$$
rm -f /tmp/mycron.$$
```

### smoke check:
```bash
# run once now, then inspect repo + logs
"$HOME/backup-git/backup_folder_daily/scripts/backup.sh" "$HOME/projects/important"
tail -n 5 "$HOME/backup-git/logs/backup.log" || true
```

### Restore(quick)
```bash
# choose an archive, verify checksum, and extract
ARCHIVE=$(ls -1 ~/backup-git/backup_folder_daily/archives/$(hostname -s)/*/*/*.tar.gz | tail -n1)
sha256sum -c "${ARCHIVE}.sha256"
mkdir -p ~/restore && tar -xzf "$ARCHIVE" -C ~/restore
```
### Optional: tag monthly snapshots
```bash
cd ~/backup-git/backups-noob
git tag -a "monthly-$(date +%Y-%m)" -m "Monthly snapshot"
git push --tags
```
