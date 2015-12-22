defmodule Firmata.Protocol do
  use Firmata.Protocol.Mixin

  def parse({outbox, {}}, <<@report_version>>) do
    {outbox, {:report_version}}
  end

  def parse({outbox, {:report_version}}, <<major>>) do
    {outbox, {:report_version, major}}
  end

  def parse({outbox, {:report_version, major}}, <<minor>>) do
    {[ {:report_version, major, minor} | outbox ], {}}
  end

  def parse({outbox, {}}, <<@start_sysex>> = sysex) do
    {outbox, {:sysex, sysex}}
  end

  def parse({outbox, {:sysex, sysex}}, <<@end_sysex>>) do
    sysex = sysex<><<@end_sysex>>
    len = Enum.count(sysex)
    command = Enum.slice(sysex, 1, 1) |> List.first
    IO.inspect "sysex len #{len}, command: #{Hexate.encode(command)}"
    {[ Firmata.Protocol.Sysex.parse(command, sysex) | outbox ], {}}
  end

  def parse({outbox, {:sysex, sysex}}, byte) do
    {outbox, {:sysex, sysex <> byte }}
  end

  def parse(protocol_state, byte) do
    IO.puts "unknown: #{Hexate.encode(byte)}"
    protocol_state
  end
end
