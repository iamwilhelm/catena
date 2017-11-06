require 'funkify'

module Catena
  module Lang
    include Funkify

    # we add the class methods to the base class so they don't have to.
    def self.included(base_mod)
      base_mod.extend ClassMethods
    end

    module ClassMethods
      def def_task(task_name, &block)
        self.class_eval do
          # define the language func that creates bind task nodes
          define_method(task_name) do |*args|
            bind(__method__, *args)
          end

          callback_name = Lang.func_name_to_callback(task_name)
          define_method(callback_name, &block)
        end
      end
    end

    # Helper functions

    def self.callback_to_func_name(callback_name)
      # strip the "__"
      callback_name[2..-1]
    end

    def self.func_name_to_callback(func_name)
      "__#{func_name}"
    end

    # basic tasks and their composition that return task nodes

    def succeed(value)
      {
        "type" => "succeed",
        "value" => value
      }
    end

    def failure(error)
      {
        "type" => "failure",
        "error" => error
      }
    end

    # bind(callback_name, arg1, arg2, ...)
    def bind(*args)
      raise "Need at least callback_name" if args.length < 1
      func_name = args[0]
      func_args = args[1..-1] || []
      {
        "type" => "binding",
        "callback_name" => Lang.func_name_to_callback(func_name),
        "callback_args" => func_args,
        "cancel" => nil,
      }
    end

    auto_curry def and_then(bind_efx, efx_a)
      binding_callback = bind_efx.is_a?(Symbol) ? bind(bind_efx) : bind_efx
      raise "bind_efx needs to be a binding" if binding_callback["type"] != "binding"

      {
        "type" => "and_then",
        "side_effect" => efx_a,
        "binding_callback" => binding_callback,
      }
    end

    auto_curry def on_error(bind_efx, efx_a)
      binding_callback = bind_efx.is_a?(Symbol) ? bind(bind_efx) : bind_efx
      raise "bind_efx needs to be a binding" if binding_callback["type"] != "binding"

      {
        "type" => "on_error",
        "side_effect" => efx_a,
        "binding_callback" => binding_callback,
      }
    end

    # TODO We have #map2 to fan-in, but we don't have something that fans out
    # example. We create an application space, but then need to upload two
    # ml files to the space, and use the results to map into create_flask_app

    auto_curry def map2(bind_efx, efx_b, efx_a)
      binding_callback = bind_efx.is_a?(Symbol) ? bind(bind_efx) : bind_efx
      raise "bind_efx needs to be a binding" if binding_callback["type"] != "binding"

      pass(efx_a) >=
        and_then(bind(:map2_a, binding_callback, efx_b))
    end

    # This only works because we're filling in all other args except val_a
    auto_curry def __map2_a(bind_efx, efx_b, val_a, evaluator)
      new_efx = pass(efx_b) >=
        and_then(bind(:map2_b, bind_efx, val_a))

      evaluator.call(new_efx)
    end

    auto_curry def __map2_b(bind_efx, val_a, val_b, evaluator)
      # update binding to have val_a and val_b as arguments
      func_name = Lang.callback_to_func_name(bind_efx["callback_name"])
      args = bind_efx["callback_args"] + [val_a, val_b]
      new_efx = bind(func_name, *args)

      evaluator.call(new_efx)
    end

    auto_curry def smap(bind_efx, efxs)
      self.send("map#{efxs.length}", bind_efx, *efxs.reverse)
    end

    # Unused. Sample usage
    #  pass([store_to_cloud("arch.hdf5"), store_to_cloud("model.hdf5")]) >=
    #    pmap(:tag_docker_image)
    auto_curry def pmap(callback_name, efxs)
      {
        "type" => "pmap",
        "side_effects" => efxs,
        "serialized_callback" => "__#{callback_name}",
      }
    end

  end
end
