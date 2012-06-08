require 'bundler/setup'
require 'sinatra/base'
require 'json'

# The project root directory
$root = ::File.dirname(__FILE__)

BUILD_DIR = '.'

class SinatraStaticServer < Sinatra::Base

  helpers do
    def hours_since(time)
      past_time = time.kind_of?(Time) ? time : Time.parse(time)
      time_between = ((Time.now - past_time) / (60*60)).round(1)
      time_between.to_s
    end


    def get_flowcell_data log_dir
      log_files = Dir.glob(File.join(log_dir, "*.log"))
      log_files = log_files.sort_by {|filename| File.mtime(filename) }.reverse
      data = []
      puts "#{log_files.size} files found in #{log_dir}"
      log_files.each do |log_file|
        flowcell_name = File.basename(log_file).split(".")[0]
        data_hash = {}
        data_hash[:id] =  flowcell_name
        data_hash[:events] = []
        File.open(log_file, 'r') do |file|
          file.each_line do |line|
            line_hash = JSON::load(line)
            data_hash[:events] << line_hash
          end
        end
        data << data_hash
      end
      data
    end
  end

  configure do
    set :log_dir, File.expand_path(File.join("/Volumes","genekc03","n","ngs","runs","archive_runs","log"))
  end

  get(/flowcells.json/) do
    content_type :json
    data = get_flowcell_data(settings.log_dir)
    data.to_json
  end

  get(/.+/) do
    send_sinatra_file(request.path) {404}
  end

  not_found do
    send_sinatra_file('404.html') {"Sorry, I cannot find #{request.path}"}
  end

  def send_sinatra_file(path, &missing_file_block)
    file_path = File.join(File.dirname(__FILE__), BUILD_DIR,  path)
    file_path = File.join(file_path, 'index.html') unless file_path =~ /\.[a-z]+$/i
    File.exist?(file_path) ? send_file(file_path) : missing_file_block.call
  end

end

run SinatraStaticServer

