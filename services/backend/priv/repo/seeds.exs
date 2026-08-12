# Run with: mix run priv/repo/seeds.exs
#
# Seeds the full 36-states-plus-FCT list (name + code only — real, verified
# names, not placeholders) so every registration-form state picker has a
# complete list from day one. Only Lagos State gets a full LGA/ward/market
# tree, matching the spec's own worked example (`LAG-IKJ-2026-000012`).
# Adding another state's LGA/ward/market tree is adding rows to the lists
# below, not writing code — see specs/mvp_design.md.

alias RevenueApi.Repo
alias RevenueApi.Geo.{State, Lga, Ward, Market}
alias RevenueApi.Accounts.User
alias RevenueApi.Levies.LevyType

# `on_conflict: :nothing` skips the write on a conflict, but Postgres's
# `RETURNING` clause then has no row to return, so a plain `Repo.insert!`
# would come back with `id: nil` on every re-run after the first. Using
# `on_conflict: {:replace, replace_fields}` instead makes it a real (if
# no-op) UPDATE on conflict, so RETURNING always yields the live row —
# this is what makes the seed script safe to run repeatedly.
upsert = fn struct, changes, conflict_target, replace_fields ->
  struct
  |> Ecto.Changeset.change(changes)
  |> Repo.insert!(
    on_conflict: {:replace, replace_fields},
    conflict_target: conflict_target,
    returning: true
  )
end

states = [
  {"Abia", "ABI"},
  {"Adamawa", "ADA"},
  {"Akwa Ibom", "AKW"},
  {"Anambra", "ANA"},
  {"Bauchi", "BAU"},
  {"Bayelsa", "BAY"},
  {"Benue", "BEN"},
  {"Borno", "BOR"},
  {"Cross River", "CRO"},
  {"Delta", "DEL"},
  {"Ebonyi", "EBO"},
  {"Edo", "EDO"},
  {"Ekiti", "EKI"},
  {"Enugu", "ENU"},
  {"Federal Capital Territory", "FCT"},
  {"Gombe", "GOM"},
  {"Imo", "IMO"},
  {"Jigawa", "JIG"},
  {"Kaduna", "KAD"},
  {"Kano", "KAN"},
  {"Katsina", "KAT"},
  {"Kebbi", "KEB"},
  {"Kogi", "KOG"},
  {"Kwara", "KWA"},
  {"Lagos", "LAG"},
  {"Nasarawa", "NAS"},
  {"Niger", "NIG"},
  {"Ogun", "OGU"},
  {"Ondo", "OND"},
  {"Osun", "OSU"},
  {"Oyo", "OYO"},
  {"Plateau", "PLA"},
  {"Rivers", "RIV"},
  {"Sokoto", "SOK"},
  {"Taraba", "TAR"},
  {"Yobe", "YOB"},
  {"Zamfara", "ZAM"}
]

state_records =
  Enum.map(states, fn {name, code} ->
    upsert.(%State{}, %{name: name, code: code}, [:code], [:name])
  end)

lagos = Enum.find(state_records, &(&1.code == "LAG"))

lagos_lgas = [
  {"Agege", "AGE"},
  {"Ajeromi-Ifelodun", "AJE"},
  {"Alimosho", "ALI"},
  {"Amuwo-Odofin", "AMU"},
  {"Apapa", "APA"},
  {"Badagry", "BAD"},
  {"Epe", "EPE"},
  {"Eti-Osa", "ETI"},
  {"Ibeju-Lekki", "IBE"},
  {"Ifako-Ijaiye", "IFA"},
  {"Ikeja", "IKJ"},
  {"Ikorodu", "IKO"},
  {"Kosofe", "KOS"},
  {"Lagos Island", "LIS"},
  {"Lagos Mainland", "LMA"},
  {"Mushin", "MUS"},
  {"Ojo", "OJO"},
  {"Oshodi-Isolo", "OSH"},
  {"Somolu", "SOM"},
  {"Surulere", "SUR"}
]

