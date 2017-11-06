# What is Catena?

Catena lets you define chainable background tasks using `and_then` and `map` semantics as glue between tasks. These background tasks get sent to sidekiq, and get executed. Since `and_then` and `map` take care of the sequencing, your background tasks can stay modular, and you have the flexibility of changing your business process around easily.

# Setup for Catena

If not using as a gem, will need to add to your autoload paths in `config/application.rb`.

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

#  Usage

## Defining tasks

Inside of `app/deployment`, create `procedure.rb` or any other grouping of
tasks you see fit.

To give you a taste, you can define tasks like so:

      def_task(:docker_build_image) do |project_id, evaluator|
        project_path = convert_project_id_to_path(project_id)
        image = Docker::Image.build_from_dir(project_path, { 'dockerfile' => "Dockerfile" })
        evaluator.call(succeed(image.id))
      end
    
      def_task(:docker_tag_image) do |project_id, docker_image_id, evaluator|
        image = Docker::Image.get(docker_image_id)
        image.tag("repo" => "iamwil/helmspointapp-#{project_id}", "tag" => "latest")
        evaluator.call(succeed(docker_image_id))
      end

And chain multiple tasks together, with map and and_then semantics, which the chained tasks is itself a task:

       task = pass(docker_create_dockerfile(project_id)) >=
          and_then(:docker_build_image) |
          and_then(bind(:docker_tag_image, project_id)) |
          and_then(bind(:docker_push_image, project_id))

docker_build_image task returns the docker image id, which gets passed into docker_tag_image as its second argument. docker_tag_image is curried, so its first argument is already filled.

## Performing the task

```
Catena.perform(task)
```

which sends it to Sidekiq to execute. The chained task will interleave the smallest unit of work with other running chained tasks. 
