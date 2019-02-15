defmodule Sshd.Keys do
  @moduledoc """
  Callback module for SSH. Is needed so that we can handle RSA Keys
  with passphrases.
  """

  @behaviour :ssh_server_key_api
  require Logger

  @ssh_hostkey_filename Application.get_env(:sshd, :hostkey_filename, "ssh_host_rsa_key")
  @doc """
  Official documentation -> http://erlang.org/doc/man/ssh_server_key_api.html#Module:host_key-2
  """
  def host_key(algorithm, options) do
    cb_options = options[:key_cb_private]
    case cb_options[:key_passphrase] do
      nil ->
        # Delegate to system implementation for handling the host keys
        :ssh_file.host_key(algorithm, options)

      {module, func, args} ->
        system_dir = options[:system_dir]

        private_key = to_charlist(to_string(system_dir) <> "/" <> @ssh_hostkey_filename)

        case File.read(private_key) do
          {:ok, pem_bin} ->
            [x] = :public_key.pem_decode(pem_bin)
            rsa_key_passphrase = apply(module, func, args) |> to_charlist()

            try do
              key = :public_key.pem_entry_decode(x, rsa_key_passphrase)
              {:ok, key}
            rescue
              ## This error is thrown when the passphrase does not match the key
              MatchError ->
                Logger.error(
                  "Error fetching private key of host: Invalid Passphrase for the following key: #{
                    inspect(private_key)
                  }"
                )

                {:error, :invalid_passphrase}
            end

          {:error, error} ->
            Logger.error("Error fetching private key of host: #{inspect(error)}")
            {:error, error}
        end
    end
  end

  @doc """
  Official documentation is unclear on this (http://erlang.org/doc/man/ssh_server_key_api.html#Module:is_auth_key-3) however,
  when it returns `true`, our user/password systems is bypassed and users can log straight in
  """
  def is_auth_key(key, _user, options) do
    # Grab the decoded authorized keys from the options
    cb_opts = Keyword.get(options, :key_cb_private)
    keys = Keyword.get(cb_opts, :authorized_keys)

    # If any of them match, then we're good.
    Enum.any?(keys, fn {k, _info} -> k == key end)
  end
end
