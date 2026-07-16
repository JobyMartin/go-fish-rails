
Data::Country = Data.define(:id, :name, :states) do
  include DataFor::Model
  config :countries
end
