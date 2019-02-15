#
#  Copyright (c) Schneider Electric 2019, All Rights Reserved.
#
#    $ID$
#
#    @author "Michael Schmidt <michael.k.schmidt@.se.com>"
#    @author "Alan Jackson <alan.jackson@.se.com>"
#

defmodule Sshd do
  @moduledoc """
    Thin Wrapper over the SSH Daemon mondule.  Heavily based on example SSH module in the
    erlang docs

  Example Config:

  """
  require Logger
  use GenServer

  @server_name __MODULE__

  @time_to_kill Application.get_env(:sshd, :time_to_kill, :timer.seconds(1))
  @kill_attempts Application.get_env(:sshd, :kill_attempts, 10)

  @ssh_hostkey_filename Application.get_env(:sshd, :hostkey_filename, "ssh_host_rsa_key")

  @doc """
  Starts the SSH Daemon.
  """
  def start_link(_args \\ []) do
    GenServer.start_link(__MODULE__, [], name: @server_name)
  end

  def init(_) do
    :ssh.start(:permanent)
    interfaces = Sshd.start()
    {:ok, %{interfaces: interfaces, restart_delay_ref: nil}}
  end

  def get_state() do
    GenServer.call(@server_name, :get_state)
  end

  def start_interface(interface, port \\ nil) do
    GenServer.call(@server_name, {:start_interface, interface, port})
  end

  def restart_interface(interface, port \\ nil) do
    timeout = @time_to_kill * (@kill_attempts + 1)
    GenServer.call(@server_name, {:restart_interface, interface, port}, timeout)
  end

  def stop_interface(daemon_name) do
    timeout = @time_to_kill * (@kill_attempts + 1)
    GenServer.call(@server_name, {:stop_interface, daemon_name}, timeout)
  end

  def ssh_daemon_alive?(daemon) do
    if Process.whereis(@server_name) != nil do
      GenServer.call(@server_name, {:ssh_daemon_alive, daemon})
    else
      false
    end
  end

  @doc """
  Starts the SSH application.  Note as an application it does not need outside supervision
  """
  def start() do
    sshd_conf = Application.get_all_env(:sshd)
    for inteface_config <- sshd_conf[:interfaces], do: listen(inteface_config, nil)
  end

  def handle_call({:ssh_daemon_alive, daemon}, _from, state = %{interfaces: interfaces}) do
    result =
      Enum.any?(interfaces, fn [name: n, daemon_ref: d] ->
        n == daemon && d != nil && daemon_alive?(d)
      end)

    {:reply, result, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:restart_interface, interface, port}, from, state) do
    {:reply, _result, new_state} = handle_call({:stop_interface, interface}, from, state)

    {:reply, result, new_state} =
      handle_call({:start_interface, interface, port}, :ok, %{new_state | restart_delay_ref: nil})

    {:reply, result, new_state}
  end

  @doc """
  Handler to start SSH on an `interface`
  """
  def handle_call({:start_interface, interface, port}, _from, state = %{interfaces: interfaces}) do
    :ssh.start(:permanent)
    ## get list of interfaces from config
    sshd_conf = Application.get_all_env(:sshd)

    {result, new_interfaces} =
      if interface_exists?(interface, interfaces) do
        [return_value] =
          for inteface_config <- sshd_conf[:interfaces] do
            name = inteface_config[:name]

            if name == interface do
              ref = get_daemon_ref(name, interfaces)

              if ref == nil do
                ## start only the interface `interface`
                listen(inteface_config, port)
              else
                Logger.info("SSH already started on interface '#{inspect(name)}'.")
                [name: name, daemon_ref: ref]
              end
            else
              ## otherwise return :ok
              :ok
            end
          end
          ## filter out the :ok entries from the list
          |> Enum.reject(fn x -> x == :ok end)

        list_of_interfaces =
          for item = [name: name, daemon_ref: _old_ref] <- interfaces do
            ## replace old entry in the interfaces for this interface
            if interface == name do
              return_value
            else
              ## return the rest of the interfaces
              item
            end
          end

        {:ok, list_of_interfaces}
      else
        Logger.info(
          "Did not start ssh daemon #{inspect(interface)} because there is no configuration specified in the config for this interface."
        )

        {:interface_does_not_exist, interfaces}
      end

    {:reply, result, %{state | interfaces: new_interfaces}}
  end

  @doc """
  Handler to stop SSH from running on an `interface`
  """
  def handle_call({:stop_interface, interface}, _from, state = %{interfaces: interfaces}) do
    {result, new_interfaces} =
      if interface_exists?(interface, interfaces) do
        list_of_interfaces =
          for daemon = [name: name, daemon_ref: daemon_ref] <- interfaces do
            if name == interface do
              if daemon_ref == nil do
                Logger.info("ssh daemon #{inspect(name)} is already stopped.")
              else
                stop_daemon(daemon_ref, @kill_attempts)
                Logger.info("Successfully stopped #{inspect(name)} ssh daemon.")
              end

              [name: name, daemon_ref: nil]
            else
              daemon
            end
          end

        {:ok, list_of_interfaces}
      else
        Logger.info(
          "Not stopping interface #{inspect(interface)} as it does not exist in this configuration"
        )

        {:interface_does_not_exist, interfaces}
      end

    {:reply, result, %{state | interfaces: new_interfaces}}
  end

  def stop_daemon(daemon_ref, repeat_count \\ 0) do
    if daemon_alive?(daemon_ref) do
      :ssh.stop_daemon(daemon_ref)
      Process.sleep(@time_to_kill)

      ## check if daemon is still alive
      if daemon_alive?(daemon_ref) do
        Logger.info(
          "SSH Daemon kill was unsuccessful. Will try again #{repeat_count} more times."
        )

        if repeat_count > 0 do
          stop_daemon(daemon_ref, repeat_count - 1)
        else
          Logger.error(
            "Count not kill SSH daemon after #{@kill_attempts} attempts. This could mean ssh will not work"
          )

          false
        end
      else
        Logger.info("SSH Daemon was killed")
        true
      end
    else
      Logger.info("SSH Daemon already killed")
      true
    end
  end

  @doc """
  Listen to the specified interface. Port can either be specified as part of `args` or explicitily as the second argument,
  where the value specified in the second argument takes priority if it is not `nil`.
  """
  def listen(args, port \\ nil) do
    name = args[:name] || :no_name

    port = port(port, args)
    full_options = full_options(args)
    ip_addr = ip_addr(args)

    ## only start on eth0 if enabled
    if enabled?(args) do
      daemon(name, ip_addr, port, full_options, args)
    else
      Logger.error(
        "Could not start SSH Daemon for #{inspect(name)} on #{inspect(ip_addr)} on port #{
          inspect(port)
        }. Reason: :not_enabled"
      )

      [name: name, daemon_ref: nil]
    end
  end

  #
  # Convert the given args to the options needed by the :ssh module
  #
  defp full_options(args) do
    options = args[:options] || []
    pwdfun = args[:pwdfun] || (&Sshd.Default.pwdfun/4)
    key_cb = args[:key_cb] || Sshd.Keys

    system_dir =
      ensure_dirs_certs(args)
      |> Path.absname()
      |> to_charlist()

    sftp_subsystem = sftp_subsystem(args)
    subsystems = args[:subsystems] || []

    args_map =
      args
      |> Enum.into(%{})
      |> Map.merge(%{pwdfun: pwdfun, system_dir: system_dir})


    shell_options =
      cond do
        args[:shell] == :iex ->
          [shell: {IEx, :start, []}]

        args[:shell] != nil ->
          [shell: &Sshd.start_shell(&1, &2, args_map)]

        :else ->
          []
      end

    exec_options =
      cond do
        args[:exec] != nil ->
          [exec: &Sshd.start_exec(&1, &2, &3, args_map)]

        :else ->
          []
      end

    interface_options =
      case args[:interface] do
        nil ->
          []

        intf ->
          #[bind_to_device: intf]
          []
      end

    authorized_keys =
      (args[:authorized_keys] || [])
      |> Enum.join("\n")

    decoded_authorized_keys = :public_key.ssh_decode(authorized_keys, :auth_keys)

    cb_opts = [
      authorized_keys: decoded_authorized_keys,
      key_passphrase: args[:key_passphrase],
      system_dir: system_dir
    ]

    options ++
      interface_options ++
      shell_options ++
      exec_options ++
      [
        system_dir: system_dir,
        pwdfun: &Sshd.password_func(&1, &2, &3, &4, args_map),
        subsystems: sftp_subsystem ++ subsystems,
        key_cb: {key_cb, cb_opts}
      ]
  end

  #
  # See if this daemon is enabled
  #
  # This is a hook to allow runtime enable/disable of individual daemons
  defp enabled?(args) do
    case args[:enabled?] do
      {module, func, args} ->
        apply(module, func, args)

      false ->
        false

      true ->
        true

      _ ->
        true
    end
  end

  #
  # Lookup the port for the daemon
  #
  defp port(nil, args) do
    case args[:port] do
      port when is_integer(port) and port >= 0 and port < 65536 ->
        port

      {module, fun, args} ->
        apply(module, fun, args)
    end
  end

  defp port(port, _args) do
    port
  end

  #
  # Start the SSH Daemon and Report any errors
  #
  defp daemon(name, ip_addr, port, full_options, args) do
     case :ssh.daemon(ip_addr, port, full_options) do
      {:ok, daemon_ref} ->
        Logger.info("Successfully started SSH daemon on interface #{inspect(name)}.")
        ## store the daemon reference, provided it is not hidden.
        if args[:hidden] != true, do: Sshd.Table.set(name, daemon_ref)
        [name: name, daemon_ref: daemon_ref]

      {:error, :eaddrinuse} ->
        Logger.info(
          "Address is in use for #{inspect(name)}. Attempting to use old daemon ref..."
        )

        ## if address is in use, chances are that the an old daemon is still running. So we try to use that daemon reference
        daemon_ref = Sshd.Table.get(name)
        [name: name, daemon_ref: daemon_ref]

      {:error, error} ->
        Logger.error(
          "Could not start SSH Daemon for #{inspect(name)} on #{inspect(ip_addr)} on port #{
            inspect(port)
          }. Reason: #{inspect(error)}"
        )
        Logger.error("Configuration #{inspect full_options}")

        ## we need to call this here as there is a bug in erlang ssh where a tcp socket can remain
        ## open even when the daemon crashes/ doesn't start:
        kill_rogue_socket(ip_addr, port)
        ## store the daemon reference as `nil`
        if args[:hidden] != true, do: Sshd.Table.set(name, nil)
        [name: name, daemon_ref: nil]
    end
  end

  # NOTE about `ip_addr`. We really don't want this value to every be set to :any, as this will mean that
  # an SSH daemon will start on 0.0.0.0:<port_no>, which blocks all other ssh daemons on other interfaces
  # starting, if they have the same port number (which is quite likely, as it's normally 22 for all interfaces).
  # So if someone decides to make a change with IPs, please keep the above in mind.
  defp ip_addr(args) do
    case args[:ip_address] do
      nil ->
        # Implement interface via lookup for now
        # TODO: bind to interface once we are on OTP20
        case args[:interface] do
          nil ->
            :any

          intf ->
            :inet.getifaddrs()
            |> elem(1)
            |> List.keyfind(to_charlist(intf), 0)
            |> elem(1)
            |> Keyword.get(:addr)
        end

      ip_addr when is_binary(ip_addr) ->
        {:ok, ip_addr} =
          ip_addr
          |> to_charlist()
          |> :inet.parse_address()

        ip_addr

      raw_ip when is_tuple(raw_ip) ->
        raw_ip

      :any ->
        :any
    end
  end

  #
  # Ensure the system_dir is created and populated with needed certs
  #
  defp ensure_dirs_certs(args) do
    system_dir = args[:system_dir] || "/etc/ssh"
    self_gen_dir = args[:self_gen_dir] || system_dir

    if !File.exists?("#{system_dir}/#{@ssh_hostkey_filename}") or
           !File.exists?("#{system_dir}/#{@ssh_hostkey_filename}.pub") do
        Logger.info(
          "One or more ssh key(s) does not exist in the #{system_dir} directory. Using self generated key pair in #{
            self_gen_dir
          }."
        )

        unless File.exists?("#{self_gen_dir}/#{@ssh_hostkey_filename}") and
                 File.exists?("#{self_gen_dir}/#{@ssh_hostkey_filename}.pub") do
          Logger.info("Generating new RSA key pair...")
          File.rm_rf!(self_gen_dir)
          File.mkdir_p!(self_gen_dir)

          case args[:key_passphrase] do
            {module, func, args} ->
              rsa_key_passphrase = apply(module, func, args)
              generate_ssh_key_pair(self_gen_dir, rsa_key_passphrase)

            nil ->
              generate_ssh_key_pair(self_gen_dir)
          end
        end

        self_gen_dir
      else
        system_dir
      end
  end

  #
  # Create SFTP Subsystem spec
  #
  defp sftp_subsystem(args) do
    case args[:sftp] do
      nil ->
        []

      sftp_args ->
        sftp_dir =
          sftp_args[:dir]
          |> to_charlist()

        cwd =
          (sftp_args[:cwd] || "/")
          |> to_charlist()

        file_handler_arg =
          if sftp_args[:handler] do
            [file_handler: sftp_args[:handler]]
          else
            []
          end

        [
          :ssh_sftpd.subsystem_spec(
            [
              root: sftp_dir,
              cwd: cwd
            ] ++ file_handler_arg
          )
        ]
    end
  end

  ## Function to check if an `interface exists in the given list of `interfaces`. Is useful because `interfaces` is actually a list of lists.
  defp interface_exists?(interface, interfaces) do
    new_list =
      for [name: name, daemon_ref: _ref] <- interfaces do
        if name == interface do
          true
        else
          :ok
        end
      end
      ## filter out the :ok entries from the list
      |> Enum.reject(fn x -> x == :ok end)

    case new_list do
      [] -> false
      _not_empty_list -> true
    end
  end

  ## Function to return the :ssh.daemon reference for a given `interface` in a list of `interfaces`
  defp get_daemon_ref(interface, interfaces) do
    new_list =
      for [name: name, daemon_ref: ref] <- interfaces do
        if name == interface do
          ref
        else
          :ok
        end
      end
      ## filter out the :ok entries from the list
      |> Enum.reject(fn x -> x == :ok end)

    case new_list do
      [] -> nil
      [result] -> result
    end
  end

  # This may look like a strange way to check if the daemon is runnning, but that is how erlang does it
  # https://github.com/erlang/otp/blob/master/lib/ssh/src/sshd_sup.erl . I would have used erlangs function if it was not private.
  # Doing this initial check is just stop a FunctionClauseError being spat out in the sshd_sup file when it's stop_child function
  # gets an atom as an argument.
  # We also check if the Process is alive ourselves because we trust no one anymore!

  # Note, that from testing, the :list.keyfind/3 function appears very expensive because it take a long time to run, but seems to be effective
  # Maybe we could just switch to Process.alive?/1
  defp daemon_alive?(daemon_ref),
    do:
      :lists.keyfind(daemon_ref, 2, Supervisor.which_children(:sshd_sup)) != false or
        Process.alive?(daemon_ref)

  # Map the password_func to the configured function
  def password_func(user, password, peer_addr, state, _args = %{pwdfun: pwdfun}) do
    pwdfun.(to_string(user), to_string(password), peer_addr, state)
  end

  def start_exec(cmd, user, peer, %{exec: {module, func, args}}) do
    spawn(fn ->
      apply(module, func, [user, peer | args])
    end)
  end

  def start_shell(user, peer, %{shell: {module, func, args}}) do
    spawn(fn ->
      apply(module, func, [user, peer | args])
    end)
  end

  ## Will Kill a tcp socket based on ip and port, if it finds one.
  defp kill_rogue_socket(:any, port), do: kill_rogue_socket({0, 0, 0, 0}, port)

  defp kill_rogue_socket(ip, port) do
    ports = :erlang.ports()

    tcp_sockets =
      Enum.filter(ports, fn port ->
        :erlang.port_info(port)[:name] == 'tcp_inet'
      end)

    socket =
      Enum.find(tcp_sockets, fn s ->
        {:ok, {i, p}} = :prim_inet.sockname(s)
        i == ip && p == port
      end)

    unless socket == nil, do: :gen_tcp.close(socket)
  end

  def generate_ssh_key_pair(key_path) do
    case System.cmd("ssh-keygen", [
           "-t",
           "rsa",
           "-f",
           "#{key_path}/#{@ssh_hostkey_filename}"
         ]) do
      {_, 0} ->
        Logger.info("Successfully generated new RSA key pair.")

      {error, _} ->
        Logger.info("Failed to generate new RSA key pair: #{inspect(error)}")
    end
  end

  def generate_ssh_key_pair(key_path, passphrase) do
    case System.cmd("ssh-keygen", [
           "-t",
           "rsa",
           "-N",
           passphrase,
           "-f",
           "#{key_path}/#{@ssh_hostkey_filename}"
         ]) do
      {_, 0} ->
        Logger.info("Successfully generated new RSA key pair.")

      {error, _} ->
        Logger.info("Failed to generate new RSA key pair: #{inspect(error)}")
    end
  end
end
