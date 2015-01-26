# Description: This MIQ Method un-verifies e-mail addresses
# From an existing SES service

# For use in MIQ under the
# /Provisioning/StateMachines/Methods/CreateSES

require 'aws-sdk'
require 'net/http'
require 'uri/http'
require 'json'

$evm.log("info", "RetireSES: Entering method")

def send_order_status(status, order_id, information, message="")

  host = "jellyfish-core-dev.dpi.bah.com"
  path ="/order_items/#{order_id}/provision_update"
  url = "http://#{host}#{path}"
  uri = URI.parse(url)

  information = information.merge("provision_status" => status.downcase)
  information = information.merge("id" => "#{order_id}")
  $evm.log("info", "send_order_status: Information: #{information}")
  json = {
      "status" => "#{status}",
      "message" => "#{message}",
      "info" => information
  }
  $evm.log("info", "send_order_status: Information #{json.to_json}")
  begin
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Put.new(uri.path)
    request.content_type ="application/json"
    request.body = json.to_json
    response = http.request(request)
    $evm.log("info", "send_order_status: HTTP Response code: #{response.code}")
    $evm.log("info", "send_order_status: HTTP Response message: #{response.message}")
  rescue HTTPExceptions => e
    $evm.log("error", "send_order_status: HTTP Exception caught while sending response back to core: #{e.message}")
  rescue Exception => e
    $evm.log("error", "send_order_status: Exception caught while sending response back to core: #{e.message}")
  end
end # End of function


# Retrieve dialog properties
access_key = "#{$evm.root['dialog_access_key_id']}"
secret_access_key = "#{$evm.root['dialog_secret_access_key']}"
email = "#{$evm.root['dialog_email']}"
order_id = "#{$evm.root['dialog_order_item']}"

AWS.config(
    :access_key_id => access_key,
    :secret_access_key => secret_access_key
)


$evm.log("info", "RetireSES: create service")
ses = AWS::SimpleEmailService.new

# Setup a verified sender if a sender was chosen
if email != ""
  begin
    email_identities = email.split(',')
    email_identities.each do |e|
      $evm.log("info", "RetireSES: E-mail Identity: #{e}")
      ses.identities[e].delete
      $evm.log("info", "RetireSES: Email Identity removed.")
    end
  rescue AWS::SimpleEmailService::Errors::InvalidClientTokenId => e
    $evm.log("error", "RetireSES: Exception caught when creating instance: #{e.message}")
    send_order_status("CRITICAL", order_id, "","#{e.message}")
    exit
  rescue AWS::SimpleEmailService::Errors::InvalidParameterValue => e
    $evm.log("error", "RetireSES: Invalid parameter exception caught: #{e.message}")
    send_order_status("CRITICAL", order_id, "","#{e.message}")
    exit
  rescue AWS::SimpleEmailService::Errors => e
    $evm.log("error", "RetireSES: Exception caught: #{e.message}")
    send_order_status("CRITICAL", order_id, "","#{e.message}")
    exit
  rescue Exception => e
    $evm.log("error", "RetireSES: Exception caught #{e.message}")
    send_order_status("CRITICAL", order_id, "","#{e.message}")
    exit
  end
end

info = {
    "order_item" => "#{order_id}"
}
send_order_status("OK", order_id, info, "Instance retired.")