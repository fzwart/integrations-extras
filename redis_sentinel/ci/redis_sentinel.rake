require 'ci/common'

def redis_sentinel_version
  ENV['FLAVOR_VERSION'] || 'latest'
end

def redis_sentinel_rootdir
  "#{ENV['INTEGRATIONS_DIR']}/redis_sentinel_#{redis_sentinel_version}"
end

namespace :ci do
  namespace :redis_sentinel do |flavor|
    task before_install: ['ci:common:before_install']

    task install: ['ci:common:install'] do
      use_venv = in_venv
      install_requirements('redis_sentinel/requirements.txt',
                           "--cache-dir #{ENV['PIP_CACHE']}",
                           "#{ENV['VOLATILE_DIR']}/ci.log", use_venv)
      sh %(docker-compose -f #{ENV['TRAVIS_BUILD_DIR']}/redis_sentinel/ci/resources/docker-compose.yml up -d)
      wait_on_docker_logs('redis-sentinel', 5, '[redis-sentinel], started')
    end

    task before_script: ['ci:common:before_script']

    task :script, [:mocked] => ['ci:common:script'] do |_, attr|
      this_provides = [
        'redis_sentinel'
      ]
      Rake::Task['ci:common:run_tests'].invoke(this_provides)
    end

    task before_cache: ['ci:common:before_cache']

    task cleanup: ['ci:common:cleanup'] do
      sh %(docker-compose -f #{ENV['TRAVIS_BUILD_DIR']}/redis_sentinel/ci/resources/docker-compose.yml stop)
      sh %(docker-compose -f #{ENV['TRAVIS_BUILD_DIR']}/redis_sentinel/ci/resources/docker-compose.yml rm -f)
    end

    task :execute, :mocked do |_, attr|
      mocked = attr[:mocked] || false
      exception = nil
      begin
        unless mocked
          %w(before_install install before_script).each do |u|
            Rake::Task["#{flavor.scope.path}:#{u}"].invoke
          end
        end
        Rake::Task["#{flavor.scope.path}:script"].invoke(mocked)
        Rake::Task["#{flavor.scope.path}:before_cache"].invoke
      rescue => e
        exception = e
        puts "Failed task: #{e.class} #{e.message}".red
      end
      if ENV['SKIP_CLEANUP']
        puts 'Skipping cleanup, disposable environments are great'.yellow
      else
        puts 'Cleaning up'
        Rake::Task["#{flavor.scope.path}:cleanup"].invoke
      end
      raise exception if exception
    end
  end
end
