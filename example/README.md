# SshdExample

This is the "kitchen sink" example of using the `Sshd` library.  See `config/config.exs`

For all examples:
* replace `172.17.0.2` with your `eth0` IP address.
* The password is handled via `SshdExample.Password`.  The default is "test"

## Public Domain

This example binds a daemon to the `eth0` interface.  The IP address is looked up at runtime, and the port is fetched using


Interactive Shell:
```
ssh test@172.17.0.2 -p 2022
```

Remote Shell:
```
ssh test@172.17.0.2 -p 2022 some command
```

SFTP:
```
mkdir _root_dir/public
touch _root_dir/public/remote_file

sftp -P 2022 test@172.17.0.2
# See remote_file
ls
```


## IEx Prompt

This example runs exposes the internal `iex>` prompt over SSH:
```
ssh test@172.17.0.2 -p 2122
```
