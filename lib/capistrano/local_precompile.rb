require 'capistrano'

module Capistrano
  module LocalPrecompile

    def self.load_into(configuration)
      configuration.load do

        set(:precompile_cmd)   { "#{fetch(:bundle_cmd, "bundle")} exec rake assets:precompile" }
        set(:cleanexpired_cmd) { "#{fetch(:bundle_cmd, "bundle")} exec rake assets:clean_expired" }
        set(:assets_dir)       { "public/assets" }

        set(:turbosprockets_enabled)    { false }
        set(:turbosprockets_backup_dir) { "public/.assets" }
        set(:rsync_cmd)                 { "rsync -av" }

        before "deploy:assets:precompile", "deploy:assets:prepare"
        after "deploy:assets:precompile", "deploy:assets:cleanup"

        def with_envs(envs)
          saved = {}
          envs.each do |name, value|
            saved[name], ENV[name] = ENV[name], value
          end
          yield
        ensure
          saved.each do |name, value|
            ENV[name] = value
          end
        end

        def run_cmd(cmd)
          envs = { 'BUNDLE_BIN_PATH' => '',
                   'BUNDLE_GEMFILE' => '',
                   'GEM_HOME' => '',
                   'GEM_PATH' => '', }
          with_envs(envs) do
            cd_app_dir = "cd #{fetch(:app_dir)} && " if fetch(:app_dir)
            run_locally "/bin/bash -l -c '#{cd_app_dir}#{cmd}'"
          end
        end

        namespace :deploy do
          namespace :assets do

            task :cleanup, :on_no_matching_servers => :continue  do
              if fetch(:turbosprockets_enabled)
                run_cmd "mv #{fetch(:assets_dir)} #{fetch(:turbosprockets_backup_dir)}"
              else
                run_cmd "rm -rf #{fetch(:assets_dir)}"
              end
            end

            task :prepare, :on_no_matching_servers => :continue  do
              if fetch(:turbosprockets_enabled)
                run_cmd "mkdir -p #{fetch(:turbosprockets_backup_dir)}"
                run_cmd "mv #{fetch(:turbosprockets_backup_dir)} #{fetch(:assets_dir)}"
                run_cmd "#{fetch(:cleanexpired_cmd)}"
              end
              run_cmd "#{fetch(:precompile_cmd)}"
            end

            desc "Precompile assets locally and then rsync to app servers"
            task :precompile, :only => { :primary => true }, :on_no_matching_servers => :continue do
              servers = find_servers :roles => assets_role, :except => { :no_release => true }
              servers.each do |srvr|
                run_cmd "#{fetch(:rsync_cmd)} ./#{fetch(:assets_dir)}/ #{user}@#{srvr}:#{release_path}/#{fetch(:assets_dir)}/"
              end
            end

          end
        end
      end
    end

  end
end

if Capistrano::Configuration.instance
  Capistrano::LocalPrecompile.load_into(Capistrano::Configuration.instance)
end
