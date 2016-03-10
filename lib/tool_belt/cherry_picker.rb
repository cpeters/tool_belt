require 'fileutils'
require 'json'
require 'time'
require 'yaml'

require File.join(File.dirname(__FILE__), 'systools')

module ToolBelt
  class CherryPicker

    attr_accessor :bugzilla, :bugzilla_bugs, :bugzilla_bugs_missing_redmine_url,
                  :redmine_issues, :redmine_issues_open, :redmine_issues_missing_changeset, :redmine_issues_cherrypick_not_needed,
                  :ignores, :release_environment

    def initialize(config, release_environment, bugzilla_bugs)
      self.bugzilla = config.bugzilla || false
      self.bugzilla_bugs = bugzilla_bugs['result']['bugs']
      self.bugzilla_bugs_missing_redmine_url = []

      self.redmine_issues = []
      self.redmine_issues_open = []
      self.redmine_issues_missing_changeset = []
      self.redmine_issues_cherrypick_not_needed = []

      find_redmine_issues(self.bugzilla_bugs)

      self.ignores = config.ignores || []
      self.release_environment = release_environment

      picks = find_cherry_picks(config.project, config.release, release_environment.repo_names)
      write_cherry_pick_log(picks, config.release)
    end

    def find_cherry_picks(project, release, repo_names)
      picks = []

      open_issues = @redmine_issues.select { |issue| issue['closed_on'].nil? }
      open_issues.each { |issue| @redmine_issues_open << log_entry(issue) }

      closed_issues = @redmine_issues.select { |issue| !issue['closed_on'].nil? }
      closed_issues.each do |issue|
        revisions = []
        commits = issue['changesets']

        if commits.empty?
          @redmine_issues_missing_changeset << log_entry(issue)
          next
        end

        commits.each do |commit|
          if commit['comments'].downcase.start_with?('fixes', 'refs') && !@release_environment.commit_in_release_branch?(repo_names, commit['comments'])
            revisions << commit['revision']
          end
        end

        if revisions.empty?
          @redmine_issues_cherrypick_not_needed << log_entry(issue)
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
        'Bugzilla Bugs' => self.bugzilla_bugs.collect { |bz_bug| {'id' => bz_bug['id']} }.sort_by { |bug| bug['id'] },
        'Bugzilla Bugs Missing Redmine Url' => self.bugzilla_bugs_missing_redmine_url.collect { |bz_bug| {'id' => bz_bug['id'], 'assigned_to' => bz_bug['assigned_to']} }.sort_by { |bug| bug['id'] },
        'Redmine Issues Open' => @redmine_issues_open.sort_by { |issue| issue['closed'] },
        'Redmine Issues Missing Changeset' => @redmine_issues_missing_changeset.sort_by { |issue| issue['closed'] },
        'Redmine Issues Ignored' => ignored_picks,
        'Redmine Issues Cherrypick Not Needed' => @redmine_issues_cherrypick_not_needed.sort_by { |issue| issue['closed'] },
        'Redmine Issues Cherrypick Needed' => picks
      }.reject{ |k,v| v.empty? }
      write_log_file("#{release}", "cherry_picks_#{release}", output.to_yaml)
    end

    private

    def find_redmine_issues(bugzilla_bugs)
      bugzilla_bugs.each do |bz_bug|
        if bz_bug['url'].empty?
          self.bugzilla_bugs_missing_redmine_url << bz_bug
        else
          self.redmine_issues << Redmine::Issue.new(bz_bug['url'].split('/').last, :include => 'changesets').raw_data['issue']
        end
      end
    end

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
