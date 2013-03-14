#awis-wrapper

This is the wrapper for AWIS service, this thought derive from Ishango2 project.

##Usage

```ruby
  Amazon::Awis.options = {:aws_access_key_id => "123", :aws_secret_key => "456", :action => "UrlInfo", :responsegroup => "RankByCountry"}

  #Or with one block
  Amazon::Awis.configure do |options|
      # options[:aws_access_key_id] = [your access key]
      # options[:aws_secret_key] = [you secret key]
      options[:responsegroup] = 'Rank'
  end

  #Call get_info method to get website info
  res = Amazon::Awis.get_info('yahoo.com')
  if res.success? 
    all_countries = res.get_all('country')
    all_countries.each do |c|
      c.contribution.first.users.first
    end
  end
```

## Contributing to awis-wrapper
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2013 Vincent.Z. See LICENSE.txt for
further details.

