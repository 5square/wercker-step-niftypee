# niftypee


Upstream your current HEAD via FTP. Stream it smooth and nifty.

After i tried to use some other FTP-deploy-steps for deploying projects to shared-hosters via FTP (which, unfortunately, is still widely used), I was somehow disappointed about their performance and stability.

With the development of niftypee I aimed for two goals: speed and robustness.

### Speed

The performance of this script is mainly achieved by reducing the executed FTP-commands to an absolute minimum. To recognize which steps must be taken to deliver the repo-update to the server, a `git show --name-status --oneline` is done. The resulting file-list transferred into batch files for the corresponding `put`, `delete`, `mkdir` and `rmdir`FTP-commands.

If there's no file to put or delete the suceeding generation of the corresponding mkdir- and rmdir-batches is skipped.

So in short the applied changes of the last commit (of the current `HEAD`) are being mapped to the target.

### Robustness

To make the script working on more boxes, it tries to use the (i hope) highly available commands `sed`, `egrep`, `git`, `uniq`, `tr`, `tail` and `wc`.

## Cache

Niftypee makes use of its cache-directory (on the box) only within its execution-cycle. All remaining text-files may be deleted (which will be done automatically at the beginning of the next execution) and exist only for debugging purposes.

## Example

Use as `target` the full ftp-path with suceeding target-directories. Let's say you'd like to deploy to your ftp-server `foo.com` and there into the `bar`-directory, your `target` would be `ftp://foo.com/bar`.

```
    - florianb/niftypee:
        target: ftp://foo.com/bar
        username: donaldduck
        password: ilovedaisy4ever!
```
