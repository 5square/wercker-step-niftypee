#!/bin/bash

NIFTY_CACHE="$WERCKER_CACHE_DIR/niftypee"
DIFF_FILE=$NIFTY_CACHE/gitdiff.txt
PUT_FILE=$NIFTY_CACHE/put.txt
MKDIR_FILE=$NIFTY_CACHE/mkdir.txt
MKDIR_SORT_FILE=$NIFTY_CACHE/mkdir.sortable.txt
DELETE_FILE=$NIFTY_CACHE/delete.txt
RMDIR_FILE=$NIFTY_CACHE/rmdir.txt
RMDIR_SORT_FILE=$NIFTY_CACHE/rmdir.sortable.txt

for COMMAND in sed egrep git uniq tr wc; do
  type $COMMAND >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    fail "error: could not find the required command '$COMMAND'."
    exit 1
  fi
done

info "commands available; preparing cache."

if [ ! -d $NIFTY_CACHE ]; then
  mkdir $NIFTY_CACHE

  if [ $? -ne "0" ]; then
    fail "error: couldn't create niftypees cache-directory."
    exit 1
  fi
fi

info "cache-directory available; detecting protocol."

# extract the protocol - sFTP is not yet suported
FTP_CLIENT=$(echo $NIFTYPEE_TARGET | egrep -o "^(ftp)")

if test $FTP_CLIENT = "ftp"; then
  FTP_DELETE_CMD="delete"
  FTP_DESTINATION=$(sed "s/^(ftp:\/\/)(.*)$/\1$NIFTYPEE_USERNAME:$NIFTYPEE_PASSWORD\2/")
  log "detected file-transfer-protocol; resetting cache, getting commit-diff."
else
  fail "error: could not identify a protocol. your chosen protocol may be mispelled or not being supported."
  exit 1
fi

# reset the cache (temp-files aren't deleted at the end)
rm $NIFTY_CACHE/*.txt

# get the git-diff between the last two commits
git diff --name-status HEAD~1 HEAD > $DIFF_FILE


info "chache is reset, commit-diff generated; generating put-command-batch."
### PREPARE CREATE FILES BATCH

# extract all modifications and addings & prepend the put-command
egrep "^(M|A)" $DIFF_FILE | sed "s/^.[[:space:]]/put /" > $PUT_FILE

info "put-command-batch contains $(wc -l < $PUT_FILE) entries; generating mkdir-command-batch."
### PREPARE CREATE DIRECTORIES BATCH

# extract all directory-listings from the put-command & prepend the mkdir-command
cat $PUT_FILE | egrep "/" | sed "s/put \(.*\)\/.*/\1\//" > $MKDIR_FILE

info "..expanding subdirectories"
# count the number of slashes per line (= directory-level per listed directories)
touch $MKDIR_SORT_FILE
cat $MKDIR_FILE | while read LINE; do
  while [ ${#LINE} -gt 1 ]; do
    COUNT=$(echo $LINE | tr -cd "/" | wc -c)
    echo $COUNT "mkdir" $LINE >> $MKDIR_SORT_FILE
    LINE=$(echo $LINE | sed "s/[^\/]*\/$//")
  done
done

info "..condensing and sorting command-batch"
# filter single-file-entries out, sort directories (in asc order) to let the mkdir-commands appear in the right order.
# already existing directories will fail to create
uniq $MKDIR_SORT_FILE | egrep "[1-9]" | sort -n |  cut -d" " -f2,3 > $MKDIR_FILE

info "mkdir-command-batch contains $(wc -l < $MKDIR_FILE) entries; generating delete-command-batch."

### PREPARE DELETE FILES BATCH

# extract all deletions & prepend the protocol-sepcific delete-command
egrep "^(D)" $DIFF_FILE | sed "s/^.[[:space:]]/$FTP_DELETE_CMD /" > $DELETE_FILE


info "delete-command-batch contains $(wc -l < $DELETE_FILE) entries; generating rmdir-command-batch."
### PREPARE DELETE DIRECTORIES BATCH

# extract all directory-listings form the delete-command & prepend the rmdir-command
cat $DELETE_FILE | egrep "/" | sed "s/delete \(.*\)\/.*/\1\//" > $RMDIR_FILE

info "..expanding subdirectories"
# count the number of slashes per line (= directory-level per listed directories)
touch $RMDIR_SORT_FILE
cat $RMDIR_FILE | while read LINE; do
  while [ ${#LINE} -gt 1 ]; do
    COUNT=$(echo $LINE | tr -cd "/" | wc -c)
    echo $COUNT "rmdir" $LINE >> $RMDIR_SORT_FILE
    LINE=$(echo $LINE | sed "s/[^\/]*\/$//")
  done
done

info "..condensing and sorting command-batch"
# filter single-file-entries out, sort directories (in desc order) to let the rmdir-commands appear in the right order.
# non-empty-directories will fail to delete
uniq $RMDIR_SORT_FILE | egrep "[1-9]" | sort -nr |  cut -d" " -f2,3 > $RMDIR_FILE

info "rmdir-command-batch contains $(wc -l < $RMDIR_FILE) entries; batch files prepared."

info "okay $WERCKER_STARTED_BY, starting synchronization to $NIFTYPEE_TARGET."

FTP -V $FTP_DESTINATION <<END_SCRIPT
$(cat $NIFTY_CACHE/delete.txt)
$(cat $NIFTY_CACHE/rmdir.txt)
$(cat $NIFTY_CACHE/mkdir.txt)
$(cat $NIFTY_CACHE/put.txt)
quit
END_SCRIPT
