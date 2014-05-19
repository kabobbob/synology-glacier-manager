#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"
require "aws-sdk"
require "pp"
require "yaml"

# load credentials
creds = YAML::load_file "aws_credentials.yml"

# instantiate glacier object
glacier = AWS::Glacier.new(access_key_id: creds['access_key'], secret_access_key: creds['secret_key'])

loop do
  # present main options
  puts "[1] - List vaults"
  puts "[0] - Exit"

  # get main choice
  print "?: "
  main_choice = gets.chomp.to_i

  case main_choice
  when 1
    loop do
      print "\r\nVaults:\r\n"

      # create vaults array and present vault list
      vaults = []
      glacier.vaults.each do |vault|
        next if vault.name =~ /mapping$/

        vaults.push(vault)
        puts "[#{vaults.length}] - vault: #{vault.name} size: #{vault.size_in_bytes} count: #{vault.number_of_archives}"
      end
      puts "[0] - Back"

      # get vault
      print "?: "
      vault_choice = gets.chomp.to_i

      # exit choice
      if vault_choice == 0
        puts ""
        break
      else
        # present vault action list
        loop do
          vault = vaults[vault_choice - 1]
          print "\r\nVault: #{vault.name}\r\n"
          puts "[1] - Initiate inventory retrieval"
          puts "[2] - Initiate archive retrieval"
          puts "[3] - List jobs"
          puts "[0] - Back"
          print "?: "
          action_choice = gets.chomp.to_i

          case action_choice
          when 1
            # submit inventory retrieval request
            print "\r\nInitiating inventory retrieval for vault: #{vault.name}\r\n"

            job_parameters = {
              format: "CSV",
              type: "inventory-retrieval",
              sns_topic: creds['sns_topic']
            }
            response = glacier.client.initiate_job(account_id: vault.account_id, vault_name: vault.name, job_parameters: job_parameters)

            if response.successful?
              puts "Inventory retrieval initiation successful; notificiation to follow."
            else
              puts "Inventory retrieval initiation failure:"
              pp response
            end
          when 2
            # submit archive retrieval request
            print "\r\nInitiating archive retrieval for vault: #{vault.name}\r\n"
            puts "Not implemented"
          when 3
            # list jobs for vault
            loop do
              print "\r\nListing jobs for vault: #{vault.name}\r\n"

              # get jobs
              response = glacier.client.list_jobs(account_id: vault.account_id, vault_name: vault.name)

              # create jobs array; present jobs list
              jobs = []
              response.data[:job_list].each do |job|
                jobs.push(job)
                puts "[#{jobs.length}] - action: #{job[:action]} started: #{job[:creation_date]} status: #{job[:status_code]}"
              end
              puts "[0] - Back"

              # get job choice
              printf "?: "
              job_choice = gets.chomp.to_i

              if job_choice == 0
                puts ""
                break
              else
                job = jobs[job_choice - 1]
              end
            end
          when 0
            puts ""
            break
          end
        end
      end
    end
  when 0
    print "\r\nExiting\r\n"
    exit
  end
end
