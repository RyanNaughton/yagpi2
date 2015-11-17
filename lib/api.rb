class Api
  def self.receive_ping
    { "status" => "ping_received" }
  end

  def self.halt!(*response)
    throw(:halt, response)
  end

  def self.error!(error_message, error_type)
    halt!(error_type,
      {'Content-Type' => 'application/json'}, {
        error: error_type,
        message: error_message
      }.to_json)
  end

  def self.receive_hook_and_return_data!(params)
    return(receive_ping.to_json) if Github.is_github_ping?(params)

    #TODO: Mirror issues
    github_payload = params["pull_request"]
    error!('No payload', 500) unless github_payload.present?

    #TODO: Clean code
    github_body = github_payload['body']
    github_branch = github_payload['head']['ref']
    github_action = params['action']
    github_pr_url = github_payload['html_url']
    github_author = github_payload['user']['login']
    error!('No action', 500) unless github_action.present?
    error!('No branch', 500) unless github_branch.present?
    error!('No PR URL', 500) unless github_pr_url.present?
    error!('No author', 500) unless github_author.present?

    pivotal_id = find_pivotal_id(github_body, github_branch)
    
    yagpi_action_taken = "none"
    if %w(opened reopened closed).include?(github_action)
      if pivotal_id.present?
        if %w(opened reopened).include?(github_action)
          change_story_state!(pivotal_id, github_pr_url, github_author, 'finished')
          yagpi_action_taken = "finish"
        elsif github_action == "closed"
          change_story_state!(pivotal_id, github_pr_url, github_author, 'delivered')
          yagpi_action_taken = "deliver"
        end
      elsif github_action != "closed" 
        o = nag_for_a_pivotal_id!(github_pr_url)
        yagpi_action_taken = o ? "nag" : "nag disabled"
      end
    end
    
    {
      detected_github_action: github_action,
      detected_pivotal_id: pivotal_id,
      detected_github_pr_url: github_pr_url,
      detected_github_author: github_author,
      pivotal_action: yagpi_action_taken
    }
  end
end