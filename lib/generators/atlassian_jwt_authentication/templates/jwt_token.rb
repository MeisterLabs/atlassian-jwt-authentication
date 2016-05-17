class JwtToken < ActiveRecord::Base
  <% if database_name.present? %>
  databases = YAML::load(IO.read('config/database_<%= database_name %>.yml'))
  establish_connection databases[Rails.env]
  <% end %>

  has_many :jwt_users, dependent: :destroy
end
