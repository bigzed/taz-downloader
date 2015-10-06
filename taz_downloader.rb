#!/usr/bin/env ruby
require 'httparty'
require 'fileutils'
require 'date'
require 'optparse'

class TazDownloader
  include HTTParty

  def initialize(options)
    @destination = options[:destination]
    @name = options[:name]
    @password = options[:password]
    FileUtils.mkdir_p(@destination)
  end

  def download_pdf(date)
    # Prepare options
    url = 'http://dl.taz.de/pdf'
    options = {
      body: {
        name: @name,
        password: @password,
        Laden: 'laden',
        year: '',
        month: '',
        id: parse_id(date)
      }
    }

    # Write PDF to file
    File.open(File.join(@destination, "#{date.strftime('%y.%m.%d')}.pdf"), 'wb+') do |f|
      f.binmode
      f.write(self.class.post(url, options).parsed_response)
    end
  end

private

  def parse_id(date)
    self.class.get('https://dl.taz.de/pdf').parsed_response.match(/(taz_#{date.year}_#{date.month}_#{"%02d" % date.day}.\d*.pdf)/)[1]
  end
end

# Options parser
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: taz_downloader [options]"

  opts.on('-u', '--username USERNAME', "Username") do |v|
    options[:username] = v
  end

  opts.on('-p', '--password PASSWORD', 'Password') do |v|
    options[:password] = v
  end

  opts.on('-t', '--target TARGET', 'Target folder') do |v|
    options[:target] = v
  end

  opts.on('-h', '--help', 'Prints helpt') do
    puts opts
    exit
  end
end.parse!

# Validates options existence
abort 'Please supply username' if options[:username].nil?
abort 'Please supply password' if options[:password].nil?
abort 'Please supply target folder' if options[:target].nil?

# Download pdf
taz = TazDownloader.new(destination: options[:target], password: options[:password], name: options[:username])
date = Time.now
taz.download_pdf(date)
