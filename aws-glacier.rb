#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require "aws-sdk"
require "yaml"

# load credentials
creds = YAML::load_file "aws_credentials.yml"

# instantiate glacier object
glacier = AWS::Glacier.new(access_key_id: creds['access_key'], secret_access_key: creds['secret_key'])

# loop through vaults
glacier.vaults.each do |vault|
  puts vault.name
  puts glacier.client.list_jobs(account_id: vault.account_id, vault_name: vault.name)
end
