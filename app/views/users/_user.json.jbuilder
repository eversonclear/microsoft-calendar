json.(
  user, 
  :google_token,
  :azure_token,
  :azure_expire_token,
  :azure_refresh_token,
  :id, 
  :email, 
  :first_name, 
  :last_name
)
json.token user.generate_jwt