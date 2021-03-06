require 'eventmachine'
require 'yaml'
require 'cfcm/iaas/iaas'
require 'cfcm/iaas/vsphere'

module CFCM
  module Monkey
    class SoftMonkey      
      def initialize(session, app_name, probability, min, max, frequency)
        @session = session
        @app_name = app_name
        @app = @session.get_app(app_name)
        @probability = probability
        @min_instances = min
        @max_instances = max
        @frequency = frequency
      end
      
      def start
        EventMachine.run do
          EventMachine.add_periodic_timer(@frequency) do
            # Determine if we should unleash the monkey
            if (Random.rand(100) + 1) <= @probability
              @app = @session.get_app(@app_name)
              instances = @app.total_instances
              max_growth = @session.max_instance_growth(@app_name)
              
              if instances > @max_instances
                puts "Shrink due to instance limitations"
                @app = @session.remove_instance(@app)
              elsif instances < @min_instances
                puts "Grow due to instance limitations"
                @app = @session.add_instance(@app)
              elsif max_growth == 0 || @max_instances == instances
                # Shrink
                puts "Shrink due to instance limitations"
                @app = @session.remove_instance(@app)
              elsif instances == @min_instances
                # Grow
                puts "Grow due to instance limitations"
                @app = @session.add_instance(@app)
              elsif Random.rand(2) == 0
                # Shrink
                puts "Shrink due to randomness"
                @app = @session.remove_instance(@app)
              else
                #Grow
                puts "Grow due to randomness"
                @app = @session.add_instance(@app)
              end
            end
          end          
        end
      end
    end
    
    
    class HardMonkey
      def show_help
        puts "Description coming soon"
      end
      
      def initialize(iaas, config_file, input_file, probability, frequency, dry_run = false)
        
        @probability = probability
        @frequency = frequency
        @dry_run = dry_run
        
        # Parse the config file
        @config = YAML.load_file(config_file)
        
        # Parse the input file
        input_fd = File.open(input_file, "rb")
        @input = input_fd.read.split
        
        # Build the IaaS interface
        @iaas_interface = nil          
        case iaas.downcase
        when "vsphere"
          @iaas_interface = CFCM::IAAS::Vsphere.new(@config["host"], @config["user"], @config["password"], @config)
        else
          puts "Unknown IaaS -- #{iaas}"
        end
      end
      
      def start
        # Start the Eventmachine loop, similar to above and shut down VMs at random
        EventMachine.run do
          EventMachine.add_periodic_timer(@frequency) do
            # Determine if we should unleash the monkey
            if (Random.rand(100) + 1) <= @probability
              vm = @input.sample
              puts "Sending Power Off to #{vm}"
              if @dry_run
                puts "Power Off not sent -- runing in dry run mode"
              else
                @iaas_interface.power_off_vm(vm)
              end
            end
          end
        end
      end
    end
  end
end