# Ansible role: thycotic_cli

Configures a command line script that facilitates interacting with Thycotic, providing the ability for such things as getting secrets.

## Requirements

None.

## Role Variables

**system_bin_dir**

    adrianjuhl__thycotic_cli__system_bin_dir: "/usr/local/bin"

The directory to install thycotic_cli into.

**thycotic_cli_executable_name**

    adrianjuhl__thycotic_cli__thycotic_cli_executable_name: "thycotic_cli"

The name that the executable is to be installed as.

## Dependencies

None.

## Example Playbook
```
- hosts: servers
  roles:
    - { role: adrianjuhl.thycotic_cli }

or

- hosts: servers
  tasks:
    - name: Install thycotic_cli
      include_role:
        name: adrianjuhl.thycotic_cli
```

## Extras

### Install script

For convenience, a bash script is also supplied that facilitates easy installation of thycotic_cli on localhost (the script executes ansible-galaxy to install the role and then executes ansible-playbook to run a playbook that includes the thycotic_cli role).

The script can be run like this:
```
$ git clone git@github.com:adrianjuhl/ansible-role-thycotic-cli.git
$ cd ansible-role-thycotic-cli
$ .extras/bin/install_thycotic_cli.sh
```

## License

MIT

## Author Information

[Adrian Juhl](http://github.com/adrianjuhl)
