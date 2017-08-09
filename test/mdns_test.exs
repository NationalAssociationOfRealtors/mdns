defmodule MdnsTest do
  use ExUnit.Case
  require Logger
  doctest Mdns

  def get_address() do
    :inet.getifaddrs()
    |> elem(1)
    |> Enum.reduce_while({}, fn {_interface, attr}, acc ->
      case attr |> get_ipv4 do
        false -> {:cont, acc}
        {} -> {:cont, acc}
        {_, _, _, _} = add-> {:halt, add}
      end
    end)
  end

  def get_ipv4(attr) do
    case attr |> Keyword.get_values(:addr) do
      [] -> false
      l -> l |> Enum.reduce_while({}, fn ip, acc ->
        case ip do
          {127, 0, 0, 1} -> {:cont, acc}
          {_, _, _, _, _, _, _, _} -> {:cont, acc}
          {_, _, _, _} = add -> {:halt, add}
        end
      end)
    end
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
  end

  test "client and server" do
    Logger.debug "Testing Server"
    address = get_address()
    Logger.debug "#{inspect address}"
    host_name = "#{random_string(10)}.local"
    Logger.debug("Address: #{inspect address}")
    Logger.debug("Hostname: #{host_name}")
    Mdns.Server.start
    Mdns.EventManager.add_handler(Mdns.Handler)
    Mdns.Server.set_ip address
    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: host_name,
      data: :ip,
      ttl: 10,
      type: :a
    })
    char_host =  host_name |> String.to_charlist()
    lookup = :inet.gethostbyname(char_host, :inet)
    Logger.debug("#{inspect lookup}")
    assert {:ok, {:hostent, char_host , [], :inet, 4, [address]}} = lookup

    Logger.debug "Testing Client"
    Mdns.Client.start
    Mdns.Server.add_service(%Mdns.Server.Service{
      domain: "_nerves._tcp.local",
      data: "_rosetta._tcp.local",
      ttl: 10,
      type: :ptr
    })
    Mdns.Client.query("_nerves._tcp.local")
    assert_receive {:"_nerves._tcp.local", %Mdns.Client.Device{ip: address}}, 10_000

  end
end
