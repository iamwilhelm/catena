require_relative 'lang'
require 'sidekiq'

module Catena
  class Scheduler
    include Lang
    include Sidekiq::Worker

    MAX_STEPS = 10

    def perform(efx, stack)
      step(efx, stack, 0)
    end

    def step(efx, stack, steps)
      if (steps > MAX_STEPS)
        logger.warn "Exceeded MAX STEPS. Stowing efx #{efx}"
        enqueue(efx, stack)
        steps
      else
        # TODO if not use >= after pass, will have efx["type"] is nil, need error message
        # TODO if has trailing "|" in chain, it'll subsume the evaluator call, and return nil
        # TODO also need error message when argument length mismatches
        logger.debug "EFX: #{efx.inspect}"
        send("step_#{efx["type"]}", efx, stack, steps)
      end
    end

    def step_succeed(efx, stack, steps)
      logger.debug "Processing succeed: #{efx}. Stack.len = #{stack.length}"
      new_stack = flush("on_error", stack)
      logger.debug "  Flushed on_error. Stack.len = #{new_stack.length}"

      if new_stack.empty?
        return steps
      else
        and_then_node = new_stack.pop()
        callback_node = and_then_node["binding_callback"] # the callback node is type binding
        logger.debug "  Popped #{callback_node}. Stack.len = #{new_stack.length}"

        new_efx = chain(callback_node, efx["value"])
        raise "step_succeed new_efx is nil. succeed value: #{efx["value"]}" if new_efx.nil?
        step(new_efx, new_stack, steps + 1)
      end
    end

    def step_failure(efx, stack, steps)
      logger.info "Processing failure: #{efx}. Stack.len = #{stack.length}"
      new_stack = flush("and_then", stack)
      #puts "  Flushed and_then. Stack.len = #{new_stack.length}"

      if new_stack.empty?
        return steps
      else
        on_error_node = new_stack.pop()
        callback_node = on_error_node["binding_callback"]
        logger.debug "  Popped #{callback_node}. Stack.len = #{new_stack.length}"

        new_efx = chain(callback_node, efx["error"])
        raise "step_failure new_efx is nil. failure value: #{efx["error"]}" if new_efx.nil?
        step(new_efx, new_stack, steps + 1)
      end
    end

    def step_binding(efx, stack, steps)
      # TODO canceling the entire process should happen at binding
      logger.info "Processing binding of #{efx["callback_name"]}"

      # FIXME shouldn't need to know explicitly the tasks are on Deployment class

      callback = find_callback(efx["callback_name"])
      args = efx["callback_args"] + [evaluator(stack)]
      logger.debug "  Calling '#{efx["callback_name"]}' with args: #{args.inspect}"

      # FIXME check the arity and note if we're short?
      # if we're at the end, and we're short on arguments, it'll happyly execute,
      # return a lambda, and silently finish
      callback.call(*args)

      return steps + 1
    end

    def step_and_then(efx, stack, steps)
      new_stack = stack.push(efx)
      logger.info "Processing and_then. Stack.len = #{new_stack.length}"

      raise "step_and_then new_efx is nil" if efx["side_effect"].nil?
      step(efx["side_effect"], new_stack, steps + 1)
    end

    def step_on_error(efx, stack, steps)
      logger.warn "Processing on_error...not implemented"
      return steps
    end

    def step_pmap(efx, stack, steps)
      logger.warn "Processing parallel map...not implemented"
      return steps
    end

    #######################

    private

    # TODO should raise if callback isn't found
    def find_callback(name)
      mod_with_callback = Catena.config.modules.find do |mod|
        mod = mod.is_a?(String) ? class_from_name(mod) : mod
        mod.respond_to?(name)
      end
      return mod_with_callback.method(name)
    end

    def class_from_name()
      mod_name.split("::").inject(Object) do |mod, class_name|
        mod.const_get(class_name)
      end
    end

    def enqueue(efx, stack)
      logger.debug "Enqueued bound_efx: #{efx}"
      Scheduler.perform_async(efx, stack)
    end

    def flush(node_type, stack)
      stack.reject { |node| node["type"] == node_type }
    end

    # create another binding with the added efx["value"], and
    # send it through a new step.
    # while we can use funkify to partially apply, it doesn't work here, because
    # we need to serialize it, and so we delay execution by creating another bind
    # step through.
    #
    # same as calling the func that returns bind in Task
    # TODO should use that so don't have to include Interpreter?
    #      But then still have to solve the problem of knowing about Deployment in step_binding
    # TODO maybe just destructively update binding_callbcak with new value in args?
    def chain(callback_node, value_or_error)
      func_name = Lang.callback_to_func_name(callback_node["callback_name"])
      args = callback_node["callback_args"] + [value_or_error]
      return bind(func_name, *args)
    end

    def evaluator(stack)
      lambda { |result_efx|
        # FIXME need to check if result_efx is nil and then throw
        # - Do you have a trailing "|"?
        # FIXME need to check if result_efx is actually an efx
        logger.info "Enqueuing result for evaluation"
        logger.debug "  result: #{result_efx}"
        enqueue(result_efx, stack)
      }
    end

  end
end
