#!/usr/bin/env ruby
require 'httparty'
require 'fileutils'
require 'date'
require 'optparse'
require 'mail'
require 'yaml'

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

  def send_mail(options)
    file_content = File.read(File.join(@destination, "#{options[:date].strftime('%y.%m.%d')}.pdf"))
    options[:receivers].each do |r|
      mail = Mail.new do 
        from 'taz-delivery@obstkiste.org'
        to r
        subject "TAZ from #{options[:date].strftime('%d.%m.%y')}"
        body <<-EOF
Enjoy your taz!

best,
taz-delivery@obstkiste.org
        EOF
        add_file filename: "taz_#{options[:date].strftime('%y.%m.%d')}.pdf", content: file_content
      end
      puts "Delivering mail to #{r}"
      mail.deliver!
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

  opts.on('-m', '--mail x@y.com,z@y.com', Array, 'Send mail to adresses') do |v|
    options[:mails] = v
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

# Prepare TAZ downloader
taz = TazDownloader.new(destination: options[:target], password: options[:password], name: options[:username])
date = Time.now

# Downloading
puts "Downloading TAZ for #{date.strftime('%d.%m.%y')}..."
taz.download_pdf(date)

# Send mail if necessary
if options[:mails]
  path = File.expand_path('../mail.yml', __FILE__)
  abort "Mail config is missing in #{path}" unless File.exists?(path)
  
  config = YAML.load_file(path)

  # Set the delivery method 
  Mail.defaults do
    delivery_method :smtp, config
  end

  taz.send_mail({date: date, receivers: options[:mails]}) 
end