lga_records =
  Enum.map(lagos_lgas, fn {name, code} ->
    upsert.(%Lga{}, %{name: name, code: code, state_id: lagos.id}, [:state_id, :code], [:name])
  end)

ikeja = Enum.find(lga_records, &(&1.code == "IKJ"))

ikeja_wards = [
  "Anifowoshe/Ikeja",
  "Ojodu/Agidingbi/Omole",
  "Alausa/Oregun/Olusosun",
  "Airport/Onipetesi/Onilekere",
  "Ipodo/Seriki Aro",
  "Adekunle Village/Adeniyi Jones/Ogba",
  "Oke-Ira/Aguda",
  "Onigbongbo/Military Cantonment",
  "GRA/Police Barracks",
  "Wasimi/Opebi/Allen"
]

ward_records =
  Enum.map(ikeja_wards, fn name ->
    upsert.(%Ward{}, %{name: name, lga_id: ikeja.id}, [:lga_id, :name], [:name])
  end)

anifowoshe = Enum.find(ward_records, &(&1.name == "Anifowoshe/Ikeja"))
alausa = Enum.find(ward_records, &(&1.name == "Alausa/Oregun/Olusosun"))

markets = [
  {"Computer Village Market", anifowoshe},
  {"Alausa Market", alausa}
]

market_records =
  Enum.map(markets, fn {name, ward} ->
    upsert.(%Market{}, %{name: name, ward_id: ward.id}, [:ward_id, :name], [:name])
  end)

computer_village = Enum.find(market_records, &(&1.name == "Computer Village Market"))

# --- Levy types (Ikeja LGA) ---
levy_types = [
  %{name: "Daily Trading Levy", amount: Decimal.new("500.00"), frequency: :daily},
  %{name: "Signage & Advertisement Permit", amount: Decimal.new("15000.00"), frequency: :one_off},
  %{name: "Monthly Shop Rate", amount: Decimal.new("3500.00"), frequency: :monthly}
]

Enum.each(levy_types, fn attrs ->
  # levy_types' uniqueness is a partial index (WHERE deleted_at IS NULL),
  # which ON CONFLICT can't target directly — check-then-insert instead.
  unless Repo.get_by(LevyType, lga_id: ikeja.id, name: attrs.name) do
    %LevyType{}
    |> LevyType.changeset(Map.put(attrs, :lga_id, ikeja.id))
    |> Repo.insert!()
  end
end)

# --- Demo users ---
# Dev-only credentials, printed below. Never reuse these outside local dev.
demo_password = "ChangeMe123!"

demo_users = [
  %{
    name: "State Admin",
    email: "admin@revenue.test",
    role: :admin,
    lga_id: nil,
    password: demo_password
  },
  %{
    name: "Ikeja Supervisor",
    email: "supervisor.ikeja@revenue.test",
    role: :supervisor,
    lga_id: ikeja.id,
    password: demo_password
  },
  %{
    name: "Ikeja Agent",
    email: "agent.ikeja@revenue.test",
    role: :agent,
    lga_id: ikeja.id,
    password: demo_password
  }
]

Enum.each(demo_users, fn attrs ->
  unless Repo.get_by(User, email: attrs.email) do
    %User{}
    |> User.create_changeset(attrs)
    |> Repo.insert!()
  end
end)

IO.puts("""

Seeded #{length(state_records)} states, #{length(lga_records)} Lagos LGAs,
#{length(ward_records)} Ikeja wards, #{length(market_records)} markets,
#{length(levy_types)} levy types, #{length(demo_users)} demo users.

Demo logins (password for all: #{demo_password}):
  admin@revenue.test          (state admin)
  supervisor.ikeja@revenue.test (Ikeja supervisor)
  agent.ikeja@revenue.test      (Ikeja agent)

Computer Village Market id: #{computer_village.id} (use for test seller registrations)
""")
