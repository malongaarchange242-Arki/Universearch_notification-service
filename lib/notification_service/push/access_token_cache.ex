defmodule NotificationService.Push.AccessTokenCache do
  use GenServer

  @refresh_skew_seconds 60

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_token do
    GenServer.call(__MODULE__, :get_token, 15_000)
  end

  def invalidate do
    GenServer.cast(__MODULE__, :invalidate)
  end

  @impl true
  def init(_state) do
    {:ok, %{access_token: nil, expires_at: nil}}
  end

  @impl true
  def handle_call(:get_token, _from, state) do
    if token_fresh?(state) do
      {:reply, {:ok, state.access_token}, state}
    else
      case NotificationService.Push.Providers.FCMV1.fetch_access_token() do
        {:ok, access_token, expires_at} ->
          new_state = %{access_token: access_token, expires_at: expires_at}
          {:reply, {:ok, access_token}, new_state}

        error ->
          {:reply, error, state}
      end
    end
  end

  @impl true
  def handle_cast(:invalidate, _state) do
    {:noreply, %{access_token: nil, expires_at: nil}}
  end

  defp token_fresh?(%{access_token: token, expires_at: expires_at})
       when is_binary(token) and not is_nil(expires_at) do
    DateTime.compare(expires_at, DateTime.add(DateTime.utc_now(), @refresh_skew_seconds, :second)) ==
      :gt
  end

  defp token_fresh?(_state), do: false
end
