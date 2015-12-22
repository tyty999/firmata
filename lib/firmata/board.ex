defmodule Firmata.Board do
  use GenServer
  use Firmata.Protocol.Mixin

  @doc """
  {:ok, board} = Firmata.Board.start_link "/dev/cu.usbmodem1421"
  """
  def start_link(tty, baudrate) do
    GenServer.start_link(__MODULE__, [tty, baudrate], [])
  end

  def connect(board) do
    GenServer.call(board, :connect, 10000)
    block_until_connected(board)
    :ok
  end

  defp block_until_connected(board) do
    unless connected?(board), do: block_until_connected(board)
  end

  def connected?(board) do
    get(board, :connected)
  end

  def get(board, key) do
    GenServer.call(board, {:get, key})
  end

  ## Server Callbacks

  def init([tty, baudrate]) do
    {:ok, serial} = Serial.start_link
    Serial.open(serial, tty)
    Serial.set_speed(serial, baudrate)
    state = [ serial: serial, connected: false ]
    {:ok, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Keyword.get(state, key), state}
  end

  def handle_call(:connect, _from, state) do
    Keyword.get(state, :serial) |> Serial.connect
    {:reply, :ok, state}
  end

  def handle_info({:report_version, major, minor }, state) do
    IO.puts "got version: #{major}.#{minor}"
    IO.puts "sending caps query"
    Serial.send_data(state[:serial], <<@start_sysex, @capability_query, @end_sysex>>)
    {:noreply, Keyword.put(state, :version, {major, minor})}
  end

  def handle_info({:firmware_name, name }, state) do
    IO.puts "got firmware name: #{name}"
    {:noreply, Keyword.put(state, :firmware_name, name)}
  end

  def handle_info({:capability_response, pins }, state) do
    IO.puts "got capabilities"
    IO.puts "doing analog mapping query"
    state = Keyword.put(state, :pins, pins) # |> Keyword.delete(:_protocol_state)
    Serial.send_data(state[:serial], <<@start_sysex, @analog_mapping_query, @end_sysex>>)
    {:noreply, state}
  end

  def handle_info({:analog_mapping_response, mapping }, state) do
    IO.puts "got mapping"
    IO.inspect mapping
    {:noreply, state}
  end

  def handle_info({:elixir_serial, _serial, data}, state) do
    acc = Firmata.Protocol.Accumulator.unpack(state)
    acc = Enum.reduce(data, acc, &Firmata.Protocol.parse(&2, &1))
    outbox = elem(acc, 0)
    IO.inspect outbox
    state = Firmata.Protocol.Accumulator.pack(acc, state)
    {:noreply, state}
  end
end
