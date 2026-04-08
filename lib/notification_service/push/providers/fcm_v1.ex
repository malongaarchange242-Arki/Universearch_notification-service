defmodule NotificationService.Push.Providers.FCMV1 do
  @behaviour NotificationService.PushProvider

  alias NotificationService.Models.DeviceToken
  alias NotificationService.Models.Notification
  alias NotificationService.Push.AccessTokenCache
  alias NotificationService.Push.Credentials

  require Logger

  @token_grant_type "urn:ietf:params:oauth:grant-type:jwt-bearer"

  def deliver(%DeviceToken{} = device_token, %Notification{} = notification, payload)
      when is_map(payload) do
    with {:ok, credentials} <- Credentials.load(),
         {:ok, access_token} <- AccessTokenCache.get_token(),
         endpoint <- build_send_endpoint(credentials),
         body <- build_send_body(device_token, notification, payload),
         {:ok, status_code, response_body} <-
           http_post_json(endpoint, auth_headers(access_token), Jason.encode!(body)),
         result <- parse_send_response(status_code, response_body) do
      result
    end
  end

  def fetch_access_token do
    with {:ok, credentials} <- Credentials.load(),
         assertion <- build_jwt_assertion(credentials),
         body <-
           URI.encode_query(%{
             "grant_type" => @token_grant_type,
             "assertion" => assertion
           }),
         {:ok, status_code, response_body} <-
           http_post_form(credentials["token_uri"], form_headers(), body),
         {:ok, decoded} <- parse_success_json(status_code, response_body, :oauth_token),
         access_token when is_binary(access_token) <- decoded["access_token"] do
      expires_in = decoded["expires_in"] || 3600
      expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)
      {:ok, access_token, expires_at}
    else
      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :invalid_oauth_token_response}
    end
  end

  defp build_send_endpoint(credentials) do
    base_url = Keyword.get(config(), :base_url, "https://fcm.googleapis.com")
    project_id = credentials["project_id"]
    "#{base_url}/v1/projects/#{project_id}/messages:send"
  end

  defp build_send_body(device_token, notification, payload) do
    %{
      validate_only: false,
      message:
        %{
          token: device_token.token,
          data: Map.get(payload, :data, %{}),
          android: android_config(notification, payload),
          apns: apns_config(notification, payload),
          webpush: webpush_config(notification, payload),
          fcm_options: %{
            analytics_label: "notification_#{notification.id}"
          }
        }
        |> maybe_put(:notification, visible_notification(payload))
    }
  end

  defp visible_notification(payload) do
    if Map.get(payload, :silent, false) do
      nil
    else
      %{
        title: Map.get(payload, :title),
        body: Map.get(payload, :body)
      }
    end
  end

  defp android_config(notification, payload) do
    %{
      priority: if(Map.get(payload, :priority) == "normal", do: "NORMAL", else: "HIGH"),
      collapse_key: Map.get(payload, :collapse_key),
      notification:
        if(Map.get(payload, :silent, false),
          do: nil,
          else: %{
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            tag: Map.get(payload, :collapse_key),
            channel_id: channel_id(notification)
          }
        )
    }
    |> compact_map()
  end

  defp apns_config(_notification, payload) do
    aps =
      %{
        "content-available" => if(Map.get(payload, :silent, false), do: 1, else: nil),
        sound: if(Map.get(payload, :silent, false), do: nil, else: "default")
      }
      |> compact_map()

    %{
      headers: %{
        "apns-priority" => if(Map.get(payload, :priority) == "normal", do: "5", else: "10")
      },
      payload: %{
        "aps" => aps
      }
    }
  end

  defp webpush_config(_notification, payload) do
    %{
      headers: %{
        "Urgency" => if(Map.get(payload, :priority) == "normal", do: "normal", else: "high")
      },
      notification:
        if(Map.get(payload, :silent, false),
          do: nil,
          else: %{
            title: Map.get(payload, :title),
            body: Map.get(payload, :body)
          }
        ),
      fcm_options: %{
        link: Map.get(payload, :deep_link)
      }
    }
    |> compact_map()
  end

  defp channel_id(notification) do
    if Map.get(notification, :campaign_type) == "sponsored" do
      "universearch_sponsored"
    else
      "universearch_default"
    end
  end

  defp auth_headers(access_token) do
    [
      {~c"content-type", ~c"application/json"},
      {~c"authorization", String.to_charlist("Bearer #{access_token}")}
    ]
  end

  defp form_headers do
    [{~c"content-type", ~c"application/x-www-form-urlencoded"}]
  end

  defp http_post_json(url, headers, body) do
    http_post(url, headers, ~c"application/json", body)
  end

  defp http_post_form(url, headers, body) do
    http_post(url, headers, ~c"application/x-www-form-urlencoded", body)
  end

  defp http_post(url, headers, content_type, body) do
    request = {String.to_charlist(url), headers, content_type, body}
    ssl_options = ssl_options_for(url)

    options = [
      timeout: Keyword.get(config(), :recv_timeout_ms, 10_000),
      connect_timeout: Keyword.get(config(), :connect_timeout_ms, 5_000),
      ssl: ssl_options
    ]

    case :httpc.request(:post, request, options, body_format: :binary) do
      {:ok, {{_, status_code, _}, _response_headers, response_body}} ->
        {:ok, status_code, IO.iodata_to_binary(response_body)}

      {:error, reason} ->
        Logger.error("FCM v1 transport error", reason: inspect(reason))
        {:error, {:transport_error, reason}}
    end
  end

  defp ssl_options_for(url) do
    host =
      case URI.parse(url) do
        %URI{host: nil} -> "localhost"
        %URI{host: value} -> value
      end

    [
      versions: [:"tlsv1.2", :"tlsv1.3"],
      verify: :verify_peer,
      cacertfile: CAStore.file_path() |> String.to_charlist(),
      server_name_indication: String.to_charlist(host),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end

  defp parse_success_json(status_code, response_body, _context) when status_code in 200..299 do
    Jason.decode(response_body)
  end

  defp parse_success_json(status_code, response_body, _context) do
    {:error, classify_error(status_code, response_body)}
  end

  defp parse_send_response(status_code, response_body) when status_code in 200..299 do
    case Jason.decode(response_body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _reason} -> {:ok, %{raw: response_body}}
    end
  end

  defp parse_send_response(status_code, response_body) do
    error = classify_error(status_code, response_body)

    case error do
      {:retryable, _reason, _details} ->
        AccessTokenCache.invalidate()

      _ ->
        :ok
    end

    {:error, error}
  end

  defp classify_error(status_code, response_body) do
    decoded =
      case Jason.decode(response_body) do
        {:ok, json} -> json
        {:error, _reason} -> %{}
      end

    error = decoded["error"] || %{}
    details = List.wrap(error["details"])

    fcm_error_code =
      Enum.find_value(details, fn detail ->
        detail["errorCode"]
      end)

    status = error["status"] || fcm_error_code || Integer.to_string(status_code)
    message = error["message"] || response_body
    detail_payload = %{status_code: status_code, status: status, message: message, body: decoded}

    cond do
      status in ["UNREGISTERED"] ->
        {:invalid_token, status, detail_payload}

      status == "INVALID_ARGUMENT" and invalid_token_message?(message) ->
        {:invalid_token, status, detail_payload}

      status_code in [401, 429, 500, 503] or
          status in ["UNAUTHENTICATED", "UNAVAILABLE", "INTERNAL", "RESOURCE_EXHAUSTED"] ->
        {:retryable, status, detail_payload}

      true ->
        {:fatal, status, detail_payload}
    end
  end

  defp invalid_token_message?(message) do
    normalized = String.downcase(to_string(message))

    Enum.any?(
      ["registration token", "requested entity was not found", "invalid registration token"],
      &String.contains?(normalized, &1)
    )
  end

  defp build_jwt_assertion(credentials) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    header =
      %{
        "alg" => "RS256",
        "typ" => "JWT",
        "kid" => credentials["private_key_id"]
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into(%{})

    claims = %{
      "iss" => credentials["client_email"],
      "scope" => Keyword.get(config(), :scope, "https://www.googleapis.com/auth/firebase.messaging"),
      "aud" => credentials["token_uri"],
      "iat" => now,
      "exp" => now + 3600
    }

    encoded_header = base64url_json(header)
    encoded_claims = base64url_json(claims)
    unsigned_token = "#{encoded_header}.#{encoded_claims}"

    private_key = decode_private_key(credentials["private_key"])
    signature = :public_key.sign(unsigned_token, :sha256, private_key)

    unsigned_token <> "." <> Base.url_encode64(signature, padding: false)
  end

  defp decode_private_key(private_key_pem) do
    [pem_entry | _rest] =
      private_key_pem
      |> normalize_private_key_pem()
      |> :public_key.pem_decode()

    :public_key.pem_entry_decode(pem_entry)
  end

  defp normalize_private_key_pem(private_key_pem) do
    private_key_pem
    |> String.replace("\\n", "\n")
    |> String.trim()
  end

  defp base64url_json(map) do
    map
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp compact_map(map) do
    map
    |> Enum.reject(fn
      {_key, nil} -> true
      {_key, value} when is_map(value) -> map_size(value) == 0
      _ -> false
    end)
    |> Enum.into(%{})
  end

  defp config do
    Application.get_env(:notification_service, __MODULE__, [])
  end
end
