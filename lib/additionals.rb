module Additionals
  MAX_CUSTOM_MENU_ITEMS = 5

  class << self
    def settings
      ActionController::Parameters.new(Setting[:plugin_additionals])
    end

    def setting?(value)
      return true if settings[value].to_i == 1
    end

    def incompatible_plugins(plugins = [], title = 'additionals')
      plugins.each do |plugin|
        if Redmine::Plugin.installed?(plugin)
          raise "\n\033[31m#{title} plugin cannot be used with #{plugin} plugin'.\033[0m"
        end
      end
    end

    def patch(patches = [], plugin_id = 'additionals')
      patches.each do |name|
        patch_dir = Rails.root.join('plugins', plugin_id, 'lib', plugin_id, 'patches')
        require "#{patch_dir}/#{name.underscore}_patch"

        target = name.constantize
        patch = "#{plugin_id.camelize}::Patches::#{name}Patch".constantize

        unless target.included_modules.include?(patch)
          target.send(:include, patch)
        end
      end
    end

    def load_macros(macros = [], plugin_id = 'additionals')
      macro_dir = Rails.root.join('plugins', plugin_id, 'lib', plugin_id, 'wiki_macros')
      macros.each do |macro|
        require_dependency "#{macro_dir}/#{macro.underscore}_macro"
      end
    end

    def load_settings(plugin_id = 'additionals')
      data = YAML.safe_load(ERB.new(IO.read(Rails.root.join('plugins',
                                                            plugin_id,
                                                            'config',
                                                            'settings.yml'))).result) || {}
      data.symbolize_keys
    end

    def load_fontawesome_icons
      data = YAML.safe_load(ERB.new(IO.read(Rails.root.join('plugins',
                                                            'additionals',
                                                            'config',
                                                            'fontawesome_icons.yml'))).result) || {}
      data['icons']
    end
  end
end

if ActiveRecord::Base.connection.table_exists?(:settings)
  Rails.configuration.to_prepare do
    require 'pry' if ENV['ENABLE_DEBUG']
    Additionals.incompatible_plugins(%w[redmine_tweaks common_libraries redmine_editauthor redmine_changeauthor redmine_auto_watch])
    Additionals.patch(%w[AccountController
                         Issue
                         IssuesController
                         TimeEntry
                         Wiki
                         WikiController
                         UserPreference
                         ApplicationController])

    Additionals.patch(%w[QueryFilter]) if Redmine::VERSION.to_s >= '3.4'

    Rails.configuration.assets.paths << Emoji.images_path
    # Send Emoji Patches to all wiki formatters available to be able to switch formatter without app restart
    Redmine::WikiFormatting.format_names.each do |format|
      case format
      when 'markdown'
        require_dependency 'additionals/patches/formatter_markdown_patch'
      when 'textile'
        require_dependency 'additionals/patches/formatter_textile_patch'
      end
    end

    # Static class patches
    require_dependency 'additionals/patches/wiki_pdf_helper_patch'
    require_dependency 'additionals/patches/access_control_patch'

    # Global helpers
    require_dependency 'additionals/helpers'

    # Hooks
    require_dependency 'additionals/hooks'

    # Macros
    Additionals.load_macros(%w[calendar cryptocompare date gist group_users issue last_updated_at
                               last_updated_by member project recently_updated reddit slideshare
                               tradingview twitter user vimeo youtube])
  end

  # include deface overwrites
  Rails.application.paths['app/overrides'] ||= []
  additionals_overwrite_dir = "#{Redmine::Plugin.directory}/additionals/app/overrides".freeze
  unless Rails.application.paths['app/overrides'].include?(additionals_overwrite_dir)
    Rails.application.paths['app/overrides'] << additionals_overwrite_dir
  end
end
