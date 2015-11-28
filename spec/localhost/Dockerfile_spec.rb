require 'spec_helper'
require 'docker'

describe 'Dockerfile' do

  before(:all) do
    @image = Docker::Image.build_from_dir('.')

    set :os, family: :debian
    set :backend, :docker
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

  describe 'Dockerfile#running' do
    before(:all) do
      @container = Docker::Container.create(
        'Image'      => @image.id,
        'HostConfig' => {
          'PortBindings' => { "#{REDIS_PORT}/tcp" => [{ 'HostPort' => "#{REDIS_PORT}" }] }
        }
      )

      @container.start
    end
  end

end
