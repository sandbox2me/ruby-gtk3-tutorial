require "gtk3"

require "fileutils"

current_path = File.expand_path(File.dirname(__FILE__))
file_pattern = File.basename(__FILE__).gsub(".rb","")
data_path = "#{current_path}/data/#{file_pattern}"
gresource_bin = "#{data_path}/exampleapp.gresource"
gresource_xml = "#{data_path}/exampleapp.gresource.xml"

system("glib-compile-resources",
       "--target", gresource_bin,
       "--sourcedir", File.dirname(gresource_xml),
       gresource_xml)

at_exit do
  FileUtils.rm_f(gresource_bin)
end

resource = Gio::Resource.load(gresource_bin)
Gio::Resources.register(resource)

class ExampleAppWindow < Gtk::ApplicationWindow
  type_register
  class << self
    def init
      set_template(:resource => "/org/gtk/exampleapp/window.ui")
    end
  end

  def initialize(application)
    super(:application => application)
  end

  def open(file)
    
  end
end

class ExampleApp < Gtk::Application
  def initialize
    super("org.gtk.exampleapp", :handles_open)

    signal_connect "activate" do |application|
      window = ExampleAppWindow.new(application)
      window.present
    end

    signal_connect "open" do |application, files, hin|
      windows = application.windows
      win = nil
      unless windows.empty?
        win = windows.first
      else
        win = ExampleAppWindow.new(application)
      end

      files.each { |file| win.open(file) }
        
      win.present
    end

  end
end

app = ExampleApp.new

puts app.run
