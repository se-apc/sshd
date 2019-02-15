use Mix.Config

root_dir = "_root_dir"

config :sshd,
  hostkey_filename: "ssh_host_rsa_key",
  interfaces: [
    [
      name: :public_daemon,
      interface: 'eth0',
      port: {Sshd.Default, :get_port, [:"network.ssh_port"]},
      shell: {Sshd.Default, :shell, []},
      exec: {Sshd.Default, :exec, []},
      enable?: {Sshd.Default, :enable?, [:eth0]},

      system_dir: "#{root_dir}/etc/ssh",
      self_gen_dir: "#{root_dir}/etc/ssh/self_generated",
      key_passphrase: {Sshd.Default, :key_passphrase, [:eth0]},

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
