module ToolBelt
  module Command
    class BugzillaCommand < Clamp::Command

      subcommand "flag-cherry-picks", "Flags bugs to be cherry picked" do

        option "--config", 'CONFIG', "Config file containing credentials to talk to Bugzilla", :required => true

        def execute
          config = YAML.load_file(@config)
          bz = RedHatBugzilla.new(config['username'], config['password'])

          bugs = JSON.parse(bz.bugs_for_release(
            :flags => [
              {:option => "equals", :value => "pm_ack+"},
              {:option => "equals", :value => "devel_ack+"},
              {:option => "equals", :value => "qa_ack+"},
              {:option => "equals", :value => "sat-6.2.0+"}
            ]
          ))

          bz_ids = bugs["result"]["bugs"].collect { |b| b['id'] }
          bz.set_needs_cherry_pick(bz_ids)
        end

      end

      subcommand "list-cherry-pick-bugs", "Returns list of BZs flagged for cherry pick" do

        option "--config", 'CONFIG', "Config file containing credentials to talk to Bugzilla", :required => true

        def execute
          config = YAML.load_file(@config)
          bz = RedHatBugzilla.new(config['username'], config['password'])

          puts "Fetching bugs needing cherry pick"
          bugs = bz.get_needs_cherry_pick
          puts "Found #{bugs['bugs'].length} bugs needing cherry pick"

          puts "Writing bugs to bugs.json file"
          File.open('bugs.json', 'w') do |file|
            file.write(bugs.to_json)
          end
        end

      end

      subcommand "cherry-pick", "Generate cherry pick output " do

        parameter "config_file", "Release configuration file"
        option "--credentials", 'CREDENTIALS', "Config file containing credentials to talk to Bugzilla", :required => false
        option "--username", 'USERNAME', "Bugzilla username", :required => false
        option "--password", 'PASSWORD', "Bugzilla password", :required => false

        def execute
          if !@credentials && !@username && !@password
            puts "Must specify a credentials file or username and password"
          elsif !@username && @password
          elsif @username && !@password
          end

          config = ToolBelt::Config.new(config_file, nil, true)
          release_environment = ToolBelt::ReleaseEnvironment.new(config.options.repos, config.options.namespace)
          release_environment.setup

          if @credentials
            credentials = YAML.load_file(@credentials)
            @username = credentials['username']
            @password = credentials['password']
          end

          puts @username
          bz = RedHatBugzilla.new(username, password)

          bugzilla_bugs = bz.get_needs_cherry_pick

          ToolBelt::CherryPicker.new(config.options, release_environment, bugzilla_bugs)
        end

      end

    end
  end
end
