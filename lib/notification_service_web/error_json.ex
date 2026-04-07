defmodule NotificationServiceWeb.ErrorJSON do
  def render("404.json", _assigns), do: %{error: "Not found"}
  def render("500.json", _assigns), do: %{error: "Internal server error"}

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
    |> then(&%{error: &1})
  end
end
