json.array!(@posts) do |post|
  json.extract! post, :id, :text
  json.url post_url(post, format: :json)
end
