#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'net/http'
require 'net/ping/http'
require 'net/ping/udp'
require 'pp'

#ntp_server_list = ['ntp.ubuntu.com']
#(0..3).to_a.each { |n| ntp_server_list.push( n.to_s + '.ubuntu.pool.ntp.org' ) } ) }
SERVER_LIST_TYPE = ENV['FASTEST_SERVER_LIST_TYPE'] || 'HTTP'
timeout = ENV['FASTEST_SERVER_INITIAL_TIMEOUT'].to_f || 0.050
mirrorlist_file = ENV['MIRRORLIST_LOCAL_FILE']
mirrorlist_host = ENV['MIRRORLIST_HOST'] || 'mirrors.ubuntu.com'
mirrorlist_url  = ENV['MIRRORLIST_URL'] || '/mirrors.txt'
port = ENV['MIRRORLIST_PORT'] || '80'
FASTEST_SERVER_LIST_OUTPUT = ENV['FASTEST_SERVER_LIST_OUTPUT'] || '/tmp/mirrors.txt'

if ENV['FASTEST_SERVER_DEBUG']
  printf "%42s = %s\n", "\033[1;32mSERVER_LIST_TYPE\033[0m", SERVER_LIST_TYPE
  printf "%42s = %s\n", "\033[1;32mFASTEST_SERVER_INITIAL_TIMEOUT\033[0m", timeout
  printf "%42s = %s\n", "\033[1;32mMIRRORLIST_LOCAL_FILE\033[0m",  mirrorlist_file
  printf "%42s = %s\n", "\033[1;32mMIRRORLIST_HOST\033[0m", mirrorlist_host
  printf "%42s = %s\n", "\033[1;32mMIRRORLIST_URL\033[0m", mirrorlist_url
  printf "%42s = %s\n", "\033[1;32mMIRRORLIST_PORT\033[0m", port
  printf "%42s = %s\n", "\033[1;32mFASTEST_SERVER_LIST_OUTPUT\033[0m", FASTEST_SERVER_LIST_OUTPUT
end

fastest_server_list = []

class EmptyListException < Exception
end

## For NTP servers...
## Helpful code taken from: Ruby NET::NTP http://www.ruby-doc.org/gems/docs/n/ntp-1.0.0/NET/NTP.html
class NTP
end
class NTP::Packet
  NTP_ADJ = 2208988800

  def initialize()
    generate_packet
  end

  def generate_packet()
    client_time_send = Time.new.to_i
    client_localtime = client_time_send
    client_adj_localtime = client_localtime + NTP_ADJ
    client_frac_localtime = frac2bin(client_adj_localtime)
    
    ntp_msg =
      (['00011011']+Array.new(12, 0)+[client_localtime, client_frac_localtime.to_s]).pack("B8 C3 N10 B32")
    
    ntp_msg
  end 
  
  def decode_packet(data)
    #data=NIL 
    #Timeout::timeout(TIMEOUT) do |t|
    #  data=sock.recvfrom(960)[0]
    #end
    client_time_receive = Time.new.to_i
    
    ntp_fields = %w{ byte1 stratum poll precision
     delay delay_fb disp disp_fb ident
     ref_time ref_time_fb
     org_time org_time_fb
     recv_time recv_time_fb
     trans_time trans_time_fb }
    
    packetdata =
        data.unpack("a C3   n B16 n B16 H8   N B32 N B32   N B32 N B32"); 
    
    tmp_pkt=Hash.new
    ntp_fields.each do |f|
      tmp_pkt[f]=packetdata.shift
    end
  
    packet=Hash.new
    packet['Leap Indicator']=(tmp_pkt['byte1'][0] & 0xC0) >> 6 
    packet['Version Number']=(tmp_pkt['byte1'][0] & 0x38) >> 3
    packet['Mode']=(tmp_pkt['byte1'][0] & 0x07)
    packet['Stratum']=tmp_pkt['stratum']
    packet['Poll Interval']=tmp_pkt['poll']
    packet['Precision']=tmp_pkt['precision'] - 255
    packet['Root Delay']=bin2frac(tmp_pkt['delay_fb'])
    packet['Root Dispersion']=tmp_pkt['disp']
    packet['Reference Clock Identifier']=unpack_ip(tmp_pkt['stratum'], tmp_pkt['ident'])
    packet['Reference Timestamp']=((tmp_pkt['ref_time'] + bin2frac(tmp_pkt['ref_time_fb'])) - NTP_ADJ)
    packet['Originate Timestamp']=((tmp_pkt['org_time'] + bin2frac(tmp_pkt['org_time_fb'])) )
    packet['Receive Timestamp']=((tmp_pkt['recv_time'] + bin2frac(tmp_pkt['recv_time_fb'])) - NTP_ADJ)
    packet['Transmit Timestamp']=((tmp_pkt['trans_time'] + bin2frac(tmp_pkt['trans_time_fb'])) - NTP_ADJ)
    
    return packet
  end
end

def get_mirrors(mirrorlist_host, port)
  mirror_list = []
  Net::HTTP.start(mirrorlist_host, port) do |http|
   resp = http.get("/mirrors.txt")

   resp.body.each_line do |line|
     mirror_list.push( URI(line.chomp) )
   end
  end
  mirror_list
end

if mirrorlist_host
  fastest_server_list = get_mirrors(mirrorlist_host, port)
elsif mirrorlist_file
  fastest_server_list = File.open(mirrorlist_file).read
else
  printf "%s", "\033[1;31mERROR:\033[0m No MIRRORLIST_HOST or MIRRORLIST_LOCAL_FILE given."
  raise EmptyListException, "Initial server list could not be generated"
end

puts "Total Mirror servers Found: #{fastest_server_list.length}"

all_uris = fastest_server_list.clone

File.open(FASTEST_SERVER_LIST_OUTPUT, 'wt') do |f|
  try_count=0
  # Remove hosts with >1ms ping
  begin
    fastest_server_list.delete_if do |uri|
      # puts "LENGTH: #{fastest_server_list.length}"
      # puts fastest_server_list
      if SERVER_LIST_TYPE == 'HTTP'
        pinger = Net::Ping::HTTP.new(uri.host, uri.port || 80, timeout)
      elsif SERVER_LIST_TYPE == 'NTP'
        pinger = Net::Ping::UDP.new(uri.host, uri.port || 123, timeout)
        pinger.data = NTP::Packet.new()
      end
      
      if pinger.ping
        printf "%40s\t%s\n", uri.host, "\033[1;32m✓\033[0m"
        f.write(uri.to_s + "\n")
          false
      else
        printf "%40s\t%s\n", uri.host, "\033[1;31m✗\033[0m"
        # puts "Removing index: #{fastest_server_list.find_index(uri)}"
        true
      end
    end


    try_count += 1
    # puts "FINAL LIST:"
    # puts fastest_server_list
    if fastest_server_list.length.zero? || fastest_server_list.length < 5
      f.truncate(0)
      f.rewind
      puts "All mirror URIs failed to pass ping test!"
      raise EmptyListException, 'All mirror URIs failed to pass ping test!'
    end 
  rescue EmptyListException
    # restart with full list
    fastest_server_list = all_uris.clone
    puts "Retrying with full url list"
    puts "TRIES: #{try_count}"
    puts "LEN  : #{fastest_server_list.length}"
    puts "ZERO?: #{fastest_server_list.length.zero?}"
    if try_count < 3
      retry
    else
      timeout += 0.001
      puts "Increasing timeout: #{timeout}"
      retry
    end
  end

end

