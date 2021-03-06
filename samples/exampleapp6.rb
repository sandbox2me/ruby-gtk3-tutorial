require "gtk3"

require "fileutils"

current_path = File.expand_path(File.dirname(__FILE__))
file_pattern = File.basename(__FILE__).gsub(".rb","")
DATA_PATH = "#{current_path}/data/#{file_pattern}"

gresource_bin = "#{DATA_PATH}/exampleapp.gresource"
gresource_xml = "#{DATA_PATH}/exampleapp.gresource.xml"

system("glib-compile-resources",
       "--target", gresource_bin,
       "--sourcedir", DATA_PATH,
       gresource_xml)

gschema_bin = "#{DATA_PATH}/gschemas.compiled"
gschema_xml = "#{DATA_PATH}/org.gtk.exampleapp.gschema.xml"

system("glib-compile-schemas", DATA_PATH)


at_exit do
  FileUtils.rm_f([gresource_bin, gschema_bin])
end

resource = Gio::Resource.load(gresource_bin)
Gio::Resources.register(resource)

ENV["GSETTINGS_SCHEMA_DIR"] = DATA_PATH

class ExampleAppPrefs < Gtk::Dialog
  type_register
  class << self
    def init
      set_template(:resource => "/org/gtk/exampleapp/prefs.ui")
      bind_template_child("font")
      bind_template_child("transition")
    end
  end
  def initialize(args)
    parent = args[:transient_for]
    bar = args[:use_header_bar]
    super(:transient_for => parent, :use_header_bar => 1)
    settings = Gio::Settings.new("org.gtk.exampleapp")
    settings.bind("font",
                  font,
                  "font",
                  Gio::SettingsBindFlags::DEFAULT)
    settings.bind("transition",
                  transition,
                  "active-id",
                  Gio::SettingsBindFlags::DEFAULT)
  end
end

class ExampleAppWindow < Gtk::ApplicationWindow
  # https://github.com/ruby-gnome2/ruby-gnome2/pull/445
  # https://github.com/ruby-gnome2/ruby-gnome2/issues/503
  type_register
  class << self
    def init
      set_template(:resource => "/org/gtk/exampleapp/window.ui")
      bind_template_child("stack")
    end
  end

  def initialize(application)
    super(:application => application)
    # load settings from gschemas.compiled in a directory
    # see https://developer.gnome.org/gio/unstable/gio-GSettingsSchema-GSettingsSchemaSource.html#g-settings-schema-source-new-from-directory
    # check ruby-gnome Gio::Settings.new or Gio::Schemas ??
    @settings = Gio::Settings.new("org.gtk.exampleapp")
    @settings.bind("transition",
                  stack,
                  "transition-type",
                  Gio::SettingsBindFlags::DEFAULT)
  end

  def open(file)
    basename = file.basename
    scrolled = Gtk::ScrolledWindow.new
    scrolled.show
    scrolled.set_hexpand(true)
    scrolled.set_vexpand(true)
    view = Gtk::TextView.new
    view.set_editable(false)
    view.set_cursor_visible(false)
    view.show
    scrolled.add(view)
    stack.add_titled(scrolled, basename, basename)
    stream = file.read
    buffer = view.buffer
    buffer.text = stream.read
    tag = buffer.create_tag() 
    @settings.bind("font", tag, "font", Gio::SettingsBindFlags::DEFAULT)
    buffer.apply_tag(tag, buffer.start_iter, buffer.end_iter)
  end
end

class ExampleApp < Gtk::Application
  def initialize
    super("org.gtk.exampleapp", :handles_open)

    signal_connect "startup" do |application|
      quit_accels = ["<Ctrl>Q"]
      action = Gio::SimpleAction.new("quit")
      action.signal_connect("activate") do |_action, _parameter|
        application.quit
      end
      application.add_action(action)
      application.set_accels_for_action("app.quit", quit_accels)

      action = Gio::SimpleAction.new("preferences")
      action.signal_connect("activate") do |_action, _parameter|
        win = application.windows.first

        prefs = ExampleAppPrefs.new(:transient_for => win,
                                    :use_header_bar => true)
        prefs.present
      end
      application.add_action(action)

      builder = Gtk::Builder.new(:resource => "/org/gtk/exampleapp/app-menu.ui")
      app_menu = builder.get_object("appmenu")
      application.set_app_menu(app_menu)

    end
    signal_connect "activate" do |application|
      window = ExampleAppWindow.new(application)
      window.present
    end

    signal_connect "open" do |application, files, hint|
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

puts app.run([$0] + ARGV)
