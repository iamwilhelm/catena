## Setup for Catena

If not using as a gem, will need to add to your autoload paths.

```
config.autoload_paths += %W(
  #{config.root}/lib/catena/lib
)
```

Add a directory for the procedures and tasks. `app/deployment` will do. Add the
directory to `config/application.rb`

```
config.autoload_paths += %W(
  #{config.root}/app/deployment
  #{config.root}/app/deployment/task
)
```

Create `config/initializers/sidekiq.rb`
```
require "catena"
require "procedure"

Sidekiq.configure_server do |config|
  config.redis = {}
end

Sidekiq.configure_server do |config|
  config.redis = {}
end

Catena.configure do |config|
  config.modules = [Deployment::Procedure]
end
```

Inside of `app/deployment`, create `procedure.rb` or any other grouping of
tasks you see fit.

```
Write tasks and custom tasks in app/deployment/procedure.rb
Write tasks and custom tasks in app/deployment/task.rb
```

Compose tasks

Then when task is ready to be performed

Catena.perform(new_task)
