defmodule RevenueApiWeb.ReceiptController do
  use RevenueApiWeb, :controller

  alias RevenueApi.{Receipts, Payments, Storage}

  action_fallback RevenueApiWeb.FallbackController

  def pdf(conn, %{"id" => id}) do
    with %Receipts.Receipt{} = receipt <- Receipts.get(id) || {:error, :not_found},
         %{} = payment <- Payments.get_payment(receipt.payment_id) || {:error, :not_found},
         :ok <- authorize(current_user(conn), payment),
         key when not is_nil(key) <- receipt.pdf_url || {:error, :not_ready},
         {:ok, binary} <- Storage.fetch(key) do
      conn
      |> put_resp_content_type("application/pdf")
      |> send_resp(200, binary)
    end
  end

  defp authorize(%{role: role}, _payment) when role in [:admin, :supervisor], do: :ok
  defp authorize(%{role: :agent, id: id}, %{agent_id: id}), do: :ok
  defp authorize(_user, _payment), do: {:error, :forbidden}
end
