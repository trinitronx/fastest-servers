require 'spec_helper'

describe "trinitronx/fastest-server:latest" do

  before(:all) do
    @image = Docker::Image.build_from_dir('.')
    t10 = Time.now
    puts "trinitronx_fastest-servers_spec.rb: Created Image: #{@image.id} at: #{t10}.#{t10.nsec}"

    set :os, family: :debian
    set :backend, :docker
    set :docker_image, @image.id
    # set :docker_image, 'trinitronx/fastest-servers:latest'

  end

  describe file('/usr/local/bin/ruby') do
    it { should exist }
    it { should be_file }
    it { should be_executable }
  end

  describe file('/usr/local/bin/gem') do
    it { should exist }
    it { should be_file }
    it { should be_executable }
  end

  describe package('net-ping') do
    it { should be_installed.by(:gem) }
  end

  describe file('/opt/app') do
    it { should be_directory }
  end

  describe file('/opt/app/fastest-servers.rb') do
    it { should exist }
    it { should be_file }
    it { should be_executable }
    it { should contain /^#!\/usr\/bin\/env ruby/ }
    it { should contain "fastest_server_list" }
  end

end
