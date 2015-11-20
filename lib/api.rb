require "./lib/github"
require "./lib/pivotal"

class Api
  def self.receive_ping
    { "status" => "ping_received" }
  end


  #TODO: Move error handling
  @@raises = false

  def self.set_raises_flag!
    @@raises = true
  end

  def self.unset_raises_flag!
    @@raises = false
  end

  def self.halt!(*response)
    throw(:halt, response)
  end

  def self.error!(error_message, error_type)
    if @@raises
      raise StandardError.new(error_message)
    else
      halt!(error_type,
        {'Content-Type' => 'application/json'}, {
          error: error_type,
          message: error_message
        }.to_json)
    end
  end


  def self.validate_payload(payload, type)
    error!("Malformed payload", 500) unless payload[type].is_a?(Hash)
    validated_payload = {
      "type" => type,
      "github_title" => payload[type]["title"],
      "github_body" => payload[type]["body"],
      "github_action" => payload["action"],
      "github_url" => payload[type]["html_url"],
      "github_author" => payload[type]["user"]["login"]
    }
    error!("No action", 500) unless validated_payload["github_action"].present?
    error!("No URL", 500) unless validated_payload["github_url"].present?
    error!("No author", 500) unless validated_payload["github_author"].present?
    validated_payload
  end

  def self.validate_pull_request_payload(payload)
    validated_payload = validate_payload(payload, "pull_request")
    validated_payload["github_branch"] = payload["pull_request"]["head"]["ref"]
    error!("No branch", 500) unless validated_payload["github_branch"].present?
    validated_payload
  end

  def self.validate_issue_payload(payload)
    validate_payload(payload, "issue")
  end


  def self.ignore(payload, pivotal_id)
    api_results(payload, pivotal_id, "ignore")
  end

  def self.nag(payload)
    nag_result = Github.nag_for_a_pivotal_id!(payload["github_url"])
    yagpi_action_taken = nag_result ? "nag" : "nag disabled"
    api_results(payload, nil, yagpi_action_taken)
  end

  def self.handle_missing_pivotal_id(payload)
    return(ignore(payload, nil)) if payload["github_action"] == "closed" 
    nag(payload)
  end

  def self.is_opening?(action)
    %w(opened reopened).include?(action)
  end

  def self.is_closing?(action)
    action == "closed"
  end

  def self.api_results(payload, pivotal_id, yagpi_action_taken)
    {
      "processing_type" => payload["type"],
      "detected_github_action" => payload["github_action"],
      "detected_pivotal_id" => pivotal_id,
      "detected_github_url" => payload["github_url"],
      "detected_github_author" => payload["github_author"],
      "pivotal_action" => yagpi_action_taken
    }
  end


  def self.receive_hook_and_return_data!(payload)
    if Github.is_github_ping?(payload)
      receive_ping
    elsif Github.is_pull_request_action?(payload)
      handle_pull_request_action(payload)
    elsif Github.is_issue_action?(payload)
      handle_issue_action(payload)
    else
      error!("Received a payload that was not a pull request or an issue.", 500)
    end
  end


  def self.handle_pull_request_action(payload)
    payload = validate_pull_request_payload(payload)

    pivotal_id = Pivotal.find_pivotal_id(payload["github_body"], payload["github_branch"])
    handle_missing_pivotal_id(payload) unless pivotal_id.present?

    if is_opening?(payload["github_action"])
      Pivotal.finish!(pivotal_id, payload["github_url"], payload["github_author"])
      yagpi_action_taken = "finish"
    elsif is_closing?(payload["github_action"])
      Pivotal.deliver!(pivotal_id, payload["github_url"], payload["github_author"])
      yagpi_action_taken = "deliver"
    else
      return(ignore(payload, pivotal_id))
    end
    api_results(payload, pivotal_id, yagpi_action_taken)
  end


  def self.handle_issue_action(payload)
    payload = validate_issue_payload(payload)

    if is_opening?(payload["github_action"])
      piv_url = Pivotal.create_a_bug!(payload["github_title"], payload["github_url"])
      Github.post_pivotal_link_on_issue!(payload, piv_url)
      yagpi_action_taken = "create"
    elsif is_closing?(payload["github_action"])
      pivotal_id = Pivotal.find_pivotal_id(payload["github_body"], nil)
      return(ignore(payload, pivotal_id)) unless pivotal_id.present?
      Pivotal.deliver!(pivotal_id, payload["github_url"], payload["github_author"])
      yagpi_action_taken = "deliver"
    else
      return(ignore(payload, pivotal_id))
    end
    api_results(payload, pivotal_id, yagpi_action_taken)
  end
end
