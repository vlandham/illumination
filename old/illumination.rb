require 'sinatra'
require 'erb'
require 'json'

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

configure do
  set :log_dir, File.expand_path(File.join("/Volumes","genekc03","n","ngs","runs","archive_runs","log"))
end

helpers do
  def hours_since(time)
    past_time = time.kind_of?(Time) ? time : Time.parse(time)
    time_between = ((Time.now - past_time) / (60*60)).round(1)
    time_between.to_s
  end
end

get '/' do
  @flowcell_data = get_flowcell_data(settings.log_dir)
  @current_flowcell = @flowcell_data[0]
  erb :index
end
