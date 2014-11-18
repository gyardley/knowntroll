class UserGenerator
  def as_json(id)
    @id = id
    {
      "id" => @id.to_i,
      "id_str" => @id.to_s,
      "name" => "Troll_" + @id.to_s,
      "screen_name" => "troll_" + @id.to_s,
      "location" => "",
      "profile_location" => nil,
      "description" => "The description of troll uid " + @id.to_s,
      "url" => nil,
      "entities" => {
        "description" =>{
          "urls" => [

          ]
        }
      },
      "protected" => false,
      "followers_count" => 1365,
      "friends_count" => 1803,
      "listed_count" => 76,
      "created_at" => "Thu Jun 05 20 =>40 =>37 +0000 2008",
      "favourites_count" => 762,
      "utc_offset" => -18000,
      "time_zone" => "Central Time (US & Canada)",
      "geo_enabled" => true,
      "verified" => false,
      "statuses_count" => 68889,
      "lang" => "en",
      "contributors_enabled" => false,
      "is_translator" => false,
      "is_translation_enabled" => false,
      "profile_background_color" => "C6E2EE",
      "profile_background_image_url" => "http:\/\/www.example.com\/bg.gif",
      "profile_background_image_url_https" => "https:\/\/www.example.com\/bg.gif",
      "profile_background_tile" => false,
      "profile_image_url" => "http:\/\/www.example.com\/profile.png",
      "profile_image_url_https" => "https:\/\/www.example.com\/profile.png",
      "profile_banner_url" => "https:\/\/www.example.com\/banner",
      "profile_link_color" => "1F98C7",
      "profile_sidebar_border_color" => "C6E2EE",
      "profile_sidebar_fill_color" => "DAECF4",
      "profile_text_color" => "663B12",
      "profile_use_background_image" => true,
      "default_profile" => false,
      "default_profile_image" => false,
      "following" => false,
      "follow_request_sent" => false,
      "notifications" => false,
      "muting" => false
    }
  end

end