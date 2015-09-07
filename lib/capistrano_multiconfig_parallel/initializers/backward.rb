module CapistranoMulticonfigParallel
  # class used to store the config with backward compatible classes
  class Backward
    class << self
      attr_accessor :config

      def config
        {
          'logger_class' => celluloid_version_16? ? Celluloid::Logger : Celluloid::Internals::Logger
        }
      end

      def celluloid_version_16?
        celluloid_version = Celluloid::VERSION.to_s.split('.')
        celluloid_version[0].to_i == 0 && celluloid_version[1].to_i <= 16
      end
    end
  end
end
