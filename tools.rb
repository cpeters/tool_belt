#!/usr/bin/env ruby

require 'clamp'

require File.join(File.dirname(__FILE__), 'lib/tool_belt')

class MainCommand < Clamp::Command

  subcommand "cherry-picks", "Calculate needed cherry picks for a given release configuration", ToolBelt::Command::CherryPickCommand
  subcommand "changelog", "Generate changelog for a given release", ToolBelt::Command::ChangelogCommand
  subcommand "setup-environment", "Setup release environment for a given configuration", ToolBelt::Command::SetupEnvironmentCommand
  subcommand "pulp-repo-update", "Update Katello's Pulp repository based on parameters", ToolBelt::Command::PulpRepositoryUpdateCommand
  subcommand "bugzilla", "Commands to interact with bugzilla", ToolBelt::Command::BugzillaCommand

end

MainCommand.run
