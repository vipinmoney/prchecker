require "octokit"
require 'optparse'

class Prchekcer

  def initialize
    parse_command_line_arguments
    @client = Octokit::Client.new(:access_token => @access_token)
    @user = @client.user
    @user.login
  end

  def parse_command_line_arguments
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: prchecker.rb [options]"

      opts.on('-g [ARG]', '--grace_period [ARG]', "Specify the grace_period") do |v|
        options[:grace_period] = v
      end

      opts.on('-s [ARG]', '--security_vulnerabilities_only [ARG]', "Specify the security_vulnerabilities_only") do |v|
        options[:security_vulnerabilities_only] = v
      end

      opts.on('-m [ARG]', '--max_allowed_prs [ARG]', "Specify the max_allowed_prs") do |v|
        options[:max_allowed_prs] = v
      end

      opts.on('-r [ARG]', '--repo_name [ARG]', "Specify the repo_name") do |v|
        options[:repo_name] = v
      end

      opts.on('-g [ARG]', '--github_access_token [ARG]', "Specify the github_access_token") do |v|
        options[:github_access_token] = v
      end

    end.parse!
    if options[:github_access_token].nil? || options[:repo_name].nil?
      STDERR.puts("ABORTED! Missing github_access_token or repo_name")
      exit(false)
    end

    @grace_period_in_days = (options[:grace_period] ||  1).to_i
    @max_allowed_prs =  (options[:max_allowed_prs] ||  1).to_i
    @security_vulnerability_only =  options[:security_vulnerabilities_only] ==  "true"
    @access_token = options[:github_access_token]
    @repo_name = options[:repo_name]
  end

  def execute
    pull_requests = fetch_pull_requests
    fail_now(pull_requests) if pull_requests.length > @max_allowed_prs
    fail_now(pull_requests) if (pull_requests = grace_period_over_for(pull_requests)) && pull_requests.length > 0
    return true
  end

  def fetch_pull_requests
    if @security_vulnerability_only
      @client.pull_requests(@repo_name, :state => 'open').select{|pr| pr.user.login == 'dependabot-preview[bot]' && pr.labels.map(&:name).include?('security')}
    else
      @client.pull_requests(@repo_name, :state => 'open').select{|pr| pr.user.login == 'dependabot-preview[bot]'}
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
