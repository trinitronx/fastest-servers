require 'spec_helper'
require 'docker'

describe 'Dockerfile' do

  before(:all) do
    @image = Docker::Image.build_from_dir('.')
    puts "Built Image: #{@image.id}"
    # This image will now be cached by docker
    # and used for the rest of the RSpec tests
    # Tag it with the REPO and git COMMIT ID
    @repo = ! ENV['REPO'].nil? ? ENV['REPO'] : 'trinitronx/fastest-servers'

    require 'git'
    g = Git.open(Dir.pwd)
    head = g.gcommit('HEAD').sha if g.index.readable?

    @commit = ! ENV['COMMIT'].nil? ? ENV['COMMIT'] : head[0..7]
    @commit ||= 'rspec-testing' # If we failed to get a commit sha, label it with this as default
    puts "Tagging Image: #{@image.id} with: #{@repo}:#{@commit}"
    @image.tag( :repo => @repo, :tag => @commit, force: true)

    set :os, family: :debian
    set :backend, :exec
    set :docker_image, @image.id

  end

  describe 'Dockerfile#config' do
    it 'should run fastest-servers.rb' do
      expect(@image.json['ContainerConfig']['Cmd']).to include('/bin/sh')
      expect(@image.json['ContainerConfig']['Cmd']).to include(/fastest-servers\.rb/)
    end

    it 'should have WorkingDir set to /opt/app' do
      expect(@image.json['ContainerConfig']['WorkingDir']).to eq('/opt/app')
    end
  end

  describe 'Dockerfile#image' do
    context "inside Docker Container" do
      before(:all) {
        set :backend, :docker
        set :docker_image, @image.id
        t3 = Time.now
        puts "Dockerfile_spec.rb: Running 'inside Docker Container' tests on: #{@image.id} at: #{t3}.#{t3.nsec}"
      }

      describe process("ruby") do
        it { should be_running }
        its(:args) { should match /fastest-servers\.rb/ }
      end
    end
  end

  describe 'Dockerfile#running' do
    before(:all) do
      @container = Docker::Container.create(
        {
          "name" => "fastest_servers_rspec_test",
          "Image" => @image.id,
          "HostConfig" => {
             "Binds" => ["/tmp/:/tmp"],
          },
          "Mounts"=>[
            {"Source"=>"/tmp", "Destination"=>"/tmp", "Mode"=>"", "RW"=>true}
          ],
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
            "FASTEST_SERVER_DEBUG=true"
          ],
          "Volumes"=>nil
        }
      )

      puts @container.start

      set :os, family: :debian

    end

    context "on Host when run interactively w/TTY and FASTEST_SERVER_DEBUG=true; It has" do
      before(:all) {
        # Tell SpecInfra NOT to run commands inside the container
        # Necessary so we can run `docker inspect` on host
        set :backend, :exec
      }

      describe docker_container("fastest_servers_rspec_test") do
        it { should be_running }
        it { should have_volume('/tmp','/tmp') }
        its(:inspection) { should include 'Path' => '/bin/sh' }
        its(:inspection) { should include 'Args' => ["-c", "./fastest-servers.rb"] }
        its(['Config.Cmd']) { should include '/bin/sh' }
        its(['Config.Cmd']) { should include './fastest-servers.rb' }
        its(['Config.Env']) { should include 'FASTEST_SERVER_DEBUG=true' }
        its(['Config']) { should include 'AttachStdin' => true }
        its(['Config']) { should include 'AttachStdout' => true }
        its(['Config']) { should include 'AttachStderr' => true }
        its(['Config']) { should include 'Tty' => true }
        its(['Config']) { should include 'OpenStdin' => true }
        its(['Config']) { should include 'StdinOnce' => true }
      end

      # describe "Docker container fastest_servers_rspec_test" do
      #   before(:all) do
      #     # Wait max of 10 minutes for container to finish
      #     set :backend, :exec
      #     @container.wait(10 * 60)
      #   end

      #   describe "fastest-server output" do
      #     puts "@container.class: #{@container.class}"
      #     puts "@container.methods: #{@container.methods - Object.methods}"
      #     pending
      #     # expect(@container.logs(stdout: true)).to match(/Total Mirror servers Found:\s+[0-9]+/)
      #     # expect(@container.logs(stdout: true)).to match(/SERVER_LIST_TYPE = HTTP/)
      #     # expect(@container.logs(stdout: true)).to match(/MIRRORLIST_PORT = 80/)
      #     # expect(@container.logs(stdout: true)).to match(/MIRRORLIST_HOST = mirrors\.ubuntu\.com/)
      #     # expect(@container.logs(stdout: true)).to match(/MIRRORLIST_URL = \/mirrors\.txt/)
      #     # expect(@container.logs(stdout: true)).to match(/FASTEST_SERVER_LIST_OUTPUT = \/tmp\/mirrors\.txt/)
      #     # expect(@container.logs(stdout: true)).to match(/fastest_server_list = \[.*#<URI::HTTP/)
      #   end

      #   # describe "fastest-server output" do
      #   #   ## TODO: mirrorlist.txt file should have stuff in it...
      #   # end
      # end
    end

    after(:all) do
      @container.kill
      @container.delete(:force => true)
    end
  end

  ## Leave image around, because SpecInfra docker backend uses same image ID
  ## AND we want to run tests against this image, tag with git SHA, and if tests pass push to docker hub
  ## ALSO!!: SpecInfra::Backend::Docker.cleanup_container is run via: ObjectSpace.define_finalizer(self, proc { cleanup_container })
  ## This means that the containers created by SpecInfra's Docker backend will be removed AFTER everything!
  ## This ordering makes it so the image CANNOT be cleaned up since the SpecInfra containers will hang around until the very end!
  ## Docker warns with Error: "cannot delete defec7ed00 because the container badcode123 is using it"
  # after(:all) do
  #     @image.remove(:force => true)
  # end
end
