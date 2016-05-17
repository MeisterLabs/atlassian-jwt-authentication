class JwtUser < ActiveRecord::Base
  belongs_to :jwt_token

  <% if database_name.present? %>
  databases = YAML::load(IO.read('config/database_<%= database_name %>.yml'))
  establish_connection databases[Rails.env]
  <% end %>
end