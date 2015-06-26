require 'configliere'
module CapistranoMulticonfigParallel
  # class that holds the options that are configurable for this gem
  module Configuration
    extend ActiveSupport::Concern

    class_methods do
      attr_accessor  :configuration
     
      def configuration
        @config ||= Configliere::Param.new
        @config.use :commandline
        command_line_params.each do |param|
          @config.define param[:name], :type => param[:type], :description => param[:description], :default => param[:default]
        end
        
        @config.read config_file if File.file?(config_file)
        @config.use :config_block
        @config.finally do |c|
          c = c[:multi_cap].present? ?  c[:multi_cap] : c
         c = c.merge(Settings.use(:commandline).resolve!)
          check_configuration(c)
        end
        @config.resolve!
      end
      
  
        
      def config_file
        File.join(CapistranoMulticonfigParallel.detect_root.to_s, 'config', 'multi_cap.yml')
      end
  
      def command_line_params
        [ 
          {:name => "multi_debug", :type => :boolean, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default => false , :show_capistrano => true },
          {:name => "multi_progress", :type => :boolean, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default => false,  :show_capistrano => true},
          {:name => "multi_secvential", :type => :boolean, :description => "[MULTI_CAP]Sets the debug enabled for celluloid actors", :default => false,  :show_capistrano => true},
          {:name => "task_confirmations", :type => Array, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default => ['deploy:symlink:release'] ,  :show_capistrano => true},
          {:name => "task_confirmation_active", :type => :boolean, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default => false, :show_capistrano => true},
          {:name => "track_dependencies", :type => :boolean, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default => false, :show_capistrano => true},
          {:name => "websocket_server.enable_debug", :type => :boolean, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default => false, :show_capistrano => true},
          {:name => "development_stages", :type => Array, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default =>  ['development', 'webdev'], :show_capistrano => true},
          {:name => "application_dependencies", :type => Array, :description => "[MULTI_CAP] Sets the debug enabled for celluloid actors", :default =>  [], :show_capistrano => false},
        ]
      end
      
      
      def capistrano_options
        command_line_params.select{|p| p[:show_capistrano] == true }.map do |param|
          [ 
            "--#{param[:name]}", 
            "--#{param[:name]}",
            param[:description],
            lambda do |_value|
             
            end
          ]
        end
      end
      
      def verify_array_of_strings(c, prop)
        param = command_line_params.detect{|p| p[:name].to_s == prop.to_s}
        if param.present? && param[:required] 
          value = c[prop]
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
        param = command_line_params.detect{|p| p[:name].to_s == prop.to_s}
        if param.present? && param[:required] &&  ![true, false, 'true', 'false'].include?(c[prop])
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
        c.application_dependencies = c[:application_dependencies] if c[:track_dependencies]  &&   verify_application_dependencies(c[:application_dependencies])
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
