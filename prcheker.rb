require "octokit"
require 'dotenv'

class Prchekcer

  def initialize(*args)
    Dotenv.load
    @client = Octokit::Client.new(:access_token => ENV['GITHUB_ACCESS_TOKEN'])
    @user = @client.user
    @user.login
    @grace_period_in_days = ENV['GRACE_PERIOD'] ? ENV['GRACE_PERIOD'].to_i : 1
    @max_allowed_prs =  ENV['GRACE_PERIOD'] ? ENV['MAX_ALLOWED_PRS'].to_i : 0
    @security_vulnerability_only =  ENV['SECURITY_VULNERABILITIES_ONLY'] == "true"
  end

  def execute
    pull_requests = fetch_pull_requests
    fail_now(pull_requests) if pull_requests.length > @max_allowed_prs
    fail_now(pull_requests) if (pull_requests = grace_period_over_for(pull_requests)) && pull_requests.length > 0
    return true
  end

  def fetch_pull_requests
    if @security_vulnerability_only
      @client.pull_requests(ENV['REPO_NAME'], :state => 'open').select{|pr| pr.user.login == 'dependabot-preview[bot]' && pr.labels.map(&:name).include?('security')}
    else
      @client.pull_requests(ENV['REPO_NAME'], :state => 'open').select{|pr| pr.user.login == 'dependabot-preview[bot]'}
    end
  end

  def fail_now(pull_requests)
    err = <<-ERR
      ABORTED! There are #{pull_requests.length} from Dependabot that needs to be closed before you can build successfully
      #{pull_requests.map(&:title).join("\n")}
    ERR
    STDERR.puts(err)
    exit(false)
  end

  def grace_period_over_for(pull_requests)
    day_in_seconds = 100
    grace_period = Time.now - (day_in_seconds * @grace_period_in_days)
    pull_requests = pull_requests.select{|pr| pr.created_at < grace_period}
  end

end

prchecker  = Prchekcer.new
prchecker.execute
