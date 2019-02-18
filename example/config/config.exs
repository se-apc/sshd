# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :sshd_example, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:sshd_example, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"

use Mix.Config

root_dir = "_root_dir"

config :sshd,
  hostkey_filename: "ssh_host_rsa_key",
  interfaces: [
    [
      name: :public_daemon,
      interface: 'eth0',
      pwdfun: &SshdExample.Password.pwdfun/4,
      port: {SshdExample.Config, :get_port, [:"network.ssh_port"]},
      shell: {SshdExample.Shell, :shell, []},
      exec: {SshdExample.Shell, :exec, []},
      enable?: {SshdExample.Config, :enable?, [:eth0]},

      system_dir: "#{root_dir}/etc/ssh",
      self_gen_dir: "#{root_dir}/etc/ssh/self_generated",
      key_passphrase: {SshdExample.Config, :key_passphrase, [:eth0]},

      authorized_keys: [],
      sftp: [
        cwd: "/",
        dir: Path.join(Path.absname(root_dir), "public"),
      ],

      options: [
        profile: :cli,
        max_sessions: 10
      ]

    ],
    [
      name: :private,
      port: 4022,
      shell: {Sshd.Default, :shell, [:some_args]},
      exec: {Sshd.Default, :exec, [:some_args]},

      system_dir: "#{root_dir}/etc/ssh_private",
      self_gen_dir: "#{root_dir}/etc/ssh_private/self_generated",

      sftp: [
        dir: Path.join(Path.absname(root_dir), "private")
      ],
      options: [
        profile: :cli,
        max_sessions: 10
      ]
    ],
    [
      name: :iex,
      pwdfun: &SshdExample.Password.pwdfun/4,
      enabled?: Mix.env != :prod,
      port: 2122,
      shell: :iex,

      system_dir: "#{root_dir}/etc/ssh_iex",

      options: [
        profile: :iex,
        max_sessions: 10
      ]
    ],
    # Below is an example for nerves_firmware_ssh
    # [
    #   name: :nerves_firmware_ssh,
    #   port: 8989,
    #   system_dir: "#{root_dir}/etc/ssh",
    #   self_gen_dir: "#{root_dir}/etc/ssh/self_generated",

    #   authorized_keys: [
    #     "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQDBCdMwNo0xOE86il0DB2Tq4RCv07XvnV7W1uQBlOOE0ZZVjxmTIOiu8XcSLy0mHj11qX5pQH3Th6Jmyqdj",
    #     "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCaf37TM8GfNKcoDjoewa6021zln4GvmOiXqW6SRpF61uNWZXurPte1u8frrJX1P/hGxCL7YN3cV6eZqRiF"
    #   ],
    #   subsystems: [
    #     {'nerves_firmware_ssh', {Nerves.Firmware.SSH.Handler, []}}
    #   ],
    # ]
  ]
