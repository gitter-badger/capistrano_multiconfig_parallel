require_relative'./initializers/conf'
module CapistranoMulticonfigParallel
  # class that holds the options that are configurable for this gem
  module Configuration
    extend ActiveSupport::Concern

    class_methods do
      attr_accessor  :configuration
     
      def configuration
        begin
          @config ||= Configliere::Param.new
          @config.use :commandline
          command_line_params.each do |param|
            @config.define param[:name], :type => param[:type], :description => param[:description], :default => param[:default]
          end
          @config.merge(Settings.use(:commandline).resolve!)
          @config.read config_file if File.file?(config_file)
        
          @config.use :config_block
          @config.finally do |c|
            check_configuration(c)
          end
          @config.resolve!
        rescue => ex
          puts ex.inspect
          puts ex.backtrace if ex.respond_to?(:backtrace)
        end
      end
      
  
      def default_config
        @default_config ||= Configliere::Param.new
        @default_config.read  File.join(CapistranoMulticonfigParallel.root.to_s, 'capistrano_multiconfig_parallel', 'initializers', 'default.yml')
        @default_config.resolve!
      end
        
      def config_file
        File.join(CapistranoMulticonfigParallel.detect_root.to_s, 'config', 'multi_cap.yml')
      end
  
      def command_line_params
        [ 
          {
            :name => "multi_debug", 
            :type => :boolean, 
            :description => "[MULTI_CAP] if option is present and has value TRUE , will enable debugging of workers", 
            :default => default_config[:multi_debug] 
          },
          {
            :name => "multi_progress", 
            :type => :boolean, 
            :description => "[MULTI_CAP] if option is present and has value TRUE  will first execute before any process , 
            same task but with option '--dry-run'  in order to show progress of how many tasks are in total for that task and what is the progress of executing
           This will slow down the workers , because they will execute twice the same task.", 
            :default => default_config[:multi_progress]
          },
          {
            :name => "multi_secvential", 
            :type => :boolean, 
            :description => "[MULTI_CAP] If parallel executing does not work for you, you can use this option so that each process is executed normally and ouputted to the screen.
  However this means that all other tasks will have to wait for each other to finish before starting ", 
            :default => default_config[:multi_secvential]
          },
          {
            :name => "websocket_server.enable_debug", 
            :type => :boolean,
            :description => "[MULTI_CAP]  if option is present and has value TRUE, will enable debugging of websocket communication between the workers", 
            :default => default_config[:websocket_server][:enable_debug]
          },
          {
            :name => "development_stages",
            :type => Array, 
            :description => "[MULTI_CAP] if option is present and has value an ARRAY of STRINGS, each of them will be used as a development stage", 
            :default => default_config[:development_stages]
          },
          {
            :name => "task_confirmations",
            :type => Array, 
            :description => "[MULTI_CAP] if option is present and has value TRUE, will enable user confirmation dialogs before executing each task from option  **--task_confirmations**",
            :default => default_config[:task_confirmations]
          },
          {
            :name => "task_confirmation_active", 
            :type => :boolean, 
            :description => "[MULTI_CAP] if option is present and has value an ARRAY of Strings, and --task_confirmation_active is TRUE , then will require a confirmation from user before executing the task. 
    This will syncronize all workers to wait before executing that task, then a confirmation will be displayed, and when user will confirm , all workers will resume their operation", 
            :default => default_config[:task_confirmation_active]
          },
          {
            :name => "track_dependencies",
            :type => :boolean,
            :description => "[MULTI_CAP] This should be useed only for Caphub-like applications , in order to deploy dependencies of an application in parallel.
     This is used only in combination with option **--application_dependencies** which is described 
     at section **[2.) Multiple applications](#multiple_apps)**", 
            :default => default_config[:track_dependencies]
          },
          {
            :name => "application_dependencies",
            :type => Array,
            :description => "[MULTI_CAP] This is an array of hashes. Each hash has only the keys 'app' ( app name), 'priority' and 'dependencies' ( an array of app names that this app is dependent to) ",
            :default =>  default_config[:application_dependencies]
          },
        ]
      end
      
      
      def capistrano_options
        command_line_params.map do |param|
          [ 
            "--#{param[:name]}[=CAP_VALUE]", 
            "--#{param[:name]}",
            param[:description],
            lambda do |value|
          
            end
          ]
        end
      end
      
      def verify_array_of_strings(c, prop)
        value = c[prop]
        if value.present?
          value.reject(&:blank?)
          if value.find { |row| !row.is_a?(String) }
            raise ArgumentError, 'the array must contain only task names'
          end
        end
      end
  
      def verify_application_dependencies(value)
        value.reject { |val| val.blank? || !val.is_a?(Hash) }
        wrong = value.find do|hash|
          !Set[:app, :priority, :dependencies].subset?(hash.keys.to_set) ||
            hash[:app].blank? ||
            hash[:priority].blank?
          !hash[:priority].is_a?(Numeric) ||
            !hash[:dependencies].is_a?(Array)
        end
        raise ArgumentError, "invalid configuration for #{wrong.inspect}" if wrong.present?
      end
  
      def check_boolean(c, prop)
        if c[prop].present?&&  ![true, false, 'true', 'false'].include?(c[prop])
          raise ArgumentError, "the property `#{prop}` must be boolean"
        end
      end

      def configuration_valid?
        configuration
      end
      
      def check_configuration(c)
        [:multi_debug, :multi_progress, :multi_secvential, :task_confirmation_active, :track_dependencies,  "websocket_server.enable_debug"].each do |prop|
          c.send("#{prop.to_s}=",  c[prop])  if  check_boolean(c, prop)
        end
        [:task_confirmations, :development_stages].each do |prop|
          c.send("#{prop.to_s}=",  c[prop])  if  verify_array_of_strings(c,prop)
        end
        c.application_dependencies = c[:application_dependencies] if c[:track_dependencies].to_s == "true"  &&   verify_application_dependencies(c[:application_dependencies])
        if c[:multi_debug]
          CapistranoMulticonfigParallel::CelluloidManager.debug_enabled = true
          Celluloid.task_class = Celluloid::TaskThread
        end
        CapistranoMulticonfigParallel.show_task_progress = true    if c[:multi_progress]
        CapistranoMulticonfigParallel.execute_in_sequence = true  if c[:multi_secvential]
      end
      
    end
  end
end
