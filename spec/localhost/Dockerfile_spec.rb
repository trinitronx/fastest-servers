require 'spec_helper'
require 'docker'

$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'helpers')

require 'singleton_docker_helper'
require 'tarextractor_helper'
require 'string_uncolorize_helper'

describe 'Dockerfile' do
  RSpec.shared_context "trinitronx/fastest-servers image" do
    def image
      # This image will now be cached by docker
      # and used for the rest of the RSpec tests
      # We will instantiate a SingletonDockerImage to store & retrieve the id throughout
      # Then return the Docker::Image class for that image ID
      singleton_image = SingletonDockerImage.instance
      if ! singleton_image.id.nil?
        Docker::Image.get(singleton_image.id)
      else
        img = Docker::Image.build_from_dir('.')
        singleton_image.id = img.id
        img
      end
    end

    before(:all) do
      # Use Global Variable so we always reference the SAME image
      
      puts "Built Image: #{image.id}"
      
      # Tag it with the REPO and git COMMIT ID
      @repo = ! ENV['REPO'].nil? ? ENV['REPO'] : 'trinitronx/fastest-servers'

      require 'git'
      g = Git.open(Dir.pwd)
      head = g.gcommit('HEAD').sha if g.index.readable?

      @commit = ! ENV['COMMIT'].nil? ? ENV['COMMIT'] : head[0..7]
      @commit ||= 'rspec-testing' # If we failed to get a commit sha, label it with this as default
      puts "Tagging Image: #{image.id} with: #{@repo}:#{@commit}"
      image.tag( :repo => @repo, :tag => @commit, force: true)

      set :os, family: :debian
      set :backend, :exec
      set :docker_image, image.id

    end
  end

  describe 'Dockerfile#config' do
    include_context "trinitronx/fastest-servers image"

    it 'should run fastest-servers.rb' do
      expect(image.json['ContainerConfig']['Cmd']).to include('/bin/sh')
      expect(image.json['ContainerConfig']['Cmd']).to include(/fastest-servers\.rb/)
    end

    it 'should have WorkingDir set to /opt/app' do
      expect(image.json['ContainerConfig']['WorkingDir']).to eq('/opt/app')
    end
  end

  describe 'Dockerfile#image' do
    include_context "trinitronx/fastest-servers image"

    context "inside Docker Container" do
      before(:all) {
        set :backend, :docker
        set :docker_image, image.id
        # t3 = Time.now
        # puts "Dockerfile_spec.rb: Running 'inside Docker Container' tests on: #{image.id} at: #{t3}.#{t3.nsec}"
      }

      describe process("ruby") do
        it { should be_running }
        its(:args) { should match /fastest-servers\.rb/ }
      end
    end
  end

  describe 'Dockerfile#running' do
    include_context "trinitronx/fastest-servers image"

    # Define a shared context for storing our container vars
    RSpec.shared_context "fastest_servers_rspec_test" do
      def container_opts
        {
            "name" => "fastest_servers_rspec_test",
            "Image" => image.id,
            "AttachStdin" => true,
            "AttachStdout" => true,
            "AttachStderr" => true,
            "Tty" => true,
            "OpenStdin" => true,
            "StdinOnce" => true,
            "Env" => [
              "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
              "RUBY_MAJOR=2.2",
              "RUBY_VERSION=2.2.0",
              "FASTEST_SERVER_DEBUG=true",
              "FASTEST_SERVER_INITIAL_TIMEOUT=0.090"
            ],
            "Volumes"=>nil
          }
      end

      def container
        # Attempt to work around RSpec's insistence that we either use `let` or `before(:all)` exclusively
        # without sharing a global scope of any kind
        # This hack lets us effectively use a Singleton-like container across RSpec Examples & ExampleGroups
        # We just instantiate a SingletonDockerContainer class to store the container id, then use it throughout
        # Try to find our started container if it's already there and use it
        # If not found, create it!
        singleton_container = SingletonDockerContainer.instance
        if ! singleton_container.id.nil?
          Docker::Container.get(singleton_container.id)
        else
          c = Docker::Container.create(container_opts)
          singleton_container.id = c.id
          c
        end
      end

      before(:all) do
        # Start the container before running any tests
        container.start
        set :os, family: :debian
      end

      after(:all) do
        # Destroy the container after all tests
        container.kill
        container.delete(:force => true)
      end
    end

    context "on Host when run interactively w/TTY, FASTEST_SERVER_DEBUG=true, FASTEST_SERVER_INITIAL_TIMEOUT=0.090; It has" do
      include_context "fastest_servers_rspec_test"

      before(:all) {
        # Tell SpecInfra NOT to run commands inside the container
        # Necessary so we can run `docker inspect` on host
        set :backend, :exec
      }

      describe docker_container("fastest_servers_rspec_test") do
        it { should be_running }
        its(:inspection) { should include 'Path' => '/bin/sh' }
        its(:inspection) { should include 'Args' => ["-c", "./fastest-servers.rb"] }
        its(['Config.Cmd']) { should include '/bin/sh' }
        its(['Config.Cmd']) { should include './fastest-servers.rb' }
        its(['Config.Env']) { should include 'FASTEST_SERVER_DEBUG=true' }
        its(['Config.Env']) { should include 'FASTEST_SERVER_INITIAL_TIMEOUT=0.090' }
        its(['Config']) { should include 'AttachStdin' => true }
        its(['Config']) { should include 'AttachStdout' => true }
        its(['Config']) { should include 'AttachStderr' => true }
        its(['Config']) { should include 'Tty' => true }
        its(['Config']) { should include 'OpenStdin' => true }
        its(['Config']) { should include 'StdinOnce' => true }
      end

      # This ExampleGroup is SLOW because it waits for the running container to complete
      # Skip with: --tag ~slow
      describe "Docker container fastest_servers_rspec_test", slow: true do

        before(:all) do
          # Wait max of 15 minutes for container to finish
          set :backend, :exec
          puts "Waiting for container #{container.id} to complete running..."
          puts "Container STDOUT/STDERR:\n"
          puts container.attach(:stream => true, :stdin => nil, :stdout => true, :stderr => true, :logs => true, :tty => true)
          container.wait(15 * 60)
        end

        describe "fastest-server output" do
          it 'should output expected strings to STDOUT' do
            # Strip ANSI color with string_uncolorize_helper
            expect(container.logs(stdout: true).uncolorize).to match(/Total Mirror servers Found:\s+[0-9]+/)
            expect(container.logs(stdout: true).uncolorize).to match(/SERVER_LIST_TYPE = HTTP/)
            expect(container.logs(stdout: true).uncolorize).to match(/FASTEST_SERVER_INITIAL_TIMEOUT = 0.090000/)
            expect(container.logs(stdout: true).uncolorize).to match(/MIRRORLIST_PORT = 80/)
            expect(container.logs(stdout: true).uncolorize).to match(/MIRRORLIST_HOST = mirrors\.ubuntu\.com/)
            expect(container.logs(stdout: true).uncolorize).to match(/MIRRORLIST_URL = \/mirrors\.txt/)
            expect(container.logs(stdout: true).uncolorize).to match(/FASTEST_SERVER_LIST_OUTPUT = \/tmp\/mirrors\.txt/)
            expect(container.logs(stdout: true).uncolorize).to match(/fastest_server_list = \[.*#<URI::HTTP/)
          end
        end

        describe "fastest-server mirrors.txt output" do

          def tmp_dir
            File.join('', 'tmp', 'rspec-testing')
          end

          def output_tar
            File.join(tmp_dir, 'output.tar')
          end

          before(:all) do
            # Tell SpecInfra NOT to run commands inside the container
            # Necessary so we can run tests on copied mirrors.txt file on host
            set :backend, :exec

            FileUtils.rm_rf tmp_dir if File.directory? tmp_dir
            FileUtils.mkdir_p(tmp_dir)
            puts "Attempting to copy /tmp/mirrors.txt from container"

            File.open( output_tar , 'w') do |file|
              container.copy('/tmp/mirrors.txt') do |chunk|
                file.write(chunk)
              end
              file.flush
            end

            TarExtractor.extract( output_tar, tmp_dir, true )
          end

          describe file( File.join('', 'tmp', 'rspec-testing', 'output.tar') ) do
            it { should be_file }
          end

          describe file( File.join('', 'tmp', 'rspec-testing', 'mirrors.txt') ) do
            it { should be_file }
            its(:content) { should match /^(https?|ftp):\/\/[^\s\/$.?#].[^\s]*$/i }
            it 'should have >=5 entries' do
              expect(subject.content.lines.length).to be >= 5
            end
          end
        end
      end
    end # end context fastest_servers_rspec_test
  end

  ## Leave image around, because SpecInfra docker backend uses same image ID
  ## AND we want to run tests against this image, tag with git SHA, and if tests pass push to docker hub
  ## ALSO!!: SpecInfra::Backend::Docker.cleanup_container is run via: ObjectSpace.define_finalizer(self, proc { cleanup_container })
  ## This means that the containers created by SpecInfra's Docker backend will be removed AFTER everything!
  ## This ordering makes it so the image CANNOT be cleaned up since the SpecInfra containers will hang around until the very end!
  ## Docker warns with Error: "cannot delete defec7ed00 because the container badcode123 is using it"
  # after(:all) do
  #     image.remove(:force => true)
  # end
end
