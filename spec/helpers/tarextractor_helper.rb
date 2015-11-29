
require 'rubygems/package'

module TarExtractor
  TAR_LONGLINK = '././@LongLink' unless const_defined?(:TAR_LONGLINK)

  def self.extract(filename, destination, verbose = false )
    Gem::Package::TarReader.new( File.open(filename, 'r')) do |tar|
      tar.each do |entry|
        dest = nil
        # puts "ENTRY: #{entry}"
        # puts "ENTRY.full_name: #{entry.full_name}"
        if entry.full_name == TAR_LONGLINK
          dest = File.join destination, entry.read.strip
          next
        end
        dest ||= File.join destination, entry.full_name
        # puts "DEST: #{dest}"
        if entry.directory?
          File.delete dest if File.file? dest
          FileUtils.mkdir_p dest, :mode => entry.header.mode, :verbose => verbose
        elsif entry.file?
          FileUtils.rm_rf dest if File.directory? dest
          File.open dest, "wb" do |f|
            f.print entry.read
          end
          FileUtils.chmod entry.header.mode, dest, :verbose => verbose
        elsif entry.header.typeflag == '2' #Symlink!
          File.symlink entry.header.linkname, dest
        end
        dest = nil
      end
    end
  end
end
