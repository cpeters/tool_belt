require 'fileutils'
require 'json'
require 'time'
require 'yaml'

require File.join(File.dirname(__FILE__), 'systools')

module ToolBelt
  class CherryPicker

    attr_accessor :bugzilla, :ignores, :issues, :release_environment,
                  :issues_open_redmine, :issues_missing_changeset, :issues_cherrypick_not_needed

    def initialize(config, release_environment, issues)
      self.bugzilla = config.bugzilla || false
      self.ignores = config.ignores || []
      self.issues = issues
      self.release_environment = release_environment

      self.issues_open_redmine = []
      self.issues_missing_changeset = []
      self.issues_cherrypick_not_needed = []

      picks = find_cherry_picks(config.project, config.release, release_environment.repo_names)
      write_cherry_pick_log(picks, config.release)
    end

    def find_cherry_picks(project, release, repo_names)
      picks = []

      open_issues = @issues.select { |issue| issue['closed_on'].nil? }
      open_issues.each { |issue| @issues_open_redmine << log_entry(issue) }

      closed_issues = @issues.select { |issue| !issue['closed_on'].nil? }
      closed_issues.each do |issue|
        revisions = []
        commits = issue['changesets']

        if commits.empty?
          @issues_missing_changeset << log_entry(issue)
          next
        end

        commits.each do |commit|
          if commit['comments'].downcase.start_with?('fixes', 'refs') && !@release_environment.commit_in_release_branch?(repo_names, commit['comments'])
            revisions << commit['revision']
          end
        end

        if revisions.empty?
          @issues_cherrypick_not_needed << log_entry(issue)
          next
        end

        revisions.each do |revision|
          picks << cherry_pick(issue, revision)
        end
      end

      picks
    end

    def write_cherry_pick_log(picks, release)
      picks = picks.sort_by { |p| [p['repository'], p['closed']] }.group_by { |h| h['repository'] }.each { |k,v| v.each { |x| x.delete('repository') } }

      ignored_picks = Hash[picks.collect { |k,v| [k, v.select { |h| ignore?(h['redmine']['id']) }] }].reject { |k,v| v.empty? }

      output = {
        'Open Redmine' => @issues_open_redmine,
        'Missing Changeset' => @issues_missing_changeset,
        'Ignored Issues' => ignored_picks,
        'Cherrypick Not Needed' => @issues_cherrypick_not_needed,
        'Cherrypick Needed' => picks
      }.reject{ |k,v| v.empty? }
      write_log_file("#{release}", "cherry_picks_#{release}", output.to_yaml)
    end

    private

    def cherry_pick(issue, revision)
      { 'repository' => find_repository(revision),
        'closed' => issue['closed_on'],
        'redmine' => { 'id' => issue['id'], 'subject' => issue['subject'] },
        'bugzilla' => ({ 'id' => issue['custom_fields'].select { |cf| cf['id'] == 6 }.first['value'], 'summary' => 'TBD' } if self.bugzilla),
        'commit' => revision
      }.reject{ |k,v| v.nil? }
    end

    def ignore?(id)
      ignores.include?(id) if ignores
    end

    def log_entry(issue)
      { 'closed' => issue['closed_on'],
        'redmine' => { 'id' => issue['id'], 'subject' => issue['subject'] },
        'bugzilla' => ({ 'id' => issue['custom_fields'].select { |cf| cf['id'] == 6 }.first['value'], 'summary' => 'TBD' } if self.bugzilla),
      }.reject{ |k,v| v.nil? }
    end

    def find_repository(revision)
      repo = @release_environment.repo_names.find { |repo_name| @release_environment.commit_in_repo?(repo_name, revision) }
      repo.nil? ? :unknown : repo
    end

    def write_log_file(path, filename, content, mode = 'w')
      FileUtils.mkdir_p("releases/#{path}") unless File.exist?("release/#{path}")
      File.open("releases/#{path}/#{filename}", mode) { |file| file.write(content) }
    end

  end
end
