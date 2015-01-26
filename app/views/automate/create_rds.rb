# Description: This MIQ Method
# provisions a new Amazon RDS Instance from the
# Criteria selected in the marketplace

# For use in MIQ under the
# For use in Service/Provisioning/StateMachines/Methods/CreateRDS

require 'aws-sdk'
require 'net/http'
require 'uri/http'
require 'securerandom'
require 'json'

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

rds = AWS::RDS.new(
    :access_key_id => "#{$evm.root['dialog_access_key_id']}",
    :secret_access_key => "#{$evm.root['dialog_secret_access_key']}")

order_id = "#{$evm.root['dialog_order_item']}"
# Create password to pass back to the Marketplace
# AWS RDS instance passwords require a minimum of 8 characters
sec_pw = SecureRandom.hex
sec_pw = sec_pw[0..9] # First 10 characters
$evm.log("info", "CreateRDS: Created password #{sec_pw}")

# Set the secure password
$evm.root['root_sec_pw'] = sec_pw

security_groups = $evm.root['dialog_security_groups'] != nil ? $evm.root['dialog_security_groups'] : ""
if security_groups != ""
  security_array = security_groups.split(',')
  security_array.each do |security|
    $evm.log("info", "CreateRDS: Security group= #{security}")
  end
end

options = {
    :allocated_storage => Integer($evm.root['dialog_allocated_storage']),
    :db_instance_class => $evm.root['dialog_db_instance_class'],
    :engine => $evm.root['dialog_db_engine'],
    :master_username => $evm.root['dialog_master_username'],
    :master_user_password => sec_pw,
    :storage_type => $evm.root['dialog_storage_type'],
    :vpc_security_group_ids => security_array
}

# Remove all empty strings from the options list
# to avoid error in creation of RDS instance
options.each do |key, value|
  if value == "" || value == nil
    options.delete(key)
  end
end

$evm.log("info", "CreateRDS: Set options for new RDS instance: #{options}")

# db_instance_id must be unique to the region.
db_instance_id = "#{$evm.root['dialog_instance_name']}"
$evm.log("info", "CreateRDs: Instance Id = #{db_instance_id}")

# Create instance
begin
  instance = rds.db_instances.create(db_instance_id, options)
rescue AWS::RDS::Errors::InvalidClientTokenId => e
  $evm.log("error", "CreateRDS: Exception caught when creating instance: #{e.message}")
  $evm.root['instance_failed'] = true
  send_order_status("CRITICAL", order_id,  "","#{e.message}")
  exit
rescue AWS::RDS::Errors::DBInstanceAlreadyExists => e
  $evm.log("error", "CreateRDS: Instance exists exception: #{e.message}")
  send_order_status("CRITICAL", order_id, "","#{e.message}")
  $evm.root['instance_failed'] = true
  exit
rescue AWS::RDS::Errors::InvalidParameterValue => e
  $evm.log("error", "CreateRDS: Invalid parameter exception: #{e.message}")
  $evm.root['instance_failed'] = true
  send_order_status("CRITICAL", order_id, "","#{e.message}")
  exit
rescue AWS::RDS::Errors::StorageTypeNotSupported => e
  $evm.log("error", "CreateRDS: Unsupported storage exception: #{e.message}")
  $evm.root['instance_failed'] = true
  send_order_status("CRITICAL", order_id, "","#{e.message}")
  exit
rescue AWS::RDS::Errors => e
  $evm.log("error", "CreateRDS: Exception caught when creating instance: #{e.message}")
  $evm.root['instance_failed'] = true
  send_order_status("CRITICAL", order_id, "","#{e.message}")
  exit
rescue Exception => e
  $evm.log("error", "CreateRDS: General exception caught: #{e.message}")
  $evm.root['instance_failed'] = true
  send_order_status("CRITICAL", order_id, "","#{e.message}")
  exit
end

# MIQ heads to next provision step


