# Bankparse

Set of utilities to process and parse email from Czech banks

### Parsemail


```shell
NAME
       parsemail - CLI for structured data out of emails

SYNOPSIS
       parsemail [options]

       Let use --help option to see brief help message.

OPTIONS
       -m --maildir
               Directory containing cur,new,tmp

       -u  --userdir
               Directory where to store user Maildirs

       -d  --dir
               Directory to parse

       -f  --file
               File to parse

       -i  --interval
               Time in seconds after which to retry POST

       -t  --text
               Include email text in debug output

       -s  --server
               Directory where to store user Maildirs

       -w  --watch
               Flag if parsemail should keep running and watch for new mail

       -h  -?  --help
               Print a brief help message and exit.
```

### Splitmail


```shell
NAME
       splitmail - CLI for splitting one Maildir into many Maildirs based on To: header

SYNOPSIS
       splitmail [options]

       Let use --help option to see brief help message.

OPTIONS
       -m --maildir
               Directory containing cur,new,tmp

       -u  --userdir
               Directory where to store user Maildirs

       -w  --watch
               Flag if splitmail should keep running and watch for new mail

       -h  -?  --help
               Print a brief help message and exit.
```
