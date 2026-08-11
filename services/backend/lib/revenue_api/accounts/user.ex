defmodule RevenueApi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @roles [:admin, :supervisor, :agent, :seller]

  schema "users" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true
    field :role, Ecto.Enum, values: @roles
    field :device_id, :string
    field :active, :boolean, default: true
    field :deleted_at, :utc_datetime

    belongs_to :lga, RevenueApi.Geo.Lga

    timestamps(type: :utc_datetime)
  end

  def roles, do: @roles

  @doc "Used by admin/user creation. Requires a password, hashes it, never stores it raw."
  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :phone, :password, :role, :lga_id, :device_id])
    |> validate_required([:name, :role, :password])
    |> validate_identifier_present()
    |> validate_inclusion(:role, @roles)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
    |> foreign_key_constraint(:lga_id)
    |> put_password_hash()
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :phone, :role, :lga_id, :device_id, :active])
    |> validate_required([:name, :role])
    |> validate_identifier_present()
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
    |> foreign_key_constraint(:lga_id)
  end

  defp validate_identifier_present(changeset) do
    email = get_field(changeset, :email)
    phone = get_field(changeset, :phone)

    if is_nil(email) and is_nil(phone) do
      add_error(changeset, :email, "email or phone is required")
    else
      changeset
    end
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = cs) do
    put_change(cs, :password_hash, Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
