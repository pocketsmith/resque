source "https://rubygems.org"

gemspec

# production parity (pocketsmith Gemfile.lock): redis 5.x breaks resque 1.27's
# client construction, and tests should exercise what production runs anyway.
gem 'redis', '~> 4.2.0'
gem 'redis-namespace', '~> 1.11.0'

gem "activesupport", "~> 3.0"
gem "i18n"

if RUBY_VERSION < "2.0"
  gem "json", '~> 1.8'
  gem "coveralls", "0.8.13", :require => false
  gem "term-ansicolor", "1.3.2" # A dependency of coveralls. The next version requires ruby >= 2.0.
else
  gem "json"
  gem "coveralls", :require => false
end

gem "minitest", "4.7.0"
gem "mocha", :require => false
gem "rack-test", "~> 0.5"
gem "rake"
gem "pry"
