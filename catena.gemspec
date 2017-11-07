Gem::Specification.new do |s|
  s.name = 'catena'
  s.version = '0.0.2'
  s.date = '2017-11-06'
  s.summary = 'Chainable background tasks'
  s.description = 'Catena lets you write and compose background tasks in a flexible way to model business processes'
  s.authors = ["Wil Chung"]
  s.email = "iamwil@gmail.com"
  s.files = Dir.glob("lib/**/*.rb")
  s.homepage = "https://github.com/iamwilhelm/catena"
  s.license = "MIT"
  s.add_runtime_dependency "funkify", ["~> 0.0.4"]
  s.add_runtime_dependency "sidekiq", ["~> 5.0"]
  s.add_runtime_dependency "redis-namespace", ["~> 1.5"]
end