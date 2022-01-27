# typed: ignore

require 'datadog/core/utils/only_once'

require 'datadog/security/contrib/patcher'
require 'datadog/security/contrib/rails/integration'
require 'datadog/security/contrib/rails/framework'
require 'datadog/security/contrib/rack/request_middleware'

require 'ddtrace/contrib/rack/middlewares'

module Datadog
  module Security
    module Contrib
      module Rails
        # Patcher for Security on Rails
        module Patcher
          include Datadog::Security::Contrib::Patcher

          BEFORE_INITIALIZE_ONLY_ONCE_PER_APP = Hash.new { |h, key| h[key] = Datadog::Core::Utils::OnlyOnce.new }
          AFTER_INITIALIZE_ONLY_ONCE_PER_APP = Hash.new { |h, key| h[key] = Datadog::Core::Utils::OnlyOnce.new }

          module_function

          def patched?
            Patcher.instance_variable_get(:@patched)
          end

          def target_version
            Integration.version
          end

          def patch
            patch_before_intialize
            patch_after_intialize

            Patcher.instance_variable_set(:@patched, true)
          end

          def patch_before_intialize
            ::ActiveSupport.on_load(:before_initialize) do
              Datadog::Security::Contrib::Rails::Patcher.before_intialize(self)
            end
          end

          def before_intialize(app)
            BEFORE_INITIALIZE_ONLY_ONCE_PER_APP[app].run do
              # Middleware must be added before the application is initialized.
              # Otherwise the middleware stack will be frozen.
              # Sometimes we don't want to activate middleware e.g. OpenTracing, etc.
              add_middleware(app) if Datadog::Tracing.configuration[:rails][:middleware]
            end
          end

          def add_middleware(app)
            # Add trace middleware
            if include_middleware?(Datadog::Contrib::Rack::TraceMiddleware, app)
              app.middleware.insert_after(Datadog::Contrib::Rack::TraceMiddleware, Datadog::Security::Contrib::Rack::RequestMiddleware)
            else
              app.middleware.insert_before(0, Datadog::Security::Contrib::Rack::RequestMiddleware)
            end
          end

          def include_middleware?(middleware, app)
            found = false

            # find tracer middleware reference in Rails::Configuration::MiddlewareStackProxy
            app.middleware.instance_variable_get(:@operations).each do |operation|
              # we can't introspect the actual operation not being a delete but it's unlikely
              if operation.binding.local_variable_get(:args).include?(middleware)
                found = true
              end
            end

            found
          end

          def inspect_middlewares(app)
            Datadog.logger.debug { 'Rails middlewares: ' << app.middleware.map(&:inspect).inspect }
          end

          def patch_after_intialize
            ::ActiveSupport.on_load(:after_initialize) do
              Datadog::Security::Contrib::Rails::Patcher.after_intialize(self)
            end
          end

          def after_intialize(app)
            AFTER_INITIALIZE_ONLY_ONCE_PER_APP[app].run do
              # Finish configuring the tracer after the application is initialized.
              # We need to wait for some things, like application name, middleware stack, etc.
              setup_security
              inspect_middlewares(app)
            end
          end

          def setup_security
            Datadog::Security::Contrib::Rails::Framework.setup
          end
        end
      end
    end
  end
end
