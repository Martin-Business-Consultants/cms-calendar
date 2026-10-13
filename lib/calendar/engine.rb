# frozen_string_literal: true

module Calendar
  # A CMS plugin (docs/plugins.md): it extends the core only through
  # Cms::Plugins, and the core never names it. It reads Market (cms-market),
  # Google (cms-google) and the AI plugin (cms-ai) when they're on, and works
  # without them.
  class Engine < ::Rails::Engine
    initializer "calendar.migrations" do |app|
      config.paths["db/migrate"].expanded.each { |path| app.config.paths["db/migrate"] << path }
    end

    initializer "calendar.routes" do |app|
      app.routes.append do
        admin = proc do
          get "calendar", to: "calendar/items#index", as: :calendar
          scope "calendar", module: "calendar", as: "calendar" do
            resources :items, except: [:index, :show] do
              resource :schedule, only: [:create, :destroy], controller: "items/schedules"
              resource :draft, only: :create, controller: "items/drafts"
              resource :record, only: :create, controller: "items/records"
              resource :dispatch, only: :create, controller: "items/dispatches"
            end
            resources :ideas, only: [:index, :create]
            resources :plans, only: :create
          end

          scope "settings", as: "settings" do
            resource :calendar, only: [:show, :update], controller: "calendar/settings" do
              get "connect/:network", to: "calendar/connections#new", as: :connect
              get "callback/:network", to: "calendar/connections#show", as: :callback
              resources :channels, only: :destroy, controller: "calendar/channels"
            end
          end
        end
        defined?(Cms::PATH) ? scope(path: Cms::PATH, &admin) : admin.call

        scope "api", defaults: {format: :json} do
          scope "calendar", module: "calendar/api", as: "api_calendar" do
            resources :items, only: [:index, :show, :create, :update, :destroy] do
              resource :schedule, only: [:create, :destroy], controller: "schedules"
              resource :draft, only: :create, controller: "drafts"
            end
            resources :channels, only: :index
            resources :ideas, only: [:index, :create]
            resources :plans, only: :create
          end
        end
      end
    end

    config.to_prepare do
      Cms::Plugins.register :calendar, name: "Calendar", version: Calendar::VERSION, author: "Martin Business Consultants",
        enabled_by_default: false, requires: ">= 1.32", homepage: "https://github.com/Martin-Business-Consultants/cms-calendar",
        description: "A content calendar: posts and pages on the site and social posts to Facebook, Instagram, LinkedIn, X and the " \
                     "Google Business Profile, planned from Market, drafted per channel by the AI, and sent when they're due."

      Cms::Plugins.menu :calendar, :calendar, label: "Calendar", icon: "calendar", group: "Content", after: [:market, :leads, :forms, :globals],
        path: -> { calendar_path }, capability: "calendar:read"
      Cms::Plugins.submenu :calendar, :calendar, label: "Calendar", path: -> { calendar_path }, capability: "calendar:read"
      Cms::Plugins.submenu :calendar, :calendar, label: "Ideas", path: -> { calendar_ideas_path }, capability: "calendar:read", after: "Calendar"
      Cms::Plugins.submenu :calendar, :calendar, label: "Channels", path: -> { settings_calendar_path }, capability: "settings:read", after: "Ideas"
      Cms::Plugins.new_item :calendar, label: "Calendar item", path: -> { new_calendar_item_path }, capability: "calendar:write"

      Cms::Plugins.permissions :calendar, "Calendar", %w[calendar:read calendar:write calendar:publish],
        after: ["Market", "Leads", "Forms", "Globals"],
        defaults: {editor: %w[calendar:read calendar:write calendar:publish], author: %w[calendar:read calendar:write], agent: %w[calendar:read calendar:write]}
      Cms::Plugins.settings :calendar, "Calendar", -> { settings_calendar_path },
        description: "The Meta, LinkedIn and X apps posts go out through, the channels connected, and how social posts should read.",
        capability: "settings:read"
      Cms::Plugins.stylesheet :calendar, "calendar/calendar"
      Cms::Plugins.minutely :calendar, :dispatch, -> { Calendar::DispatchJob.perform_later if Calendar::Item.due.exists? || Calendar::Item.where(state: "sending").exists? }
      Cms::Plugins.counts :calendar, scheduled: -> { Calendar::Item.where(state: "scheduled").count }

      Cms::Plugins.api :calendar, "/api/calendar/items",
        description: "The calendar: items between ?from and ?to (ISO dates), each with its kind (social, post, page, note), state (idea, draft, scheduled, sending, published, failed), " \
                     "when, body, link, image, record and deliveries (channel, text, state, address, error). Create, update, delete (calendar:write); " \
                     "POST /api/calendar/items/:id/schedule {\"at\":ISO time} schedules it (calendar:publish), DELETE unschedules; POST /api/calendar/items/:id/draft has the AI write each channel's text."
      Cms::Plugins.api :calendar, "/api/calendar/channels", description: "The social channels connected: network, name, handle, state."
      Cms::Plugins.api :calendar, "/api/calendar/ideas", description: "What to put on the calendar from Market and Google; POST {\"source\":…,\"at\":ISO date} adds one as an idea."
      Cms::Plugins.api :calendar, "/api/calendar/plans", description: "POST {\"from\",\"to\",\"per_week\"}: the AI plans that stretch as ideas, from Market's plan and Google's searches (a minute or so)."
    end
  end
end
